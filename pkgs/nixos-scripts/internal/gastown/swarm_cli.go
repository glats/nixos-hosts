package gastown

import (
	"context"
	"flag"
	"fmt"
	"io"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const swarmUsage = `gastown-run swarm - a goal-driven swarm: a Mayor plans, confined workers code, a trusted gate verifies

  swarm init [flags] <project> <repo-path>
      --check CMD            trusted check the gate runs on every branch (repeatable, required)
      --polecat-agent SPEC   worker agent, in fallback order (repeatable); SPEC is codex:<model>:<effort>, claude:<model> or opencode:nvidia/<model id>, e.g. opencode:nvidia/nvidia/nemotron-3-ultra-550b-a55b
      --mayor-agent SPEC     coordinator agent (default: the worker model at medium effort)
      --max-polecats N       parallel workers (default 2)
      --dolt-port N          port for the swarm's own Dolt (default 45900)
      --notify-cmd CMD       command run for every notification; it receives GASTOWN_NOTIFY_SEVERITY, _TITLE and _BODY
      --agent-env NAME       environment variable passed to opencode agents (repeatable)
      --protect PATH         file or dir/ the gate never lets a worker change, e.g. main.go or cmd/ (repeatable)
  swarm run --goal TEXT [--timeout 6h] <project>   start everything in one limited, detached systemd unit and work until done
  swarm reply <project> TEXT                        answer the Mayor when it asked you something
  swarm status <project>                            workers, scheduler, gated branches
  swarm check <project>                             probe each opencode agent (model alive, key valid) before spending a goal
  swarm usage [--since goal|all] <project>          token totals by role and model (ledger.jsonl in the swarm directory)
  swarm stop <project>                              ask a running swarm to shut down
  swarm up|down|goal|watch                          lower-level steps (watch: --interval, --once, --until-complete)

Accepted work appears as branch gastown/<bead> in the swarm's staging repository; nothing touches your repository.
`

func SwarmMain(c Config, args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprint(stderr, swarmUsage)
		return 2
	}
	r := &Runner{Config: c, Exec: OSExec{}}
	fail := func(err error) int { fmt.Fprintln(stderr, "gastown-run swarm:", err); return 1 }
	switch args[0] {
	case "init":
		fs := flag.NewFlagSet("swarm init", flag.ContinueOnError)
		fs.SetOutput(stderr)
		var checks, polecats, agentEnv, protect listFlag
		mayor := fs.String("mayor-agent", "", "coordinator agent")
		maxPolecats := fs.Int("max-polecats", 2, "parallel workers")
		port := fs.Int("dolt-port", 45900, "dolt port")
		notify := fs.String("notify-cmd", "", "notification command")
		fs.Var(&checks, "check", "check command")
		fs.Var(&polecats, "polecat-agent", "worker agent spec")
		fs.Var(&agentEnv, "agent-env", "env var passed to opencode agents")
		fs.Var(&protect, "protect", "path the gate never lets a worker change (file, or dir with trailing slash)")
		if fs.Parse(args[1:]) != nil || fs.NArg() != 2 {
			fmt.Fprint(stderr, swarmUsage)
			return 2
		}
		if len(polecats) == 0 {
			polecats = listFlag{"codex:" + c.Model + ":" + c.Effort}
		}
		if *mayor == "" {
			*mayor = "codex:" + c.Model + ":medium"
		}
		s := &Swarm{R: r, Out: stdout, Cfg: SwarmConfig{Project: fs.Arg(0), Repo: fs.Arg(1), Checks: checks,
			Chains: map[string][]string{"polecat": polecats, "mayor": {*mayor}}, MaxPolecats: *maxPolecats, DoltPort: *port, NotifyCmd: *notify, AgentEnv: agentEnv, Protect: protect}}
		s.Self, _ = os.Executable()
		if err := s.Init(); err != nil {
			return fail(err)
		}
		return 0
	case "run":
		return swarmRun(c, r, args[1:], stdout, stderr)
	case "exec":
		return swarmExec(r, args[1:], stdout, stderr)
	}
	// remaining commands operate on an existing swarm
	fs := flag.NewFlagSet("swarm "+args[0], flag.ContinueOnError)
	fs.SetOutput(stderr)
	interval := fs.Duration("interval", 20*time.Second, "watch interval")
	once := fs.Bool("once", false, "run one supervision round")
	since := fs.String("since", "goal", "usage window: goal or all")
	untilComplete := fs.Bool("until-complete", false, "stop when the goal is complete and gated")
	if fs.Parse(args[1:]) != nil || fs.NArg() < 1 {
		fmt.Fprint(stderr, swarmUsage)
		return 2
	}
	s, err := LoadSwarm(r, fs.Arg(0), stdout)
	if err != nil {
		return fail(err)
	}
	text := strings.Join(fs.Args()[1:], " ")
	switch args[0] {
	case "up":
		err = s.Up()
	case "down":
		s.Down()
	case "goal":
		err = s.Goal(text)
	case "reply":
		err = s.Reply(text)
	case "status":
		err = s.Status()
	case "check":
		err = s.Check()
	case "usage":
		err = s.Usage(*since)
	case "stop":
		err = os.WriteFile(s.StopFile(), []byte("stop\n"), 0o600)
	case "watch":
		if *once {
			s.Tick(time.Now())
		} else {
			ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
			defer cancel()
			s.Watch(ctx, *interval, 24*time.Hour, *untilComplete)
		}
	default:
		fmt.Fprint(stderr, swarmUsage)
		return 2
	}
	if err != nil {
		return fail(err)
	}
	return 0
}

func swarmUnitFlags(timeout time.Duration, project, workdir string) []string {
	return []string{"--user", "--unit=gts-" + project + "-" + strconv.FormatInt(time.Now().Unix(), 10), "--collect",
		"--working-directory=" + workdir, "-p", "StandardOutput=journal", "-p", "StandardError=journal", "-p", "RuntimeMaxSec=" + strconv.Itoa(int(timeout.Seconds())), "-p", "TimeoutStopSec=30",
		"-p", "KillMode=control-group", "-p", "MemoryMax=8G", "-p", "CPUQuota=400%", "-p", "TasksMax=2048"}
}

func swarmRun(c Config, r *Runner, args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("swarm run", flag.ContinueOnError)
	fs.SetOutput(stderr)
	goal := fs.String("goal", "", "what the swarm should achieve")
	timeout := fs.Duration("timeout", 6*time.Hour, "overall limit")
	if fs.Parse(args) != nil || fs.NArg() != 1 || strings.TrimSpace(*goal) == "" {
		fmt.Fprint(stderr, swarmUsage)
		return 2
	}
	s, err := LoadSwarm(r, fs.Arg(0), stdout)
	if err != nil {
		fmt.Fprintln(stderr, "gastown-run swarm:", err)
		return 1
	}
	_ = os.Remove(s.StopFile())
	self, _ := os.Executable()
	workdir, _ := os.Getwd()
	argv := append([]string{"systemd-run"}, swarmUnitFlags(*timeout+10*time.Minute, s.Cfg.Project, workdir)...)
	argv = append(argv, "--setenv=GASTOWN_IN_UNIT=1")
	for _, entry := range os.Environ() {
		if (strings.HasPrefix(entry, "GASTOWN_") && !strings.HasPrefix(entry, "GASTOWN_IN_UNIT")) || strings.HasPrefix(entry, "PATH=") {
			argv = append(argv, "--setenv="+entry)
		}
	}
	var specs []string
	for _, chain := range s.Cfg.Chains {
		specs = append(specs, chain...)
	}
	for _, name := range AgentEnvNames(specs, s.Cfg.AgentEnv) {
		if _, ok := os.LookupEnv(name); ok {
			argv = append(argv, "--setenv="+name)
		}
	}
	argv = append(argv, self, "swarm", "exec", "--goal", *goal, "--timeout", timeout.String(), s.Cfg.Project)
	if err := syscallExec(argv); err != nil {
		fmt.Fprintln(stderr, "gastown-run swarm:", err)
		return 1
	}
	return 0
}

func swarmExec(r *Runner, args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("swarm exec", flag.ContinueOnError)
	fs.SetOutput(stderr)
	goal := fs.String("goal", "", "goal")
	timeout := fs.Duration("timeout", 6*time.Hour, "limit")
	if fs.Parse(args) != nil || fs.NArg() != 1 {
		return 2
	}
	s, err := LoadSwarm(r, fs.Arg(0), stdout)
	if err != nil {
		fmt.Fprintln(stderr, "gastown-run swarm:", err)
		return 1
	}
	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer cancel()
	defer s.Down()
	if err := s.Up(); err != nil {
		fmt.Fprintln(stderr, "gastown-run swarm:", err)
		return 1
	}
	time.Sleep(15 * time.Second)
	if err := s.Goal(*goal); err != nil {
		fmt.Fprintln(stderr, "gastown-run swarm:", err)
		return 1
	}
	s.notify("low", "Swarm started", "goal sent to the Mayor: "+clip(*goal, 200))
	s.Watch(ctx, 20*time.Second, *timeout, true)
	return 0
}
