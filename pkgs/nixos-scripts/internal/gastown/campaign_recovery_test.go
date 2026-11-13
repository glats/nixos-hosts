package gastown

import (
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
)

func verifiedItem(t *testing.T, branches ...string) (*Swarm, *Campaign) {
	t.Helper()
	s, c, _ := campaignWithItems(t)
	st := s.loadState()
	for i, b := range branches {
		st.Gated[strings.TrimPrefix(b, "gastown/")+"@abc"+string(rune('a'+i))] = GateResult{Status: "pass", Published: b, Files: []string{"f"}, At: t0}
	}
	s.saveState(st)
	return s, c
}

func TestABaseAdvanceFailureLeavesItsLogsBehind(t *testing.T) {
	s := chainRepos(t)
	s.R.Exec = fnExec(func(c Command) (Result, error) {
		return Result{Exit: 1, Stdout: []byte("not ok 1 something broke\n")}, nil
	})
	if res := s.AdvanceBase([]string{"gastown/x-1"}); res.Status != "fail" {
		t.Fatalf("result = %+v", res)
	}
	matches, _ := filepath.Glob(filepath.Join(s.Dir(), "gate-logs", "advance-failed-*", "check-1.stdout"))
	if len(matches) != 1 {
		t.Fatalf("the failing run's logs must be kept for diagnosis: %v", matches)
	}
	if data, _ := os.ReadFile(matches[0]); !strings.Contains(string(data), "something broke") {
		t.Fatalf("log = %q", data)
	}
}

func TestATransientAdvanceFailureIsRetriedOnceBeforeBlocking(t *testing.T) {
	s, c := verifiedItem(t, "gastown/x-1")
	var calls int32
	original := s.R.Exec
	s.R.Exec = fnExec(func(cmd Command) (Result, error) {
		if cmd.Name == s.R.Config.Bwrap {
			if atomic.AddInt32(&calls, 1) == 1 {
				return Result{Exit: 1}, nil
			}
			return Result{}, nil
		}
		return original.Run(cmd)
	})
	c.item("spec").Status = "selected"
	s.CampaignStep(c, t0)
	st := s.loadState()
	st.Complete, st.LastActivity = true, t0
	st.Gated["x-1@abc"] = GateResult{Status: "pass", Published: "gastown/x-1", Files: []string{"one.txt"}, At: st.GoalAt.Add(1)}
	s.saveState(st)
	s.CampaignStep(c, t0.Add(1))
	if got := c.item("spec").Status; got != "done" {
		t.Fatalf("one transient failure must not block the item: %s (check runs: %d)", got, atomic.LoadInt32(&calls))
	}
	if atomic.LoadInt32(&calls) < 2 {
		t.Fatal("the advance must have been attempted twice")
	}
}

func TestABlockedItemKeepsItsVerifiedBranchesSoItCanBeRetried(t *testing.T) {
	s, c, _ := campaignWithItems(t)
	c.item("spec").Status = "selected"
	s.CampaignStep(c, t0)
	st := s.loadState()
	st.Complete, st.LastActivity = true, t0
	st.Gated["x-3@abc"] = GateResult{Status: "pass", Published: "gastown/x-3", Files: []string{"base.txt"}, At: st.GoalAt.Add(1)}
	st.Gated["x-4@abc"] = GateResult{Status: "pass", Published: "gastown/x-4", Files: []string{"base.txt"}, At: st.GoalAt.Add(1)}
	s.saveState(st)
	s.CampaignStep(c, t0.Add(1))
	spec := c.item("spec")
	if spec.Status != "blocked" || len(spec.Branches) != 2 {
		t.Fatalf("a blocked item must remember its gate-verified branches: %+v", spec)
	}
}

func TestRetryFinishesABlockedItemMechanicallyWithoutClaimingAUserReview(t *testing.T) {
	s, c := verifiedItem(t, "gastown/x-1")
	spec := c.item("spec")
	spec.Status, spec.Branches = "blocked", []string{"gastown/x-1"}
	before := tipOf(t, s.RigRepo(), "main")
	if err := s.QueueCampaignRetry("spec"); err != nil {
		t.Fatal(err)
	}
	s.CampaignStep(c, t0)
	if spec.Status != "done" || tipOf(t, s.RigRepo(), "main") == before {
		t.Fatalf("spec=%s base moved=%v", spec.Status, tipOf(t, s.RigRepo(), "main") != before)
	}
	if strings.Contains(spec.Summary, "approved by the user") || !strings.Contains(spec.Summary, "retried") {
		t.Fatalf("a retry is a mechanical re-check, not a user review: %q", spec.Summary)
	}
}

func TestRetryRefusesWhatTheGateNeverAcceptedAndItemsThatAreNotBlocked(t *testing.T) {
	s, c := verifiedItem(t, "gastown/x-1")
	c.item("spec").Status, c.item("spec").Branches = "blocked", []string{"gastown/x-2"}
	c.item("build").Status = "running"
	for _, id := range []string{"spec", "build", "ghost"} {
		if err := s.QueueCampaignRetry(id); err != nil {
			t.Fatal(err)
		}
	}
	s.CampaignStep(c, t0)
	if c.item("spec").Status == "done" || c.item("build").Status == "done" {
		t.Fatal("retry must never finish an item whose branches the gate did not accept, or one that is not blocked")
	}
	refusals := 0
	for _, n := range notifications(t, s) {
		if strings.Contains(n["title"], "Cannot retry") {
			refusals++
		}
	}
	if refusals != 3 {
		t.Fatalf("every refusal must be reported, got %d: %v", refusals, titles(t, s))
	}
}

func TestRetryCommandQueuesForTheSupervisor(t *testing.T) {
	s, _ := newCampaignSwarm(t)
	if err := s.save(); err != nil {
		t.Fatal(err)
	}
	var out, errOut strings.Builder
	if code := CampaignMain(s.R.Config, []string{"retry", "toy", "spec"}, &out, &errOut); code != 0 {
		t.Fatalf("code=%d err=%s", code, errOut.String())
	}
	if got := s.drainReplies(); len(got) != 1 || got[0].Kind != "retry" || got[0].Question != "spec" {
		t.Fatalf("queued = %+v", got)
	}
	if code := CampaignMain(s.R.Config, []string{"retry", "toy"}, &out, &errOut); code == 0 {
		t.Fatal("retry needs an item")
	}
}
