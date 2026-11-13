package gastown

import (
	"context"
	"errors"
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

const campaignUsage = `gastown-run campaign - an intent becomes needs, you pick, the swarm executes and remembers

  campaign start [--timeout 24h] <project> "<intent>"   plan with the Mayor, then execute what you select (resumes a saved campaign)
  campaign reply <project> TEXT                         pick items ("a c" or "all"), answer a question or steer the work
  campaign answer [--question ID] <project> TEXT        answer one of the Mayor's questions (no id: the only open one)
  campaign advance <project> BRANCH...                  add gate-accepted branches (gastown/<bead>) to the swarm's base by hand
  campaign approve <project> <item> BRANCH...           approve an item whose branches the gate accepted (you reviewed them)
  campaign extend <project> "<direction>"               have the Mayor propose more items for a new direction
  campaign retry <project> <item>                       re-run the base advance of a blocked item whose branches the gate accepted
  campaign autopilot <project> on|off                   select items that need no decision from you automatically (at most 3 active)
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
	question := fs.String("question", "", "question id for campaign answer")
	if fs.Parse(hoistFlags(args[1:], "question", "timeout")) != nil || fs.NArg() < 1 {
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
		if release, lockErr := s.AcquireSupervisor(); errors.Is(lockErr, ErrSupervisorRunning) {
			fmt.Fprintln(stdout, "a supervisor is already running for "+s.Cfg.Project+"; nothing to start (see: gastown-run campaign status "+s.Cfg.Project+")")
			return 0
		} else if lockErr == nil {
			release()
		}
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
		fmt.Fprintln(stdout, "starting the supervisor in the background; follow it with: gastown-run campaign status "+s.Cfg.Project)
		if err := syscallExec(argv); err != nil {
			return fail(err)
		}
	case "exec":
		release, lockErr := s.AcquireSupervisor()
		if lockErr != nil {
			fmt.Fprintln(stderr, "gastown-run campaign:", lockErr)
			if errors.Is(lockErr, ErrSupervisorRunning) {
				return 75
			}
			return 1
		}
		defer release()
		camp, _, err := s.CampaignStart("", time.Now())
		if err != nil {
			return fail(err)
		}
		if n := ResumeCampaign(camp); n > 0 {
			_ = SaveCampaign(s.campaignPath(), camp)
			s.notify("medium", "Campaign resumed", strconv.Itoa(n)+" interrupted item(s) will be sent again to a fresh Mayor")
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
	case "approve":
		args := fs.Args()[1:]
		if len(args) < 2 {
			return fail(errors.New("approve needs an item and at least one gate-accepted branch"))
		}
		if err := s.QueueCampaignApprove(args[0], args[1:]); err != nil {
			return fail(err)
		}
		fmt.Fprintln(stdout, "queued; the supervisor checks the branches against the gate before marking the item done")
	case "extend":
		if err := s.QueueCampaignExtend(text); err != nil {
			return fail(err)
		}
		fmt.Fprintln(stdout, "queued; the Mayor will propose items and you choose among them")
	case "retry":
		args := fs.Args()[1:]
		if len(args) != 1 {
			return fail(errors.New("retry needs exactly one item"))
		}
		if err := s.QueueCampaignRetry(args[0]); err != nil {
			return fail(err)
		}
		fmt.Fprintln(stdout, "queued; the supervisor re-checks the gate verdicts and the combined checks")
	case "autopilot":
		args := fs.Args()[1:]
		if len(args) != 1 || (args[0] != "on" && args[0] != "off") {
			return fail(errors.New("autopilot takes on or off"))
		}
		if err := s.QueueCampaignAutopilot(args[0] == "on"); err != nil {
			return fail(err)
		}
		fmt.Fprintln(stdout, "queued; autopilot "+args[0])
	case "advance":
		if err := s.CampaignAdvance(fs.Args()[1:]); err != nil {
			return fail(err)
		}
	case "answer":
		if err := s.QueueCampaignAnswer(*question, text); err != nil {
			return fail(err)
		}
		fmt.Fprintln(stdout, "queued; the supervisor reads it on its next round")
	case "status":
		camp, err := LoadCampaign(s.campaignPath())
		if err != nil {
			return fail(fmt.Errorf("no campaign for %s: %w", s.Cfg.Project, err))
		}
		fmt.Fprintf(stdout, "intent: %s\nphase: %s | decisions: %d | learnings: %d\n", camp.Intent, camp.Phase, len(camp.Decisions), len(camp.Learnings))
		fmt.Fprintf(stdout, "process: test: %s | build: %s | ship: %s\n", camp.Process.Test, camp.Process.Build, camp.Process.Ship)
		for _, q := range camp.Questions {
			fmt.Fprintf(stdout, "  question %-8s %s -> %s\n", q.ID, q.Text, firstNonEmpty(q.Answer, "(open)"))
		}
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
