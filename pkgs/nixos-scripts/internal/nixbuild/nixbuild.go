// Package nixbuild ports the dispatch, platform, flag and tool-detection
// logic of bin/nixos-build, and replicates its exact exec sequences.
//
// The bash original runs under `set -euo pipefail`. That contract shows up
// here in three ways:
//
//   - a failing exec'd command that is not guarded (everything except the
//     four `safe` stages and `update_npm_packages`'s nix build) kills the
//     script silently with the child's exit status — Run returns that code
//     with no extra output;
//   - the guarded `safe` stages print their "> ERROR: X failed. Stopping."
//     block and exit 1;
//   - run_with_nom pipes both stdout and stderr through nom (bash `|& nom`),
//     and pipefail reports the rightmost non-zero status, so a failing
//     build alongside a failing nom yields nom's status.
package nixbuild

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"syscall"
)

// Env carries everything the bash script resolved at startup. Steps is a
// pure function of Env + command, which makes the argv contract testable.
type Env struct {
	Darwin    bool   // uname = Darwin
	Raw       bool   // --raw (forces nixos-rebuild instead of nh)
	NoNom     bool   // --no-nom
	HasNH     bool   // command -v nh (Linux only)
	HasNom    bool   // command -v nom (Linux only)
	NomPath   string // nom executable path; empty when unavailable
	Hostname  string
	FlakePath string // worktree-aware: "." inside <root>/.worktrees
}

// Kind is the action a Step performs.
type Kind int

const (
	KindEcho Kind = iota // print Echo
	KindExec             // exec Args
	KindNpm              // capture a store path, then exec it when non-empty
	KindExit             // return ExitCode
)

// Step is one unit of the bash contract: an echo, an exit, an exec, or the
// npm update-script dance.
//
// FailLines ports the guarded failure blocks of the `safe` workflow:
// after a non-zero exec status, each line is printed and the run exits 1.
// Without FailLines a failure matches `set -e`: silent exit with the
// child's status (or nom's status through the pipe, per pipefail).
type Step struct {
	Kind       Kind
	Echo       string
	Args       []string
	ThroughNom bool // run_with_nom: `"$@" |& nom`
	FailLines  []string
	ExitCode   int
}

// IsDarwin mirrors `[[ "$(uname)" == "Darwin" ]]`.
func IsDarwin() bool { return runtime.GOOS == "darwin" }

// DetectTools mirrors the bash tool detection: nh/nom are probed on Linux
// only. It returns executable paths ("" when unavailable).
func DetectTools(darwin bool) (nhPath, nomPath string) {
	if darwin {
		return "", ""
	}
	nhPath, _ = exec.LookPath("nh")
	nomPath, _ = exec.LookPath("nom")
	return nhPath, nomPath
}

// ParseArgs ports the bash flag sweep: --raw and --no-nom are recognized
// anywhere, stripped, and the first remaining argument is the command
// (default "switch"). All further arguments are ignored, like bash's
// `COMMAND="${1:-switch}"`.
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

// isHelp ports `[[ "$COMMAND" == "help" || -h || --help ]]`.
func IsHelp(command string) bool {
	return command == "help" || command == "-h" || command == "--help"
}

// IsKnown reports whether command is one of the eight dispatch targets.
func IsKnown(command string) bool {
	switch command {
	case "switch", "boot", "test", "upgrade", "dry", "check", "build", "safe":
		return true
	}
	return false
}

// Steps returns the exact sequence of echoes, execs and exits the bash
// script would perform for the given command. It never touches the OS;
// Run executes it.
func Steps(env Env, command string) []Step {
	useNH := !env.Darwin && !env.Raw && env.HasNH
	useNom := !env.Darwin && !env.NoNom && env.HasNom

	flakeArg := env.FlakePath + "#" + env.Hostname
	refTop := env.FlakePath + "#nixosConfigurations." + env.Hostname + ".config.system.build.toplevel"
	refDarwin := env.FlakePath + "#darwinConfigurations." + env.Hostname + ".config.system.build.toplevel"

	// darwinBuild(): sudo darwin-rebuild "$@" --flake "$FLAKE_PATH#$HOSTNAME"
	darwinBuild := func(sub string) Step {
		return execStep([]string{"sudo", "darwin-rebuild", sub, "--flake", flakeArg}, false)
	}
	// run_with_nom sudo nixos-rebuild <op> --flake ...
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
		s = append(s, npmSteps(env)...)
		s = append(s, Step{Kind: KindEcho, Echo: ""})
		if env.Darwin {
			s = append(s,
				Step{Kind: KindEcho, Echo: "> Updating flake inputs..."},
				execStep([]string{"nix", "flake", "update", "--flake", env.FlakePath}, false),
				Step{Kind: KindEcho, Echo: ""},
				Step{Kind: KindEcho, Echo: "> Building Darwin configuration (upgrade)..."},
				darwinBuild("switch"))
		} else if useNH {
			s = append(s,
				Step{Kind: KindEcho, Echo: "> Updating flake inputs and rebuilding (nh os switch --update)..."},
				execStep([]string{"nh", "os", "switch", "--update"}, false))
		} else {
			s = append(s,
				Step{Kind: KindEcho, Echo: "> Updating flake inputs..."},
				execStep([]string{"nix", "flake", "update"}, false),
				Step{Kind: KindEcho, Echo: ""},
				linuxHeader("upgrade"),
				rebuild("switch"))
		}

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
			// bash: plain sudo nixos-rebuild dry-activate — no nom even with
			// nom installed (dry-activate output is not build progress).
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
			s = append(s, execStep([]string{"nh", "build", refTop}, false))
		} else {
			s = append(s, execStep([]string{"nix", "build", refTop}, useNom))
		}

	case "safe":
		buildStep := execStep([]string{"nh", "build", refTop}, false)
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

// unsupportedDarwin ports the early Darwin exit of boot/test.
func unsupportedDarwin(command string) []Step {
	return []Step{
		{Kind: KindEcho, Echo: "> '" + command + "' not supported on Darwin. Use 'switch' instead."},
		{Kind: KindExit, ExitCode: 1},
	}
}

// npmSteps ports update_npm_packages(): print banner, capture the store
// path of the flake's updateScript (stderr to /dev/null, `|| true`), then
// exec the path when it is non-empty. It is one KindNpm step, not two, so
// the runner keeps the capture/execute pairing atomic.
func npmSteps(env Env) []Step {
	return []Step{
		{Kind: KindEcho, Echo: "> Updating npm packages to latest..."},
		{Kind: KindNpm, Args: []string{
			"nix", "build",
			env.FlakePath + "#opencode-npm-packages.updateScript",
			"--no-link", "--print-out-paths",
		}},
	}
}

func execStep(args []string, throughNom bool) Step {
	return Step{Kind: KindExec, Args: args, ThroughNom: throughNom}
}

// guarded ports `if ! cmd; then ...; exit 1; fi`.
func guarded(args []string, failMsg string) Step {
	return Step{Kind: KindExec, Args: args,
		FailLines: []string{"", failMsg}}
}

func guardedStep(st Step, failMsg string) Step {
	st.FailLines = []string{"", failMsg}
	return st
}

// Run executes steps and returns the exit code the bash script would
// produce. nomPath is the nom executable ("" unavailable).
func Run(steps []Step, nomPath string) int {
	for _, st := range steps {
		switch st.Kind {
		case KindEcho:
			fmt.Println(st.Echo)
		case KindExit:
			return st.ExitCode
		case KindNpm:
			cmd := exec.Command(st.Args[0], st.Args[1:]...)
			var buf bytes.Buffer
			cmd.Stdout = &buf
			// bash: 2>/dev/null; failure tolerated (`|| true`).
			if err := cmd.Run(); err != nil {
				// fall through — the bash build is guarded
			}
			if path := strings.TrimRight(buf.String(), "\n"); path != "" {
				// `"$UPDATE_SCRIPT"` — unguarded: failure kills with its status.
				if rc := runDirect([]string{path}); rc != 0 {
					return rc
				}
			}
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

// runDirect execs argv with inherited stdio, returning the exit status the
// bash child would set. A start failure mirrors bash's command-not-found
// status 127.
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
			return 127 // exec not startable: bash command-not-found
		}
		return exitStatus(err)
	}
	return 0
}

// RunThroughNom ports run_with_nom(): `"$@" |& nom` — the child's stdout
// and stderr are merged into nom's stdin; nom inherits the terminal's
// stdout/stderr. With `set -o pipefail` the pipeline status is the
// rightmost non-zero status, so when both fail, nom's status wins.
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
		// Close the write end so the child drains via EOF/SIGPIPE.
		pw.Close()
		pr.Close()
		c.Wait()
		return 127
	}
	// Parent copies: children hold their own descriptors.
	pw.Close()
	pr.Close()

	cerr := c.Wait()
	nerr := n.Wait()
	cs := exitStatus(cerr)
	ns := exitStatus(nerr)
	switch {
	case cs != 0 && ns != 0:
		return ns // pipefail: rightmost non-zero wins
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

// exitStatus extracts the bash $? from a Run error: the child's exit code,
// or 128+signal for a signaled child.
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
