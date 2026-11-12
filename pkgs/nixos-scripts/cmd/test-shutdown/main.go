package main

import (
	"flag"
	"fmt"
	"math/rand/v2"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/glats/nixos-scripts/internal/kmsg"
	"github.com/glats/nixos-scripts/internal/shutdowncampaign"
	"github.com/glats/nixos-scripts/internal/shutdowntrial"
)

type osSystem struct{}

func (osSystem) ReadFile(p string) ([]byte, error)     { return os.ReadFile(p) }
func (osSystem) WriteFile(p string, d []byte) error    { return os.WriteFile(p, d, 0o644) }
func (osSystem) Glob(pattern string) ([]string, error) { return filepath.Glob(pattern) }
func (osSystem) Run(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	return cmd.Run()
}

func (osSystem) Output(name string, args ...string) (string, error) {
	out, err := exec.Command(name, args...).Output()
	return string(out), err
}

func (osSystem) Sleep(d time.Duration) { time.Sleep(d) }

func usage() {
	fmt.Fprint(os.Stderr, `Usage:
  test-shutdown                      list trials and the recorded history
  sudo test-shutdown <trial>         apply one trial, record it, and power off
  sudo test-shutdown -n <trial>      dry run: show the steps, change nothing
  sudo test-shutdown result off|hung [note...]
                                     record what you saw after the last trial
  test-shutdown status               A/B campaign summary (normal vs unload)
  sudo test-shutdown campaign pause|resume
                                     stop or restart the automatic campaign
`)
}

func main() {
	dryRun := flag.Bool("n", false, "dry run: show the steps without applying them")
	logPath := flag.String("log", shutdowntrial.DefaultLogPath, "trial history file")
	flag.Usage = usage
	flag.Parse()

	log := &shutdowntrial.Log{Path: *logPath}
	ctx := shutdowntrial.Context{
		BootID: readTrim("/proc/sys/kernel/random/boot_id"),
		Kernel: readTrim("/proc/sys/kernel/osrelease"),
		Now:    time.Now(),
		DryRun: *dryRun,
	}
	args := flag.Args()

	switch {
	case len(args) == 0:
		list(log)
	case args[0] == "status":
		status(log)
	case args[0] == "campaign":
		if len(args) < 2 {
			usage()
			os.Exit(2)
		}
		requireRoot()
		campaign(log, ctx, args[1])
	case args[0] == "result":
		if len(args) < 2 {
			usage()
			os.Exit(2)
		}
		requireRoot()
		if err := shutdowntrial.RecordResult(log, args[1], strings.Join(args[2:], " "), ctx); err != nil {
			fail(err)
		}
		fmt.Println("recorded")
	default:
		run(log, args[0], ctx)
	}
}

func run(log *shutdowntrial.Log, id string, ctx shutdowntrial.Context) {
	t, err := shutdowntrial.Lookup(id)
	if err != nil {
		fail(err)
	}
	fmt.Printf("trial %s: %s\n", t.ID, t.Hypothesis)
	if t.Manual != "" {
		fmt.Println(t.Manual)
		return
	}
	for _, st := range t.Steps {
		fmt.Println("  -", st.Desc)
	}
	if ctx.DryRun {
		fmt.Println("dry run: nothing changed")
		return
	}
	requireRoot()
	if os.Getenv(detachedEnv) == "" {
		if entries, _ := log.Read(); pendingResult(entries) {
			fmt.Fprintln(os.Stderr, "warning: the previous trial has no recorded result")
		}
		detach(log, id)
		return
	}
	km := kmsg.New()
	err = shutdowntrial.Execute(osSystem{}, log, id, ctx, func(m string) {
		_ = km.Write(kmsg.UserNotice, m)
	})
	if err != nil {
		fail(err)
	}
}

const detachedEnv = "TEST_SHUTDOWN_DETACHED"

func detach(log *shutdowntrial.Log, id string) {
	self, err := os.Executable()
	if err != nil {
		fail(err)
	}
	fmt.Println("powering off; after the next boot run: sudo test-shutdown result off|hung <note>")
	cmd := exec.Command("systemd-run", "--collect", "--wait", "--pipe", "--unit=test-shutdown-"+id,
		"--setenv="+detachedEnv+"=1", "--setenv=PATH="+os.Getenv("PATH"), self, "-log", log.Path, id)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		fail(fmt.Errorf("launch detached trial: %w", err))
	}
}

func list(log *shutdowntrial.Log) {
	fmt.Println("Trials:")
	for _, t := range shutdowntrial.Trials {
		kind := "auto"
		if t.Manual != "" {
			kind = "manual"
		}
		fmt.Printf("  %-9s %-6s %s\n", t.ID, kind, t.Hypothesis)
	}
	entries, err := log.Read()
	if err != nil {
		fail(err)
	}
	if len(entries) == 0 {
		fmt.Println("\nNo trials recorded yet.")
		return
	}
	fmt.Println("\nHistory:")
	for _, e := range entries {
		switch e.Kind {
		case "trial":
			failed := 0
			for _, s := range e.Steps {
				if s.Error != "" {
					failed++
				}
			}
			fmt.Printf("  %s  trial  %-9s kernel=%s failed_steps=%d\n", e.Time.Format("2006-01-02 15:04"), e.Trial, e.Kernel, failed)
		case "result":
			fmt.Printf("  %s  result %-9s %s %s\n", e.Time.Format("2006-01-02 15:04"), e.Trial, e.Outcome, e.Note)
		}
	}
	if pendingResult(entries) {
		fmt.Println("\nThe last trial has no result: sudo test-shutdown result off|hung <note>")
	}
}

func pendingResult(entries []shutdowntrial.Entry) bool {
	return len(entries) > 0 && entries[len(entries)-1].Kind == "trial"
}

func requireRoot() {
	if os.Geteuid() != 0 {
		fail(fmt.Errorf("run with sudo"))
	}
}

func readTrim(p string) string {
	b, err := os.ReadFile(p)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "test-shutdown:", err)
	os.Exit(1)
}

func campaign(log *shutdowntrial.Log, ctx shutdowntrial.Context, sub string) {
	env := osSystem{}
	c := shutdowncampaign.Ctx{
		BootID: ctx.BootID,
		Kernel: ctx.Kernel,
		Now:    ctx.Now,
		Rand:   rand.IntN,
	}
	km := kmsg.New()
	crumb := func(m string) { _ = km.Write(kmsg.UserNotice, m) }
	var err error
	switch sub {
	case "shutdown":
		err = shutdowncampaign.Shutdown(env, log, c, crumb)
	case "boot":
		var e shutdowntrial.Entry
		if e, err = shutdowncampaign.Boot(env, log, c); err == nil && e.Kind != "" {
			crumb(fmt.Sprintf("test-shutdown: campaign boot reason=%s outcome=%s arm=%s", e.Reason, e.Outcome, e.Arm))
		}
	case "cycle":
		err = shutdowncampaign.AutoCycle(env, log, c, crumb)
	case "pause":
		err = os.MkdirAll(filepath.Dir(shutdowncampaign.PausePath), 0o755)
		if err == nil {
			err = os.WriteFile(shutdowncampaign.PausePath, nil, 0o644)
		}
		if err == nil {
			fmt.Println("campaign paused: no arm, no alarm, no auto-cycle")
		}
	case "resume":
		if err = os.Remove(shutdowncampaign.PausePath); err != nil && os.IsNotExist(err) {
			err = nil
		}
		if err == nil {
			fmt.Println("campaign resumed")
		}
	default:
		usage()
		os.Exit(2)
	}
	if err != nil {
		fail(err)
	}
}

func status(log *shutdowntrial.Log) {
	entries, err := log.Read()
	if err != nil {
		fail(err)
	}
	r := shutdowncampaign.Summarize(entries)
	paused := "running"
	if _, err := os.Stat(shutdowncampaign.PausePath); err == nil {
		paused = "paused"
	}
	fmt.Printf("campaign: %s\n", paused)
	fmt.Printf("  normal  measured=%d off=%d hung_or_unwoken=%d\n", r.Normal.N, r.Normal.Off, r.Normal.N-r.Normal.Off)
	fmt.Printf("  unload  measured=%d off=%d hung_or_unwoken=%d\n", r.Unload.N, r.Unload.Off, r.Unload.N-r.Unload.Off)
	fmt.Printf("  alarm wakes=%d unload-failed=%d unmeasured=%d\n", r.AlarmWakes, r.Invalid, r.Unmeasured)
	fmt.Printf("  verdict: %s\n", r.Verdict)
}
