package gastown

import (
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const realGasTownIgnoreBlock = "\n# Gas Town (added by gt)\n.runtime/\n.claude/\n.opencode/\n.logs/\n__pycache__/\nstate.json\nCLAUDE.md\nCLAUDE.local.md\nGEMINI.md\n"

func trackedIgnoreRepo(t *testing.T, committed string) string {
	t.Helper()
	dir := t.TempDir()
	gitIn(t, dir, "init", "-q", "-b", "main")
	if err := os.WriteFile(filepath.Join(dir, ".gitignore"), []byte(committed), 0o600); err != nil {
		t.Fatal(err)
	}
	gitIn(t, dir, "add", "-A")
	gitIn(t, dir, "commit", "-q", "-m", "init")
	return dir
}

func writeIgnore(t *testing.T, dir, content string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(dir, ".gitignore"), []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
}

func readIgnore(t *testing.T, dir string) string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(dir, ".gitignore"))
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func TestCleanGasTownIgnoreRestoresCommittedGitignore(t *testing.T) {
	dir := trackedIgnoreRepo(t, "bin/\n")
	writeIgnore(t, dir, "bin/\n"+realGasTownIgnoreBlock)
	if err := CleanGasTownIgnore(dir); err != nil {
		t.Fatal(err)
	}
	if got := strings.TrimSpace(gitIn(t, dir, "status", "--porcelain")); got != "" {
		t.Fatalf("gt-added block must not leave a tracked .gitignore change, got %q", got)
	}
	if got := readIgnore(t, dir); got != "bin/\n" {
		t.Fatalf("committed content not restored: %q", got)
	}
}

func TestCleanGasTownIgnoreKeepsExecutorEdits(t *testing.T) {
	dir := trackedIgnoreRepo(t, "bin/\n")
	writeIgnore(t, dir, "bin/\nobj/\n"+realGasTownIgnoreBlock)
	if err := CleanGasTownIgnore(dir); err != nil {
		t.Fatal(err)
	}
	if got := readIgnore(t, dir); got != "bin/\nobj/\n" {
		t.Fatalf("only the gt block may be removed, got %q", got)
	}
	if got := gitIn(t, dir, "status", "--porcelain"); !strings.Contains(got, ".gitignore") {
		t.Fatalf("a genuine .gitignore edit must stay visible, got %q", got)
	}
}

func TestCleanGasTownIgnoreKeepsCommittedPatternsIntact(t *testing.T) {
	dir := trackedIgnoreRepo(t, "bin/\n.logs/\n")
	writeIgnore(t, dir, "bin/\n.logs/\n"+realGasTownIgnoreBlock)
	if err := CleanGasTownIgnore(dir); err != nil {
		t.Fatal(err)
	}
	if got := readIgnore(t, dir); got != "bin/\n.logs/\n" {
		t.Fatalf("committed .logs/ must survive, got %q", got)
	}
	if got := strings.TrimSpace(gitIn(t, dir, "status", "--porcelain")); got != "" {
		t.Fatalf("expected a clean workspace, got %q", got)
	}
}

func TestCleanGasTownIgnoreIgnoresUntrackedGitignore(t *testing.T) {
	dir := t.TempDir()
	gitIn(t, dir, "init", "-q", "-b", "main")
	writeIgnore(t, dir, "bin/\n"+realGasTownIgnoreBlock)
	if err := CleanGasTownIgnore(dir); err != nil {
		t.Fatal(err)
	}
	if got := readIgnore(t, dir); got != "bin/\n"+realGasTownIgnoreBlock {
		t.Fatalf("an untracked .gitignore is hidden by ExcludeInfra, not rewritten: %q", got)
	}
}

func TestRunTaskRemovesGasTownIgnoreBeforeChecksAndCommit(t *testing.T) {
	f := &fakeExec{stream: goodStream, checkExit: map[string]int{"true": 0}}
	r, job := newRunner(t, f)
	ws := r.Workspace(Project{Rig: "app", Crew: "worker"})
	gitIn(t, ws, "init", "-q", "-b", "main")
	writeIgnore(t, ws, "bin/\n")
	gitIn(t, ws, "add", "-A")
	gitIn(t, ws, "commit", "-q", "-m", "init")
	writeIgnore(t, ws, "bin/\n"+realGasTownIgnoreBlock)
	f.onStart = func() { writeIgnore(t, ws, "bin/\n"+realGasTownIgnoreBlock) }
	report, err := runTask(r, job, "true")
	if err != nil || report.Status != "pass" {
		t.Fatalf("a gt-added .gitignore block must not block the run: %+v err=%v", report, err)
	}
	if got := readIgnore(t, ws); got != "bin/\n" {
		t.Fatalf("gt re-added block must be removed before the commit, got %q", got)
	}
}

type scriptedExec struct {
	onCrewAdd func()
}

func (s *scriptedExec) Run(c Command) (Result, error) {
	if len(c.Args) > 1 && c.Args[0] == "crew" && c.Args[1] == "add" {
		s.onCrewAdd()
	}
	return Result{}, nil
}

func runAddProject(t *testing.T, branch, committed, gitignoreAfterAdd string) (string, string, error) {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Skip("loopback unavailable")
	}
	port := listener.Addr().(*net.TCPAddr).Port
	listener.Close()
	c := testConfig()
	c.State, c.DoltPort = t.TempDir(), port
	town := filepath.Join(c.State, "town")
	if err := os.MkdirAll(filepath.Join(town, "mayor"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(town, "mayor", "town.json"), []byte("{}"), 0o600); err != nil {
		t.Fatal(err)
	}
	repo := trackedIgnoreRepo(t, committed)
	ws := filepath.Join(town, "demo", "crew", "worker")
	ex := &scriptedExec{onCrewAdd: func() {
		if err := os.MkdirAll(ws, 0o700); err != nil {
			t.Fatal(err)
		}
		gitIn(t, ws, "init", "-q", "-b", branch)
		writeIgnore(t, ws, committed)
		gitIn(t, ws, "add", "-A")
		gitIn(t, ws, "commit", "-q", "-m", "init")
		writeIgnore(t, ws, gitignoreAfterAdd)
	}}
	var out strings.Builder
	err = AddProject(c, ex, "demo", "worker", repo, &out)
	return ws, out.String(), err
}

func TestAddProjectRemovesGasTownIgnoreFromTrackedGitignore(t *testing.T) {
	ws, _, err := runAddProject(t, "main", "bin/\n", "bin/\n"+realGasTownIgnoreBlock)
	if err != nil {
		t.Fatal(err)
	}
	if got := readIgnore(t, ws); got != "bin/\n" {
		t.Fatalf("add must leave the committed .gitignore, got %q", got)
	}
	if got := strings.TrimSpace(gitIn(t, ws, "status", "--porcelain")); got != "" {
		t.Fatalf("worker must be clean after add, got %q", got)
	}
}

func TestAddProjectPrintsTheMergeCommandForTheWorkerBranch(t *testing.T) {
	ws, out, err := runAddProject(t, "master", "bin/\n", "bin/\n")
	if err != nil {
		t.Fatal(err)
	}
	if want := "git pull " + ws + " master"; !strings.Contains(out, want) {
		t.Fatalf("add must print the merge command with the worker branch %q, got:\n%s", want, out)
	}
}

func TestWorkerBranchReadsTheCurrentBranch(t *testing.T) {
	dir := t.TempDir()
	gitIn(t, dir, "init", "-q", "-b", "master")
	writeIgnore(t, dir, "bin/\n")
	gitIn(t, dir, "add", "-A")
	gitIn(t, dir, "commit", "-q", "-m", "init")
	branch, err := WorkerBranch(dir)
	if err != nil || branch != "master" {
		t.Fatalf("a master-only worker must report master, got %q err=%v", branch, err)
	}
}

func TestCleanGasTownIgnoreRestoresFileCommittedWithoutTrailingNewline(t *testing.T) {
	dir := trackedIgnoreRepo(t, "bin/")
	writeIgnore(t, dir, "bin/"+realGasTownIgnoreBlock)
	if err := CleanGasTownIgnore(dir); err != nil {
		t.Fatal(err)
	}
	if got := strings.TrimSpace(gitIn(t, dir, "status", "--porcelain")); got != "" {
		t.Fatalf("a file committed without a trailing newline must come back clean, got %q", got)
	}
	if got := readIgnore(t, dir); got != "bin/" {
		t.Fatalf("committed bytes not restored: %q", got)
	}
}

func TestCleanGasTownIgnoreKeepsRealEditWhenCommittedHasNoTrailingNewline(t *testing.T) {
	dir := trackedIgnoreRepo(t, "bin/")
	writeIgnore(t, dir, "bin/\nobj/\n"+realGasTownIgnoreBlock)
	if err := CleanGasTownIgnore(dir); err != nil {
		t.Fatal(err)
	}
	got := readIgnore(t, dir)
	if !strings.Contains(got, "obj/") || strings.Contains(got, "Gas Town") {
		t.Fatalf("genuine edit must survive without the gt block: %q", got)
	}
}
