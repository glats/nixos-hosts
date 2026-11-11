package gastown

import (
	"context"
	"flag"
	"fmt"
	"io"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
)

const campaignUsage = `gastown-run campaign - an intent becomes needs, you pick, the swarm executes and remembers

  campaign start [--timeout 24h] <project> "<intent>"   plan with the Mayor, then execute what you select (resumes a saved campaign)
  campaign reply <project> TEXT                         pick items ("a c" or "all"), answer a question or steer the work
  campaign status <project>                             phase, items, decisions and learnings
  campaign stop <project>                               stop the supervisor; the campaign resumes with campaign start

The campaign memory is campaign.json in the swarm directory; it is published as CAMPAIGN.md on branch gastown/campaign of the staging repository.
`

func CampaignMain(c Config, args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprint(stderr, campaignUsage)
		return 2
	}
	r := &Runner{Config: c, Exec: OSExec{}}
	fail := func(err error) int { fmt.Fprintln(stderr, "gastown-run campaign:", err); return 1 }
	fs := flag.NewFlagSet("campaign "+args[0], flag.ContinueOnError)
	fs.SetOutput(stderr)
	timeout := fs.Duration("timeout", 24*time.Hour, "overall limit")
	if fs.Parse(args[1:]) != nil || fs.NArg() < 1 {
		fmt.Fprint(stderr, campaignUsage)
		return 2
	}
	s, err := LoadSwarm(r, fs.Arg(0), stdout)
	if err != nil {
		return fail(err)
	}
	text := strings.Join(fs.Args()[1:], " ")
	switch args[0] {
	case "start":
		camp, resumed, err := s.CampaignStart(text, time.Now())
		if err != nil {
			return fail(err)
		}
		if resumed {
			fmt.Fprintln(stdout, "resuming the saved campaign: "+camp.Intent)
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
		argv = append(argv, self, "campaign", "exec", "--timeout", timeout.String(), s.Cfg.Project)
		if err := syscallExec(argv); err != nil {
			return fail(err)
		}
	case "exec":
		camp, _, err := s.CampaignStart("", time.Now())
		if err != nil {
			return fail(err)
		}
		ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
		defer cancel()
		defer s.Down()
		if err := s.Up(); err != nil {
			return fail(err)
		}
		time.Sleep(15 * time.Second)
		s.notify("low", "Campaign started", clip(camp.Intent, 200))
		s.CampaignWatch(ctx, camp, 20*time.Second, *timeout)
	case "reply":
		if err := s.QueueCampaignReply(text); err != nil {
			return fail(err)
		}
		fmt.Fprintln(stdout, "queued; the supervisor reads it on its next round")
	case "status":
		camp, err := LoadCampaign(s.campaignPath())
		if err != nil {
			return fail(fmt.Errorf("no campaign for %s: %w", s.Cfg.Project, err))
		}
		fmt.Fprintf(stdout, "intent: %s\nphase: %s | decisions: %d | learnings: %d\n", camp.Intent, camp.Phase, len(camp.Decisions), len(camp.Learnings))
		for _, it := range camp.Items {
			fmt.Fprintf(stdout, "  %-10s %-9s %s\n", it.ID, it.Status, it.Title)
		}
	case "stop":
		if err := os.WriteFile(s.StopFile(), []byte("stop\n"), 0o600); err != nil {
			return fail(err)
		}
	default:
		fmt.Fprint(stderr, campaignUsage)
		return 2
	}
	return 0
}
