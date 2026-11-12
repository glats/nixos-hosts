package gastown

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

func writeIn(t *testing.T, dir, rel, content string) {
	t.Helper()
	path := filepath.Join(dir, rel)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

type gateFixture struct {
	rig, staging string
	base         string
}

func newGateFixture(t *testing.T, baseFiles map[string]string, branchEdit func(work string)) gateFixture {
	t.Helper()
	root := t.TempDir()
	work := filepath.Join(root, "work")
	gitIn(t, root, "init", "-q", "-b", "main", work)
	for name, content := range baseFiles {
		writeIn(t, work, name, content)
	}
	gitIn(t, work, "add", "-A")
	gitIn(t, work, "commit", "-q", "-m", "init")
	gitIn(t, work, "checkout", "-q", "-b", "polecat/a/toy-1+x")
	branchEdit(work)
	gitIn(t, work, "add", "-A")
	gitIn(t, work, "commit", "-q", "-m", "feat: add abs (toy-1)")
	gitIn(t, work, "checkout", "-q", "main")
	rig := filepath.Join(root, "rig.git")
	gitIn(t, root, "clone", "-q", "--bare", work, rig)
	staging := filepath.Join(root, "staging.git")
	gitIn(t, root, "clone", "-q", "--bare", work, staging)
	return gateFixture{rig: rig, staging: staging, base: "main"}
}

func gateInput(f gateFixture, t *testing.T) GateInput {
	return GateInput{RigRepo: f.rig, Branch: "polecat/a/toy-1+x", Base: f.base, Bead: "toy-1", Staging: f.staging, WorkDir: filepath.Join(t.TempDir(), "gate")}
}

func passChecks(string, []string) []CheckResult { return []CheckResult{{Command: "go test", Exit: 0}} }
func failChecks(string, []string) []CheckResult { return []CheckResult{{Command: "go test", Exit: 1}} }

func publishedFiles(t *testing.T, f gateFixture, branch string) []string {
	t.Helper()
	out := strings.Fields(gitIn(t, f.staging, "diff", "--name-only", "--no-renames", "main", branch))
	sort.Strings(out)
	return out
}

func TestGateDropsGasTownFilesAndPublishesOnlyTheRequestedChange(t *testing.T) {
	f := newGateFixture(t, map[string]string{"main.go": "package main\n"}, func(w string) {
		writeIn(t, w, "abs.go", "package main\n")
		writeIn(t, w, ".beads/redirect", "x")
		writeIn(t, w, ".runtime/agent.lock.flock", "")
		writeIn(t, w, "CLAUDE.md", "overlay")
	})
	res := (&Runner{}).Gate(gateInput(f, t), passChecks)
	if res.Status != "pass" || res.Published != "gastown/toy-1" {
		t.Fatalf("unexpected result: %+v", res)
	}
	if got := publishedFiles(t, f, "gastown/toy-1"); strings.Join(got, ",") != "abs.go" {
		t.Fatalf("published files = %v, want only abs.go", got)
	}
	if len(res.Dropped) != 3 {
		t.Fatalf("dropped = %v", res.Dropped)
	}
}

func TestGateDoesNotPublishWhenChecksFail(t *testing.T) {
	f := newGateFixture(t, map[string]string{"main.go": "package main\n"}, func(w string) { writeIn(t, w, "abs.go", "package main\n") })
	res := (&Runner{}).Gate(gateInput(f, t), failChecks)
	if res.Status != "fail" || res.Published != "" {
		t.Fatalf("failing checks must not publish: %+v", res)
	}
	if out := gitIn(t, f.staging, "branch", "--list", "gastown/*"); strings.TrimSpace(out) != "" {
		t.Fatalf("branch leaked into staging: %q", out)
	}
}

func TestGateReportsEmptyWhenOnlyInfrastructureChanged(t *testing.T) {
	f := newGateFixture(t, map[string]string{"main.go": "package main\n"}, func(w string) {
		writeIn(t, w, ".beads/redirect", "x")
	})
	res := (&Runner{}).Gate(gateInput(f, t), passChecks)
	if res.Status != "empty" || res.Published != "" {
		t.Fatalf("expected empty: %+v", res)
	}
}

func TestGateHonorsDeletionsAndKeepsProjectOwnedAgentFiles(t *testing.T) {
	f := newGateFixture(t, map[string]string{"main.go": "package main\n", "old.go": "package main\n", "CLAUDE.md": "project rules\n"}, func(w string) {
		if err := os.Remove(filepath.Join(w, "old.go")); err != nil {
			t.Fatal(err)
		}
		writeIn(t, w, "CLAUDE.md", "project rules\nmore\n")
		writeIn(t, w, "abs.go", "package main\n")
	})
	res := (&Runner{}).Gate(gateInput(f, t), passChecks)
	if res.Status != "pass" {
		t.Fatalf("unexpected: %+v", res)
	}
	got := publishedFiles(t, f, "gastown/toy-1")
	if strings.Join(got, ",") != "CLAUDE.md,abs.go,old.go" {
		t.Fatalf("published = %v", got)
	}
	if !strings.Contains(strings.Join(res.Notes, " "), "CLAUDE.md") {
		t.Fatalf("a changed project-owned agent file must be flagged for review: %+v", res.Notes)
	}
}

func TestInfrastructurePathPolicy(t *testing.T) {
	for _, tc := range []struct {
		path    string
		inBase  bool
		dropped bool
	}{
		{".beads/redirect", false, true}, {".runtime/x", false, true}, {".logs/x", false, true}, {".beads/x", true, true},
		{"CLAUDE.md", false, true}, {"CLAUDE.md", true, false}, {".opencode/plugins/gastown.js", false, true},
		{".opencode/agents/a.md", true, false}, {"src/main.go", false, false}, {"state.json", false, true},
	} {
		if got := IsInfrastructure(tc.path, tc.inBase); got != tc.dropped {
			t.Errorf("IsInfrastructure(%q, inBase=%v)=%v want %v", tc.path, tc.inBase, got, tc.dropped)
		}
	}
}

func TestGateStripsTheGasTownBlockFromATrackedGitignore(t *testing.T) {
	f := newGateFixture(t, map[string]string{"main.go": "package main\n", ".gitignore": "bin/\n"}, func(w string) {
		writeIn(t, w, ".gitignore", "bin/\n"+realGasTownIgnoreBlock)
		writeIn(t, w, "abs.go", "package main\n")
	})
	res := (&Runner{}).Gate(gateInput(f, t), passChecks)
	if res.Status != "pass" {
		t.Fatalf("unexpected: %+v", res)
	}
	if got := publishedFiles(t, f, "gastown/toy-1"); strings.Join(got, ",") != "abs.go" {
		t.Fatalf("a gt-only .gitignore change must not be published, got %v", got)
	}
}

func TestGateKeepsARealGitignoreEditButNotTheGasTownBlock(t *testing.T) {
	f := newGateFixture(t, map[string]string{"main.go": "package main\n", ".gitignore": "bin/\n"}, func(w string) {
		writeIn(t, w, ".gitignore", "bin/\n*.tmp\n"+realGasTownIgnoreBlock)
		writeIn(t, w, "abs.go", "package main\n")
	})
	res := (&Runner{}).Gate(gateInput(f, t), passChecks)
	if res.Status != "pass" {
		t.Fatalf("unexpected: %+v", res)
	}
	if got := publishedFiles(t, f, "gastown/toy-1"); strings.Join(got, ",") != ".gitignore,abs.go" {
		t.Fatalf("published = %v", got)
	}
	content := gitIn(t, f.staging, "show", "gastown/toy-1:.gitignore")
	if !strings.Contains(content, "*.tmp") || strings.Contains(content, "Gas Town") {
		t.Fatalf("published .gitignore = %q", content)
	}
}

func TestGateKeepsAGitignoreThePolecatCreatedFromScratch(t *testing.T) {
	f := newGateFixture(t, map[string]string{"main.go": "package main\n"}, func(w string) {
		writeIn(t, w, ".gitignore", "bin/\n"+realGasTownIgnoreBlock)
		writeIn(t, w, "abs.go", "package main\n")
	})
	res := (&Runner{}).Gate(gateInput(f, t), passChecks)
	if res.Status != "pass" {
		t.Fatalf("unexpected: %+v", res)
	}
	content := gitIn(t, f.staging, "show", "gastown/toy-1:.gitignore")
	if strings.TrimSpace(content) != "bin/" {
		t.Fatalf("a new .gitignore must keep its own lines only, got %q", content)
	}
}

func TestGateDropsInfrastructureLinesTheWorkerAddedToGitignoreItself(t *testing.T) {
	f := newGateFixture(t, map[string]string{"main.go": "package main\n", ".gitignore": "bin/\n"}, func(w string) {
		writeIn(t, w, ".gitignore", "bin/\n.beads/\n.runtime/\nCLAUDE.md\n")
		writeIn(t, w, "abs.go", "package main\n")
	})
	res := (&Runner{}).Gate(gateInput(f, t), passChecks)
	if res.Status != "pass" {
		t.Fatalf("unexpected: %+v", res)
	}
	if got := publishedFiles(t, f, "gastown/toy-1"); strings.Join(got, ",") != "abs.go" {
		t.Fatalf("self-added infrastructure ignore lines must not be published, got %v", got)
	}
}

func TestGateKeepsRealIgnoreLinesNextToSelfAddedInfrastructureOnes(t *testing.T) {
	f := newGateFixture(t, map[string]string{"main.go": "package main\n", ".gitignore": "bin/\n"}, func(w string) {
		writeIn(t, w, ".gitignore", "bin/\n*.tmp\n.beads/\n.runtime/\n")
		writeIn(t, w, "abs.go", "package main\n")
	})
	res := (&Runner{}).Gate(gateInput(f, t), passChecks)
	content := gitIn(t, f.staging, "show", "gastown/toy-1:.gitignore")
	if res.Status != "pass" || strings.TrimSpace(content) != "bin/\n*.tmp" {
		t.Fatalf("status=%s .gitignore=%q", res.Status, content)
	}
}

func TestGateKeepsInfrastructureIgnoreLinesTheProjectAlreadyOwns(t *testing.T) {
	f := newGateFixture(t, map[string]string{"main.go": "package main\n", ".gitignore": "bin/\n.runtime/\n"}, func(w string) {
		writeIn(t, w, ".gitignore", "bin/\n.runtime/\nextra/\n")
		writeIn(t, w, "abs.go", "package main\n")
	})
	(&Runner{}).Gate(gateInput(f, t), passChecks)
	content := gitIn(t, f.staging, "show", "gastown/toy-1:.gitignore")
	if !strings.Contains(content, ".runtime/") || !strings.Contains(content, "extra/") {
		t.Fatalf("lines the project already had must stay: %q", content)
	}
}

func TestGateDropsNewBinaryFilesAndSaysSo(t *testing.T) {
	f := newGateFixture(t, map[string]string{"main.go": "package main\n"}, func(w string) {
		writeIn(t, w, "abs.go", "package main\n")
		writeIn(t, w, "calc", "\x7fELF\x00\x01\x02\x00binary")
	})
	res := (&Runner{}).Gate(gateInput(f, t), passChecks)
	if res.Status != "pass" || strings.Join(publishedFiles(t, f, "gastown/toy-1"), ",") != "abs.go" {
		t.Fatalf("a new binary must not be published: %+v", res)
	}
	if strings.Join(res.Dropped, ",") != "calc" || !strings.Contains(strings.Join(res.Notes, " "), "binary") {
		t.Fatalf("the drop must be reported: dropped=%v notes=%v", res.Dropped, res.Notes)
	}
}

func TestGateFlagsEditsToFilesThatAlreadyExisted(t *testing.T) {
	f := newGateFixture(t, map[string]string{"main.go": "package main\n", "keep.go": "package main\n"}, func(w string) {
		writeIn(t, w, "main.go", "package main\n// edited\n")
		writeIn(t, w, "abs.go", "package main\n")
	})
	res := (&Runner{}).Gate(gateInput(f, t), passChecks)
	if res.Status != "pass" {
		t.Fatalf("unexpected: %+v", res)
	}
	notes := strings.Join(res.Notes, " ")
	if !strings.Contains(notes, "main.go") || strings.Contains(notes, "abs.go") || strings.Contains(notes, "keep.go") {
		t.Fatalf("only the edited pre-existing file must be flagged, got %v", res.Notes)
	}
}

func TestProtectedPathPolicy(t *testing.T) {
	protect := []string{"main.go", "cmd/", "docs/api.md"}
	for path, want := range map[string]bool{"main.go": true, "cmd/x/main.go": true, "cmd": false, "docs/api.md": true, "docs/other.md": false, "sub/main.go": false, "abs.go": false} {
		if got := IsProtected(path, protect); got != want {
			t.Errorf("IsProtected(%q)=%v want %v", path, got, want)
		}
	}
}

func TestGateRefusesAndPublishesNothingWhenAProtectedFileChanges(t *testing.T) {
	for name, edit := range map[string]func(string){
		"edit":   func(w string) { writeIn(t, w, "main.go", "package main\n// changed\n") },
		"delete": func(w string) { _ = os.Remove(filepath.Join(w, "main.go")) },
	} {
		f := newGateFixture(t, map[string]string{"main.go": "package main\n"}, func(w string) { edit(w); writeIn(t, w, "abs.go", "package main\n") })
		in := gateInput(f, t)
		in.Protect = []string{"main.go"}
		res := (&Runner{}).Gate(in, passChecks)
		if res.Status != "fail" || res.Published != "" || !strings.Contains(res.Detail, "main.go") {
			t.Errorf("%s: protected change must fail: %+v", name, res)
		}
		if out := gitIn(t, f.staging, "branch", "--list", "gastown/*"); strings.TrimSpace(out) != "" {
			t.Errorf("%s: branch leaked: %q", name, out)
		}
	}
}

func TestGateAllowsUnprotectedChangesWhenProtectionIsConfigured(t *testing.T) {
	f := newGateFixture(t, map[string]string{"main.go": "package main\n"}, func(w string) { writeIn(t, w, "abs.go", "package main\n") })
	in := gateInput(f, t)
	in.Protect = []string{"main.go"}
	if res := (&Runner{}).Gate(in, passChecks); res.Status != "pass" {
		t.Fatalf("unexpected: %+v", res)
	}
}

type integrationFixture struct{ staging string }

func newIntegrationFixture(t *testing.T, branches map[string]map[string]string) integrationFixture {
	t.Helper()
	root := t.TempDir()
	work := filepath.Join(root, "work")
	gitIn(t, root, "init", "-q", "-b", "main", work)
	writeIn(t, work, "main.go", "package main\n")
	writeIn(t, work, "shared.txt", "base\n")
	gitIn(t, work, "add", "-A")
	gitIn(t, work, "commit", "-q", "-m", "init")
	for name, files := range branches {
		gitIn(t, work, "checkout", "-q", "-B", "gastown/"+name, "main")
		for file, content := range files {
			writeIn(t, work, file, content)
		}
		gitIn(t, work, "add", "-A")
		gitIn(t, work, "commit", "-q", "-m", "feat "+name)
	}
	gitIn(t, work, "checkout", "-q", "main")
	staging := filepath.Join(root, "staging.git")
	gitIn(t, root, "clone", "-q", "--bare", work, staging)
	return integrationFixture{staging: staging}
}

func TestIntegratePublishesAllAcceptedBranchesTogetherWhenChecksPass(t *testing.T) {
	f := newIntegrationFixture(t, map[string]map[string]string{"a": {"a.go": "package main\n"}, "b": {"b.go": "package main\n"}})
	res := Integrate(f.staging, filepath.Join(t.TempDir(), "int"), "main", []string{"gastown/a", "gastown/b"}, passChecks)
	if res.Status != "pass" || res.Published != "gastown/integrated" || len(res.Branches) != 2 {
		t.Fatalf("unexpected: %+v", res)
	}
	files := strings.Fields(gitIn(t, f.staging, "diff", "--name-only", "--no-renames", "main", "gastown/integrated"))
	sort.Strings(files)
	if strings.Join(files, ",") != "a.go,b.go" {
		t.Fatalf("integrated files = %v", files)
	}
}

func TestIntegrateReportsTheConflictingBranchesAndPublishesNothing(t *testing.T) {
	f := newIntegrationFixture(t, map[string]map[string]string{"a": {"shared.txt": "from a\n"}, "b": {"shared.txt": "from b\n"}})
	res := Integrate(f.staging, filepath.Join(t.TempDir(), "int"), "main", []string{"gastown/a", "gastown/b"}, passChecks)
	if res.Status != "conflict" || res.Published != "" || res.Conflict == "" {
		t.Fatalf("a conflict must be reported: %+v", res)
	}
	if out := gitIn(t, f.staging, "branch", "--list", "gastown/integrated"); strings.TrimSpace(out) != "" {
		t.Fatalf("integrated branch leaked: %q", out)
	}
}

func TestIntegrateDoesNotPublishWhenCombinedChecksFail(t *testing.T) {
	f := newIntegrationFixture(t, map[string]map[string]string{"a": {"a.go": "package main\n"}, "b": {"b.go": "package main\n"}})
	res := Integrate(f.staging, filepath.Join(t.TempDir(), "int"), "main", []string{"gastown/a", "gastown/b"}, failChecks)
	if res.Status != "fail" || res.Published != "" {
		t.Fatalf("unexpected: %+v", res)
	}
}

func TestIntegrateIsQuietWithFewerThanTwoBranches(t *testing.T) {
	f := newIntegrationFixture(t, map[string]map[string]string{"a": {"a.go": "package main\n"}})
	if res := Integrate(f.staging, filepath.Join(t.TempDir(), "int"), "main", []string{"gastown/a"}, passChecks); res.Status != "none" {
		t.Fatalf("a single branch needs no integration: %+v", res)
	}
}
