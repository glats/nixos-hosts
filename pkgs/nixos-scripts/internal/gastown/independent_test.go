package gastown

import (
	"bytes"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"
)

func TestIndependentRejectsBlankChecks(t *testing.T) {
	for _, check := range []string{`""`, `"   "`, `"\t\n"`} {
		data := []byte(`[{"title":"t","prompt":"p","checks":[` + check + `]}]`)
		if _, err := ParseTasks(data); err == nil {
			t.Fatalf("accepted blank check %s", check)
		}
	}
}

func TestIndependentRejectsConflictingCheckSources(t *testing.T) {
	t.Setenv("GASTOWN_IN_UNIT", "1")
	dir := t.TempDir()
	path := filepath.Join(dir, "tasks.json")
	if err := os.WriteFile(path, []byte(`[{"title":"t","prompt":"p","checks":["true"]}]`), 0o600); err != nil {
		t.Fatal(err)
	}
	var out, stderr bytes.Buffer
	code := runCommand(Config{State: dir}, []string{"--tasks", path, "--check", "exit 99", "demo"}, &out, &stderr)
	if code != 2 || !strings.Contains(stderr.String(), "--check") {
		t.Fatalf("explicit --check with --tasks must be rejected, got %d: %s", code, stderr.String())
	}
}

func TestIndependentJobDirectoriesAreUniqueAndExclusive(t *testing.T) {
	state := t.TempDir()
	seen := map[string]bool{}
	for i := 0; i < 20; i++ {
		dir, err := NewJobDir(state, "app", 1)
		if err != nil {
			t.Fatal(err)
		}
		if seen[dir] {
			t.Fatalf("job directory reused: %s", dir)
		}
		seen[dir] = true
		if err := os.WriteFile(filepath.Join(dir, "report.json"), []byte(dir), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	for dir := range seen {
		if data, _ := os.ReadFile(filepath.Join(dir, "report.json")); string(data) != dir {
			t.Fatalf("artifact overwritten in %s", dir)
		}
	}
}

func TestIndependentTruncatedExitCodeIsNotSuccess(t *testing.T) {
	f := &fakeExec{stream: goodStream, agentExit: "not-a-number"}
	r, job := newRunner(t, f)
	report, _ := runTask(r, job)
	if report.Status != "partial" || index(f.calls, "bd close") >= 0 {
		t.Fatalf("an unreadable exit code must not close the task: %+v", report)
	}
}

func TestIndependentNewlineInPathsIsRefused(t *testing.T) {
	f := &fakeExec{stream: goodStream}
	r, job := newRunner(t, f)
	r.Self = "/nix/bin/gastown-run\nrm"
	report, _ := runTask(r, job)
	if report.Failure != "unsafe_agent_command_path" || index(f.calls, "gt crew start") >= 0 {
		t.Fatalf("newline in the agent command path must be refused: %+v", report)
	}
}

func longJob(t *testing.T, r *Runner) string {
	t.Helper()
	job := filepath.Join(r.Config.State, "runs", "app", strings.Repeat("x", 80), "20261104T153416.928221856Z-01")
	if err := os.MkdirAll(job, 0o700); err != nil {
		t.Fatal(err)
	}
	return job
}

func TestIndependentOverlongTmuxSocketFailsClosedBeforeAnyService(t *testing.T) {
	f := &fakeExec{stream: goodStream}
	r, _ := newRunner(t, f)
	job := longJob(t, r)
	f.job = job
	r.TmuxBase = ""
	report, _ := runTask(r, job)
	if report.Failure != "tmux_socket_path_too_long" || index(f.calls, "gt dolt start") >= 0 {
		t.Fatalf("an unusable socket path must refuse before starting services: %+v", report)
	}
}

func TestIndependentShortTmuxBaseKeepsLongJobPathsWorking(t *testing.T) {
	f := &fakeExec{stream: goodStream}
	r, _ := newRunner(t, f)
	job := longJob(t, r)
	f.job = job
	r.TmuxBase = shortDir(t)
	report, err := runTask(r, job)
	if err != nil || report.Status != "pass" {
		t.Fatalf("a short tmux base must make long job paths work: %+v err=%v", report, err)
	}
	if !strings.HasPrefix(f.tmuxDir, r.TmuxBase) {
		t.Fatalf("tmux must use the short base, got %q", f.tmuxDir)
	}
	if _, statErr := os.Stat(f.tmuxDir); !os.IsNotExist(statErr) {
		t.Fatal("the temporary tmux directory must be removed after the run")
	}
}

func TestUnitFlagsKeepTheCallerWorkingDirectory(t *testing.T) {
	flags := UnitFlags(15*time.Minute, "demo", "/home/u/work")
	if !slices.Contains(flags, "--working-directory=/home/u/work") {
		t.Fatalf("the transient unit must run in the caller's directory so relative --tasks paths resolve: %v", flags)
	}
}
