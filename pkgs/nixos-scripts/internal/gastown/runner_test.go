package gastown

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type fakeExec struct {
	t            *testing.T
	job          string
	calls        []string
	hookState    string
	dirty        bool
	checkExit    map[string]int
	stream       string
	agentExit    string
	headMoves    bool
	started      bool
	statusSeen   int
	head         string
	beadState    string
	assignee     string
	stealOnStart bool
	onStart      func()
	stopFails    bool
	tmuxDir      string
}

func (f *fakeExec) Run(c Command) (Result, error) {
	key := filepath.Base(c.Name) + " " + strings.Join(c.Args, " ")
	f.calls = append(f.calls, key)
	ok := func(out string) (Result, error) { return Result{Stdout: []byte(out)}, nil }
	switch {
	case strings.HasPrefix(key, "git status"):
		f.statusSeen++
		if f.statusSeen == 1 && f.dirty {
			return ok(" M file.go\n")
		}
		if f.statusSeen > 1 {
			return ok(" M file.go\n")
		}
		return ok("")
	case strings.HasPrefix(key, "git rev-parse"):
		if f.headMoves && f.started {
			return ok("bbbb\n")
		}
		return ok("aaaa\n")
	case strings.HasPrefix(key, "git diff"):
		return ok(" file.go | 2 +-\n")
	case key == "gt dolt stop" && f.stopFails:
		return Result{Exit: 1}, nil
	case key == "gt dolt start", key == "gt dolt stop", strings.HasPrefix(key, "tmux"):
		return ok("")
	case strings.HasPrefix(key, "gt hook show"):
		if f.hookState == "empty" || f.hookState == "" {
			return ok(`{"status":"empty"}`)
		}
		return ok(`{"status":"hooked","bead_id":"app-xyz"}`)
	case strings.HasPrefix(key, "bd create"):
		return ok("app-xyz\n")
	case strings.HasPrefix(key, "gt hook app-xyz"):
		f.beadState = "hooked"
		return ok("")
	case strings.HasPrefix(key, "bd show"):
		who := "app/crew/worker"
		if f.assignee != "" {
			who = f.assignee
		}
		if f.stealOnStart && f.started {
			who = "app/crew/other"
		}
		return ok(`[{"id":"app-xyz","status":"` + f.beadState + `","assignee":"` + who + `"}]`)
	case strings.HasPrefix(key, "bd close"):
		f.beadState = "closed"
		return ok("")
	case strings.HasPrefix(key, "gt config agent set"):
		return ok("")
	case strings.HasPrefix(key, "gt crew start"):
		f.started = true
		for _, e := range c.Env {
			if v, ok := strings.CutPrefix(e, "TMUX_TMPDIR="); ok {
				f.tmuxDir = v
			}
		}
		if f.onStart != nil {
			f.onStart()
		}
		if err := os.WriteFile(filepath.Join(f.job, "stream.jsonl"), []byte(f.stream), 0o600); err != nil {
			f.t.Fatal(err)
		}
		exit := f.agentExit
		if exit == "" {
			exit = "0"
		}
		if err := os.WriteFile(filepath.Join(f.job, "exit-code.txt"), []byte(exit+"\n"), 0o600); err != nil {
			f.t.Fatal(err)
		}
		return ok("")
	case strings.HasPrefix(key, "gt unsling"):
		f.beadState = "open"
		f.hookState = "empty"
		return ok("")
	case strings.HasPrefix(key, "git "):
		return ok("")
	case filepath.Base(c.Name) == "bwrap":
		check := c.Args[len(c.Args)-1]
		return Result{Exit: f.checkExit[check]}, nil
	}
	f.t.Fatalf("unexpected command: %s", key)
	return Result{}, nil
}

const goodStream = `{"type":"item.completed","item":{"id":"1","type":"command_execution","exit_code":0}}
{"type":"turn.completed","usage":{}}
`

func newRunner(t *testing.T, f *fakeExec) (*Runner, string) {
	t.Helper()
	state := t.TempDir()
	job := filepath.Join(state, "runs", "app", "j1")
	if err := os.MkdirAll(job, 0o700); err != nil {
		t.Fatal(err)
	}
	ws := filepath.Join(state, "town", "app", "crew", "worker")
	if err := os.MkdirAll(ws, 0o700); err != nil {
		t.Fatal(err)
	}
	c := testConfig()
	c.State = state
	f.t, f.job = t, job
	if f.beadState == "" {
		f.beadState = "open"
	}
	return &Runner{Config: c, Exec: f, Self: "/nix/gastown-run", Poll: time.Millisecond, AgentDeadline: time.Second, MaxCommands: 60, TmuxBase: shortDir(t)}, job
}

func runTask(r *Runner, job string, checks ...string) (Report, error) {
	return r.RunTask(Project{Rig: "app", Crew: "worker"}, Task{Title: "t", Prompt: "do it", Checks: checks}, job)
}

func index(calls []string, prefix string) int {
	for i, call := range calls {
		if strings.HasPrefix(call, prefix) {
			return i
		}
	}
	return -1
}

func TestPassClosesOnlyAfterChecksAndAssignsFirst(t *testing.T) {
	f := &fakeExec{stream: goodStream, checkExit: map[string]int{"go test ./...": 0}}
	r, job := newRunner(t, f)
	report, err := runTask(r, job, "go test ./...")
	if err != nil || report.Status != "pass" || report.BeadState != "closed" {
		t.Fatalf("want pass/closed, got %+v err=%v", report, err)
	}
	hook, start, check, closeAt := index(f.calls, "gt hook app-xyz"), index(f.calls, "gt crew start"), index(f.calls, "bwrap"), index(f.calls, "bd close")
	if !(hook >= 0 && hook < start && start < check && check < closeAt) {
		t.Fatalf("bad ordering: %v", f.calls)
	}
	if index(f.calls, "gt dolt stop") < closeAt || index(f.calls, "tmux -L") < 0 {
		t.Fatalf("owned services must be stopped after closure: %v", f.calls)
	}
	if _, err := os.Stat(filepath.Join(job, "plan.json")); err != nil {
		t.Fatal("plan.json missing")
	}
	var saved Report
	data, _ := os.ReadFile(filepath.Join(job, "report.json"))
	if json.Unmarshal(data, &saved) != nil || saved.Status != "pass" || saved.BeadID != "app-xyz" {
		t.Fatalf("report not persisted: %s", data)
	}
}

func TestFailedCheckKeepsTaskOpen(t *testing.T) {
	f := &fakeExec{stream: goodStream, checkExit: map[string]int{"go test ./...": 1}}
	r, job := newRunner(t, f)
	report, _ := runTask(r, job, "go test ./...")
	if report.Status != "partial" || index(f.calls, "bd close") >= 0 || report.BeadState != "hooked" {
		t.Fatalf("failed check must not close: %+v calls=%v", report, f.calls)
	}
	if index(f.calls, "git -C") >= 0 && strings.Contains(strings.Join(f.calls, "\n"), "commit") {
		t.Fatal("failed task must not be committed")
	}
}

func TestOccupiedHookRefusesBeforeCreatingWork(t *testing.T) {
	f := &fakeExec{stream: goodStream, hookState: "hooked"}
	r, job := newRunner(t, f)
	report, _ := runTask(r, job)
	if report.Status != "partial" || index(f.calls, "bd create") >= 0 || !strings.Contains(report.Failure, "existing_hook_preserved") {
		t.Fatalf("occupied hook must refuse: %+v", report)
	}
}

func TestDirtyWorkspaceRefuses(t *testing.T) {
	f := &fakeExec{stream: goodStream, dirty: true}
	r, job := newRunner(t, f)
	report, _ := runTask(r, job)
	if !strings.Contains(report.Failure, "workspace_not_clean") || index(f.calls, "gt dolt start") >= 0 {
		t.Fatalf("dirty workspace must refuse before starting anything: %+v", report)
	}
}

func TestForbiddenToolAndNativeFailureDoNotClose(t *testing.T) {
	for name, f := range map[string]*fakeExec{
		"forbidden tool": {stream: `{"type":"item.started","item":{"id":"1","type":"web_search"}}` + "\n"},
		"native exit":    {stream: goodStream, agentExit: "3"},
		"no turn":        {stream: `{"type":"item.completed","item":{"id":"1","type":"command_execution","exit_code":0}}` + "\n"},
	} {
		r, job := newRunner(t, f)
		report, _ := runTask(r, job)
		if report.Status != "partial" || index(f.calls, "bd close") >= 0 {
			t.Errorf("%s: must not close: %+v", name, report)
		}
	}
}

func TestExecutorMovingHeadDoesNotClose(t *testing.T) {
	f := &fakeExec{stream: goodStream, headMoves: true}
	r, job := newRunner(t, f)
	report, _ := runTask(r, job)
	if report.Status != "partial" || index(f.calls, "bd close") >= 0 {
		t.Fatalf("moved HEAD must not close: %+v", report)
	}
}

func TestCommandBudget(t *testing.T) {
	var b strings.Builder
	for i := 0; i < 5; i++ {
		b.WriteString(`{"type":"item.completed","item":{"id":"` + string(rune('a'+i)) + `","type":"command_execution","exit_code":0}}` + "\n")
	}
	b.WriteString(`{"type":"turn.completed"}` + "\n")
	f := &fakeExec{stream: b.String()}
	r, job := newRunner(t, f)
	r.MaxCommands = 3
	report, _ := runTask(r, job)
	if report.Status != "partial" || !strings.Contains(report.Failure, "command_budget_exceeded") {
		t.Fatalf("budget not enforced: %+v", report)
	}
}

func TestWrongAssigneeRefusesBeforeDispatch(t *testing.T) {
	f := &fakeExec{stream: goodStream, assignee: "app/crew/other"}
	r, job := newRunner(t, f)
	report, _ := runTask(r, job)
	if report.Status != "partial" || report.Failure != "assignment_mismatch" || index(f.calls, "gt crew start") >= 0 {
		t.Fatalf("wrong assignee must stop before dispatch: %+v", report)
	}
}

func TestReassignedTaskIsNotClosed(t *testing.T) {
	f := &fakeExec{stream: goodStream, stealOnStart: true}
	r, job := newRunner(t, f)
	report, _ := runTask(r, job)
	if report.Status != "partial" || report.Failure != "assignment_changed" || index(f.calls, "bd close") >= 0 {
		t.Fatalf("reassigned task must not be closed: %+v", report)
	}
}

func abandonSetup(t *testing.T, status string) (*Runner, *fakeExec) {
	f := &fakeExec{hookState: "hooked", beadState: "hooked", statusSeen: 5}
	r, job := newRunner(t, f)
	_ = job
	dir := filepath.Join(r.Config.State, "runs", "app", "20261104T000000Z-01")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "bead.json"), []byte(`{"id":"app-xyz"}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if status != "" {
		data, _ := json.Marshal(Report{Status: status, BeadID: "app-xyz", BeadState: "hooked"})
		if err := os.WriteFile(filepath.Join(dir, "report.json"), data, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	return r, f
}

func TestAbandonPreservesWorkThenReleasesTask(t *testing.T) {
	r, f := abandonSetup(t, "partial")
	if _, err := r.Abandon(Project{Rig: "app", Crew: "worker"}); err != nil {
		t.Fatal(err)
	}
	stash, unsling := index(f.calls, "git stash"), index(f.calls, "gt unsling --force app-xyz")
	if stash < 0 || unsling < 0 || stash > unsling {
		t.Fatalf("work must be stashed before release: %v", f.calls)
	}
	if index(f.calls, "bd close") >= 0 || index(f.calls, "gt dolt stop") < unsling {
		t.Fatalf("abandon must not close the task and must stop dolt: %v", f.calls)
	}
}

func TestAbandonRefusesCompletedTask(t *testing.T) {
	r, f := abandonSetup(t, "pass")
	if _, err := r.Abandon(Project{Rig: "app", Crew: "worker"}); err == nil {
		t.Fatal("a passed task must not be abandoned")
	}
	if index(f.calls, "gt unsling") >= 0 {
		t.Fatal("nothing may be released")
	}
}

func TestAbandonRefusesWhenHookHoldsOtherWork(t *testing.T) {
	r, f := abandonSetup(t, "partial")
	f.hookState = "empty"
	if _, err := r.Abandon(Project{Rig: "app", Crew: "worker"}); err == nil {
		t.Fatal("must refuse when the hook does not hold the failed task")
	}
	if index(f.calls, "gt unsling") >= 0 || index(f.calls, "git stash") >= 0 {
		t.Fatalf("must change nothing: %v", f.calls)
	}
}

func TestCancellationPreservesTaskAndStopsServices(t *testing.T) {
	cancel := make(chan struct{})
	f := &fakeExec{stream: `{"type":"item.completed","item":{"id":"1","type":"command_execution","exit_code":0}}` + "\n"}
	f.onStart = func() {
		_ = os.Remove(filepath.Join(f.job, "exit-code.txt"))
		close(cancel)
	}
	r, job := newRunner(t, f)
	r.Cancel = cancel
	r.AgentDeadline = 5 * time.Second
	report, _ := runTask(r, job, "true")
	if !report.Cancelled || report.Status != "partial" || report.BeadID != "app-xyz" {
		t.Fatalf("cancellation must be recorded with the task id: %+v", report)
	}
	if index(f.calls, "bd close") >= 0 || index(f.calls, "gt dolt stop") < 0 || index(f.calls, "tmux -L") < 0 {
		t.Fatalf("task stays open and owned services stop: %v", f.calls)
	}
	data, err := os.ReadFile(filepath.Join(job, "report.json"))
	if err != nil || !strings.Contains(string(data), `"cancelled": true`) {
		t.Fatalf("checkpoint report missing: %s %v", data, err)
	}
}

func TestAbandonWorksAfterHardKillWithoutReport(t *testing.T) {
	r, f := abandonSetup(t, "")
	if _, err := r.Abandon(Project{Rig: "app", Crew: "worker"}); err != nil {
		t.Fatalf("a killed run leaves bead.json but no report: %v", err)
	}
	if index(f.calls, "gt unsling --force app-xyz") < 0 {
		t.Fatalf("task not released: %v", f.calls)
	}
}

func TestCancelledRunReportsServicesStoppedWhenPortIsFree(t *testing.T) {
	cancel := make(chan struct{})
	f := &fakeExec{stream: `{"type":"item.completed","item":{"id":"1","type":"command_execution","exit_code":0}}` + "\n"}
	f.onStart = func() {
		_ = os.Remove(filepath.Join(f.job, "exit-code.txt"))
		close(cancel)
	}
	r, job := newRunner(t, f)
	r.Cancel, r.PortFree = cancel, func(int) bool { return true }
	f.stopFails = true
	report, _ := runTask(r, job, "true")
	if !report.Cancelled || !report.ServicesOff {
		t.Fatalf("services killed by the cgroup are already stopped: %+v", report)
	}
	r2, job2 := newRunner(t, &fakeExec{stream: goodStream, stopFails: true})
	report2, _ := runTask(r2, job2)
	if report2.ServicesOff || report2.Status != "partial" {
		t.Fatalf("a failed dolt stop on a normal run must stay partial: %+v", report2)
	}
}

func shortDir(t *testing.T) string {
	t.Helper()
	dir, err := os.MkdirTemp("", "g")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(dir) })
	return dir
}

func writeTaskRecord(t *testing.T, state, dirName, record string) {
	t.Helper()
	dir := filepath.Join(state, "runs", "app", dirName)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "bead.json"), []byte(record), 0o600); err != nil {
		t.Fatal(err)
	}
}

func TestAbandonReleasesTheRequestedCrewsTask(t *testing.T) {
	f := &fakeExec{hookState: "hooked", beadState: "hooked", statusSeen: 5}
	r, _ := newRunner(t, f)
	writeTaskRecord(t, r.Config.State, "20261104T000000Z-01", `{"id":"app-xyz","crew":"a"}`)
	writeTaskRecord(t, r.Config.State, "20261104T000001Z-01", `{"id":"app-zzz","crew":"b"}`)
	if _, err := r.Abandon(Project{Rig: "app", Crew: "a"}); err != nil {
		t.Fatalf("abandoning crew a must find crew a's task, not crew b's newer one: %v", err)
	}
	if index(f.calls, "gt unsling --force app-xyz") < 0 {
		t.Fatalf("crew a's task not released: %v", f.calls)
	}
}

func TestRunTaskRecordsTheCrewInBeadJSON(t *testing.T) {
	f := &fakeExec{stream: goodStream, checkExit: map[string]int{"true": 0}}
	r, job := newRunner(t, f)
	if _, err := runTask(r, job, "true"); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(job, "bead.json"))
	if err != nil || !strings.Contains(string(data), `"crew":"worker"`) || !strings.Contains(string(data), `"id":"app-xyz"`) {
		t.Fatalf("bead.json must keep the id and record the crew: %s %v", data, err)
	}
}

func assertOutsideUntouched(t *testing.T, outside string) {
	t.Helper()
	entries, err := os.ReadDir(outside)
	if err != nil || len(entries) != 1 || entries[0].Name() != "keep" {
		t.Fatalf("the controller must not create anything outside the clone, got %v", entries)
	}
	if data, _ := os.ReadFile(filepath.Join(outside, "keep")); string(data) != "keep" {
		t.Fatalf("outside file changed: %q", data)
	}
}

func TestCheckLogsSymlinkCannotEscapeTheWorkspace(t *testing.T) {
	f := &fakeExec{stream: goodStream, checkExit: map[string]int{"true": 0}}
	r, job := newRunner(t, f)
	ws := r.Workspace(Project{Rig: "app", Crew: "worker"})
	outside := t.TempDir()
	if err := os.WriteFile(filepath.Join(outside, "keep"), []byte("keep"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(ws, ".logs")); err != nil {
		t.Fatal(err)
	}
	report, _ := runTask(r, job, "true")
	if report.Status != "pass" {
		t.Fatalf("a replaced .logs must be rebuilt inside the clone and the task pass: %+v", report)
	}
	assertOutsideUntouched(t, outside)
	info, err := os.Lstat(filepath.Join(ws, ".logs"))
	if err != nil || !info.IsDir() {
		t.Fatalf(".logs must be a real directory after the run: %v %v", info, err)
	}
}

func TestCheckLogsChildSymlinkCannotEscapeTheWorkspace(t *testing.T) {
	f := &fakeExec{stream: goodStream, checkExit: map[string]int{"true": 0}}
	r, job := newRunner(t, f)
	ws := r.Workspace(Project{Rig: "app", Crew: "worker"})
	outside := t.TempDir()
	if err := os.WriteFile(filepath.Join(outside, "keep"), []byte("keep"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(ws, ".logs"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(ws, ".logs", "gocache")); err != nil {
		t.Fatal(err)
	}
	report, _ := runTask(r, job, "true")
	if report.Status != "pass" {
		t.Fatalf("a symlinked cache must be replaced and the task pass: %+v", report)
	}
	assertOutsideUntouched(t, outside)
	info, err := os.Lstat(filepath.Join(ws, ".logs", "gocache"))
	if err != nil || !info.IsDir() {
		t.Fatalf("gocache must be a real directory after the run: %v %v", info, err)
	}
}
