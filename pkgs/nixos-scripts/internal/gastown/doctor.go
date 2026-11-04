package gastown

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

var expectedProbe = map[string]string{
	"write_workspace": "allowed",
	"write_git":       "denied",
	"write_beads":     "denied",
	"read_outside":    "denied",
	"write_outside":   "denied",
	"list_home":       "denied",
	"network":         "denied",
}

func ProbeScript(canary string, port int) string {
	return `t() { if eval "$2" 2>/dev/null; then echo "$1=allowed"; else echo "$1=denied"; fi; }
t write_workspace 'if [ -e .doctor-probe ]; then : >> .doctor-probe; else : >> .doctor-probe && rm -f .doctor-probe; fi'
t write_git ': >> .git/config'
t write_beads 'if [ -e .beads/doctor-probe ]; then : >> .beads/doctor-probe; else : >> .beads/doctor-probe && rm -f .beads/doctor-probe; fi'
t read_outside 'cat ` + canary + ` > /dev/null'
t write_outside ': >> ` + canary + `'
t list_home 'ls /home > /dev/null'
t network 'exec 3<>/dev/tcp/127.0.0.1/` + strconv.Itoa(port) + `'
`
}

// EvaluateProbe requires every probe to report exactly the expected outcome.
func EvaluateProbe(output string) error {
	seen := map[string]string{}
	for _, line := range strings.Split(output, "\n") {
		if name, value, ok := strings.Cut(strings.TrimSpace(line), "="); ok {
			seen[name] = value
		}
	}
	var bad []string
	for name, want := range expectedProbe {
		if got := seen[name]; got != want {
			bad = append(bad, fmt.Sprintf("%s=%q (want %s)", name, got, want))
		}
	}
	sort.Strings(bad)
	if len(bad) > 0 {
		return errors.New("sandbox boundary mismatch: " + strings.Join(bad, ", "))
	}
	return nil
}

// Doctor proves, without a model, that the executor policy confines the worker
// clone. It runs probes inside the same Codex sandbox policy a task would use.
func (r *Runner) Doctor(p Project, out io.Writer) error {
	c := r.Config
	workspace := r.Workspace(p)
	if _, err := os.Stat(workspace); err != nil {
		return errors.New("worker clone not found: " + workspace)
	}
	dir := filepath.Join(c.State, "doctor")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	token := make([]byte, 16)
	if _, err := rand.Read(token); err != nil {
		return err
	}
	canary := filepath.Join(dir, "canary-"+hex.EncodeToString(token[:4]))
	if err := os.WriteFile(canary, []byte(hex.EncodeToString(token)+"\n"), 0o600); err != nil {
		return err
	}
	defer os.Remove(canary)
	before, _ := os.ReadFile(canary)

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return err
	}
	defer listener.Close()
	port := listener.Addr().(*net.TCPAddr).Port

	job := filepath.Join(dir, "job")
	for _, name := range []string{"tmp", "state", "logs"} {
		if err := os.MkdirAll(filepath.Join(job, name), 0o700); err != nil {
			return err
		}
	}
	args := []string{"sandbox"}
	probe := c
	probe.ToolPath = c.ToolPath + ":" + filepath.Dir(c.Bwrap)
	args = append(args, PolicyArgs(probe, workspace, job)...)
	args = append(args, "-P", "pilot", "--", c.Bash, "-c", ProbeScript(canary, port))
	res, err := r.Exec.Run(Command{Name: c.Codex, Args: args, Dir: workspace, Env: NativeEnv(c, job), Timeout: time.Minute})
	if err != nil {
		return err
	}
	after, _ := os.ReadFile(canary)
	if string(before) != string(after) {
		return errors.New("sandbox boundary mismatch: canary outside the workspace was modified")
	}
	if err := EvaluateProbe(string(res.Stdout)); err != nil {
		return fmt.Errorf("%w (exit %d): %s", err, res.Exit, strings.TrimSpace(string(res.Stderr)))
	}
	fmt.Fprintln(out, "sandbox boundary verified: workspace writable; repo, task metadata, outside paths and network denied")
	return nil
}
