package gastown

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func chainRepos(t *testing.T) *Swarm {
	t.Helper()
	s, _ := chainReposWithFake(t)
	return s
}

func chainReposWithFake(t *testing.T) (*Swarm, *swarmFake) {
	t.Helper()
	s, f := newCampaignSwarm(t)
	for _, dir := range []string{s.Staging(), s.RigRepo()} {
		if err := os.RemoveAll(dir); err != nil {
			t.Fatal(err)
		}
	}
	seed := filepath.Join(t.TempDir(), "seed")
	if err := os.MkdirAll(seed, 0o700); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{{"init", "-q", "-b", "main"}} {
		if _, err := runGit(seed, args...); err != nil {
			t.Fatal(err)
		}
	}
	commit := func(branch, file, body string) {
		if _, err := runGit(seed, "checkout", "-q", "-B", branch, "main"); err != nil && branch != "main" {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(seed, file), []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
		if _, err := runGit(seed, "add", "-A"); err != nil {
			t.Fatal(err)
		}
		if _, err := runGit(seed, "commit", "-q", "-m", "add "+file); err != nil {
			t.Fatal(err)
		}
	}
	commit("main", "base.txt", "base\n")
	commit("gastown/x-1", "one.txt", "one\n")
	commit("gastown/x-2", "two.txt", "two\n")
	commit("gastown/x-3", "base.txt", "three\n")
	commit("gastown/x-4", "base.txt", "four\n")
	for _, args := range [][]string{{"clone", "-q", "--bare", seed, s.Staging()}} {
		if _, err := runGit("", args...); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := runGit("", "clone", "-q", "--bare", s.Staging(), s.RigRepo()); err != nil {
		t.Fatal(err)
	}
	if _, err := runGit(s.RigRepo(), "config", "remote.origin.fetch", "+refs/heads/*:refs/remotes/origin/*"); err != nil {
		t.Fatal(err)
	}
	if _, err := runGit(s.RigRepo(), "fetch", "-q", "origin"); err != nil {
		t.Fatal(err)
	}
	return s, f
}

func tipOf(t *testing.T, repo, ref string) string {
	t.Helper()
	out, err := runGit("", "-C", repo, "rev-parse", ref)
	if err != nil {
		t.Fatal(err)
	}
	return strings.TrimSpace(out)
}

func TestAdvanceBaseMergesVerifiedBranchesIntoTheStagingAndRigMain(t *testing.T) {
	s := chainRepos(t)
	before := tipOf(t, s.RigRepo(), "main")
	res := s.AdvanceBase([]string{"gastown/x-1", "gastown/x-2"})
	if res.Status != "pass" {
		t.Fatalf("result = %+v", res)
	}
	for _, repo := range []string{s.Staging(), s.RigRepo()} {
		tip := tipOf(t, repo, "main")
		if tip == before {
			t.Fatalf("%s: main did not advance", repo)
		}
		for _, f := range []string{"base.txt", "one.txt", "two.txt"} {
			if _, err := runGit("", "-C", repo, "cat-file", "-e", "main:"+f); err != nil {
				t.Errorf("%s: main lacks %s", repo, f)
			}
		}
	}
	if tipOf(t, s.RigRepo(), "main") != tipOf(t, s.Staging(), "main") || tipOf(t, s.RigRepo(), "origin/main") != tipOf(t, s.Staging(), "main") {
		t.Fatal("the rig's main and origin/main must equal the staging main: workers branch from them and the gate diffs against them")
	}
	if res2 := s.AdvanceBase([]string{"gastown/x-1"}); res2.Status != "pass" || tipOf(t, s.Staging(), "main") != tipOf(t, s.RigRepo(), "main") {
		t.Fatalf("advancing with an already merged branch must be harmless: %+v", res2)
	}
}

func TestAdvanceBaseRefusesConflictsAndFailingChecksAndLeavesTheBaseUntouched(t *testing.T) {
	s := chainRepos(t)
	before := tipOf(t, s.Staging(), "main")
	res := s.AdvanceBase([]string{"gastown/x-1", "gastown/x-3", "gastown/x-4", "gastown/x-2"})
	if res.Status != "conflict" || res.Conflict != "gastown/x-4" {
		t.Fatalf("a conflicting branch must be named: %+v", res)
	}
	if tipOf(t, s.Staging(), "main") != before || tipOf(t, s.RigRepo(), "main") != before {
		t.Fatal("a conflict must not move any main")
	}
	failing := fnExec(func(c Command) (Result, error) { return Result{Exit: 1}, nil })
	s.R.Exec = failing
	if res := s.AdvanceBase([]string{"gastown/x-1"}); res.Status != "fail" {
		t.Fatalf("failing checks must refuse: %+v", res)
	}
	if tipOf(t, s.Staging(), "main") != before || tipOf(t, s.RigRepo(), "main") != before {
		t.Fatal("failing checks must not move any main")
	}
}

func TestAnItemWhoseBranchesCannotAdvanceTheBaseIsBlockedNotDone(t *testing.T) {
	s := chainRepos(t)
	c, _, _ := s.CampaignStart("ship", t0)
	c.Items = planned()
	c.Phase = phaseExecuting
	c.item("spec").Status = "selected"
	s.CampaignStep(c, t0)
	st := s.loadState()
	st.Complete, st.LastActivity = true, t0
	st.Gated["x-3@abc"] = GateResult{Status: "pass", Published: "gastown/x-3", Files: []string{"base.txt"}, At: st.GoalAt.Add(1)}
	st.Gated["x-4@abc"] = GateResult{Status: "pass", Published: "gastown/x-4", Files: []string{"base.txt"}, At: st.GoalAt.Add(1)}
	s.saveState(st)
	before := tipOf(t, s.Staging(), "main")
	s.CampaignStep(c, t0.Add(1))
	if got := c.item("spec").Status; got != "blocked" {
		t.Fatalf("branches that conflict with each other must block the item, not finish it: %s", got)
	}
	if tipOf(t, s.Staging(), "main") != before {
		t.Fatal("the base must not move")
	}
	told := false
	for _, n := range notifications(t, s) {
		if strings.Contains(n["body"], "cannot be added to the base") {
			told = true
		}
	}
	if !told {
		t.Fatalf("the user must be told: %v", notifications(t, s))
	}
}

func TestAnItemIsDoneAndTheBaseAdvancesWhenItsBranchesMerge(t *testing.T) {
	s := chainRepos(t)
	c, _, _ := s.CampaignStart("ship", t0)
	c.Items = planned()
	c.Phase = phaseExecuting
	c.item("spec").Status = "selected"
	s.CampaignStep(c, t0)
	st := s.loadState()
	st.Complete, st.LastActivity = true, t0
	st.Gated["x-1@abc"] = GateResult{Status: "pass", Published: "gastown/x-1", Files: []string{"one.txt"}, At: st.GoalAt.Add(1)}
	s.saveState(st)
	before := tipOf(t, s.RigRepo(), "main")
	s.CampaignStep(c, t0.Add(1))
	if c.item("spec").Status != "done" || tipOf(t, s.RigRepo(), "main") == before {
		t.Fatalf("spec=%s base moved=%v", c.item("spec").Status, tipOf(t, s.RigRepo(), "main") != before)
	}
	if _, err := runGit("", "-C", s.RigRepo(), "cat-file", "-e", "main:one.txt"); err != nil {
		t.Fatal("the next item must start from a base that contains this item's work")
	}
}

func TestAdvanceBaseKeepsWorktreesOnMainInSyncSoNobodySeesPhantomChanges(t *testing.T) {
	s := chainRepos(t)
	wt := filepath.Join(t.TempDir(), "refinery")
	if _, err := runGit("", "-C", s.RigRepo(), "worktree", "add", "-q", wt, "main"); err != nil {
		t.Fatal(err)
	}
	if res := s.AdvanceBase([]string{"gastown/x-1"}); res.Status != "pass" {
		t.Fatalf("result = %+v", res)
	}
	if out, _ := runGit(wt, "status", "--porcelain"); strings.TrimSpace(out) != "" {
		t.Fatalf("a worktree on main must follow the new base, got phantom changes: %s", out)
	}
	if _, err := os.Stat(filepath.Join(wt, "one.txt")); err != nil {
		t.Fatal("the worktree must contain the accepted work")
	}
}
