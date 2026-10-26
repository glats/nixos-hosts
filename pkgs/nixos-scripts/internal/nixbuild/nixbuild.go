package nixbuild

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"syscall"
)

type Env struct {
	Darwin    bool
	Raw       bool
	NoNom     bool
	HasNH     bool
	HasNom    bool
	NomPath   string
	Hostname  string
	FlakePath string
}

const DefaultDarwinHost = "macm5"

func ResolveHost(darwin bool, getenv func(string) string, hostname func() (string, error)) string {
	if darwin {
		if configured := getenv("NIXOS_DARWIN_HOST"); configured != "" {
			return configured
		}
		return DefaultDarwinHost
	}

	host, _ := hostname()
	return host
}

type Kind int

const (
	KindEcho Kind = iota
	KindExec
	KindExit
)

type Step struct {
	Kind       Kind
	Echo       string
	Args       []string
	ThroughNom bool
	FailLines  []string
	ExitCode   int
}

func IsDarwin() bool { return runtime.GOOS == "darwin" }

func DetectTools(darwin bool) (nhPath, nomPath string) {
	if darwin {
		return "", ""
	}
	nhPath, _ = exec.LookPath("nh")
	nomPath, _ = exec.LookPath("nom")
	return nhPath, nomPath
}

func ParseArgs(args []string) (command string, raw, noNom bool) {
	command = "switch"
	var rest []string
	for _, arg := range args {
		switch arg {
		case "--raw":
			raw = true
		case "--no-nom":
			noNom = true
		default:
			rest = append(rest, arg)
		}
	}
	if len(rest) > 0 {
		command = rest[0]
	}
	return command, raw, noNom
}

func IsHelp(command string) bool {
	return command == "help" || command == "-h" || command == "--help"
}

func IsKnown(command string) bool {
	switch command {
	case "switch", "boot", "test", "upgrade", "dry", "check", "build", "safe":
		return true
	}
	return false
}

func Steps(env Env, command string) []Step {
	useNH := !env.Darwin && !env.Raw && env.HasNH
	useNom := !env.Darwin && !env.NoNom && env.HasNom

	flakeArg := env.FlakePath + "#" + env.Hostname
	refTop := env.FlakePath + "#nixosConfigurations." + env.Hostname + ".config.system.build.toplevel"
	refDarwin := env.FlakePath + "#darwinConfigurations." + env.Hostname + ".config.system.build.toplevel"

	darwinBuild := func(sub string) Step {
		return execStep([]string{"sudo", "darwin-rebuild", sub, "--flake", flakeArg}, false)
	}

	rebuild := func(op string) Step {
		return execStep([]string{"sudo", "nixos-rebuild", op, "--flake", flakeArg}, useNom)
	}

	linuxHeader := func(op string) Step {
		return Step{Kind: KindEcho, Echo: "> Building NixOS configuration (" + op + ")..."}
	}

	var s []Step
	switch command {
	case "switch":
		s = append(s, Step{Kind: KindEcho, Echo: ""})
		if env.Darwin {
			s = append(s, Step{Kind: KindEcho, Echo: "> Building Darwin configuration (switch)..."}, darwinBuild("switch"))
		} else if useNH {
			s = append(s, linuxHeader("switch"), execStep([]string{"nh", "os", "switch"}, false))
		} else {
			s = append(s, linuxHeader("switch"), rebuild("switch"))
		}

	case "boot":
		if env.Darwin {
			return unsupportedDarwin("boot")
		}
		s = append(s, Step{Kind: KindEcho, Echo: ""}, linuxHeader("boot"))
		if useNH {
			s = append(s, execStep([]string{"nh", "os", "boot"}, false))
		} else {
			s = append(s, rebuild("boot"))
		}

	case "test":
		if env.Darwin {
			return unsupportedDarwin("test")
		}
		s = append(s, Step{Kind: KindEcho, Echo: ""}, linuxHeader("test"))
		if useNH {
			s = append(s, execStep([]string{"nh", "os", "test"}, false))
		} else {
			s = append(s, rebuild("test"))
		}

	case "upgrade":
		s = append(s, Step{Kind: KindEcho, Echo: ""})
		s = append(s,
			Step{Kind: KindEcho, Echo: "> Updating BrowserMCP npm dependencies (OpenCode pins are preserved)..."},
			execStep([]string{"npm", "update", "--prefix", env.FlakePath + "/pkgs/browsermcp-v2", "--package-lock-only", "--no-audit", "--no-fund"}, false),
			Step{Kind: KindEcho, Echo: "> Updating flake inputs..."},
			execStep([]string{"nix", "flake", "update", "--flake", env.FlakePath}, false),
			Step{Kind: KindEcho, Echo: "OpenCode versions remain pinned; use npm install --package-lock-only --save-exact for intentional version changes."})

	case "dry":
		s = append(s, Step{Kind: KindEcho, Echo: ""})
		if env.Darwin {
			s = append(s,
				Step{Kind: KindEcho, Echo: "> Checking Darwin configuration (dry run)..."},
				darwinBuild("check"))
		} else if useNH {
			s = append(s,
				Step{Kind: KindEcho, Echo: "> Dry-activating (nh)..."},
				execStep([]string{"nh", "os", "switch", "--dry"}, false))
		} else {

			s = append(s,
				Step{Kind: KindEcho, Echo: "> Dry-activating..."},
				execStep([]string{"sudo", "nixos-rebuild", "dry-activate", "--flake", flakeArg}, false))
		}

	case "check":
		s = append(s,
			Step{Kind: KindEcho, Echo: "> Validating flake..."},
			execStep([]string{"nix", "flake", "check"}, false))

	case "build":
		s = append(s, Step{Kind: KindEcho, Echo: "> Dry-building..."})
		if env.Darwin {
			s = append(s, execStep([]string{"nix", "build", refDarwin}, useNom))
		} else if useNH {
			s = append(s, execStep([]string{"nh", "os", "build", "--hostname", env.Hostname, env.FlakePath}, false))
		} else {
			s = append(s, execStep([]string{"nix", "build", refTop}, useNom))
		}

	case "safe":
		buildStep := execStep([]string{"nh", "os", "build", "--hostname", env.Hostname, env.FlakePath}, false)
		dryStep := execStep([]string{"nh", "os", "switch", "--dry"}, false)
		switchStep := execStep([]string{"nh", "os", "switch"}, false)
		if env.Darwin {
			buildStep = execStep([]string{"nix", "build", refDarwin}, useNom)
			dryStep = darwinBuild("check")
			switchStep = darwinBuild("switch")
		} else if !useNH {
			buildStep = execStep([]string{"nix", "build", refTop}, useNom)
			dryStep = execStep([]string{"sudo", "nixos-rebuild", "dry-activate", "--flake", flakeArg}, false)
			switchStep = rebuild("switch")
		}
		s = append(s,
			Step{Kind: KindEcho, Echo: ""},
			Step{Kind: KindEcho, Echo: "> Running safe build workflow..."},
			Step{Kind: KindEcho, Echo: ""},
			Step{Kind: KindEcho, Echo: "> [1/4] Checking flake..."},
			guarded([]string{"nix", "flake", "check"}, "> ERROR: Flake check failed. Stopping."),
			Step{Kind: KindEcho, Echo: ""},
			Step{Kind: KindEcho, Echo: "> [2/4] Building..."},
			guardedStep(buildStep, "> ERROR: Build failed. Stopping."),
			Step{Kind: KindEcho, Echo: ""},
			Step{Kind: KindEcho, Echo: "> [3/4] Dry-activating..."},
			guardedStep(dryStep, "> ERROR: Dry-activate failed. Stopping."),
			Step{Kind: KindEcho, Echo: ""},
			Step{Kind: KindEcho, Echo: "> [4/4] Switching..."},
			guardedStep(switchStep, "> ERROR: Switch failed. Stopping."),
			Step{Kind: KindEcho, Echo: ""},
			Step{Kind: KindEcho, Echo: "> Safe build completed successfully!"})
	}
	return s
}

func unsupportedDarwin(command string) []Step {
	return []Step{
		{Kind: KindEcho, Echo: "> '" + command + "' not supported on Darwin. Use 'switch' instead."},
		{Kind: KindExit, ExitCode: 1},
	}
}

func execStep(args []string, throughNom bool) Step {
	return Step{Kind: KindExec, Args: args, ThroughNom: throughNom}
}

func guarded(args []string, failMsg string) Step {
	return Step{Kind: KindExec, Args: args,
		FailLines: []string{"", failMsg}}
}

func guardedStep(st Step, failMsg string) Step {
	st.FailLines = []string{"", failMsg}
	return st
}

func Run(steps []Step, nomPath string) int {
	for _, st := range steps {
		switch st.Kind {
		case KindEcho:
			fmt.Println(st.Echo)
		case KindExit:
			return st.ExitCode
		case KindExec:
			rc := 0
			if st.ThroughNom && nomPath != "" {
				rc = RunThroughNom(st.Args, nomPath)
			} else {
				rc = runDirect(st.Args)
			}
			if rc != 0 {
				if st.FailLines != nil {
					for _, line := range st.FailLines {
						fmt.Println(line)
					}
					return 1
				}
				return rc
			}
		}
	}
	return 0
}

func runDirect(argv []string) int {
	if len(argv) == 0 {
		return 0
	}
	cmd := exec.Command(argv[0], argv[1:]...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		if !isExitError(err) {
			return 127
		}
		return exitStatus(err)
	}
	return 0
}

func RunThroughNom(argv []string, nomPath string) int {
	c := exec.Command(argv[0], argv[1:]...)
	c.Stdin = os.Stdin
	n := exec.Command(nomPath)
	n.Stdout = os.Stdout
	n.Stderr = os.Stderr

	pr, pw, err := os.Pipe()
	if err != nil {
		return 1
	}
	c.Stdout = pw
	c.Stderr = pw
	n.Stdin = pr

	if err := c.Start(); err != nil {
		pr.Close()
		pw.Close()
		return 127
	}
	if err := n.Start(); err != nil {

		pw.Close()
		pr.Close()
		c.Wait()
		return 127
	}

	pw.Close()
	pr.Close()

	cerr := c.Wait()
	nerr := n.Wait()
	cs := exitStatus(cerr)
	ns := exitStatus(nerr)
	switch {
	case cs != 0 && ns != 0:
		return ns
	case cs != 0:
		return cs
	case ns != 0:
		return ns
	}
	return 0
}

func isExitError(err error) bool {
	var ee *exec.ExitError
	return errors.As(err, &ee)
}

func exitStatus(err error) int {
	if err == nil {
		return 0
	}
	var ee *exec.ExitError
	if errors.As(err, &ee) {
		if ws, ok := ee.Sys().(syscall.WaitStatus); ok && ws.Signaled() {
			return 128 + int(ws.Signal())
		}
		return ee.ExitCode()
	}
	return 1
}
