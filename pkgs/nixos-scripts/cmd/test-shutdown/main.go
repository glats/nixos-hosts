package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/glats/nixos-scripts/internal/kmsg"
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

func usage() {
	fmt.Fprint(os.Stderr, `Usage:
  test-shutdown                      list trials and the recorded history
  sudo test-shutdown <trial>         apply one trial, record it, and power off
  sudo test-shutdown -n <trial>      dry run: show the steps, change nothing
  sudo test-shutdown result off|hung [note...]
                                     record what you saw after the last trial
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
	cmd := exec.Command("systemd-run", "--collect", "--unit=test-shutdown-"+id,
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
