package gastown

import (
	"strings"
	"testing"
)

const extension = "More items.\n```json\n" + `{"items":[
 {"id":"go-builder","title":"Research a Go builder","why":"scripts are growing","depends_on":["spec"],"needs_decision":false},
 {"id":"runner-model","title":"Decide where the builder runs","why":"transportable","depends_on":["go-builder"],"needs_decision":true}]}` + "\n```\n"

func campaignWithItems(t *testing.T) (*Swarm, *Campaign, *swarmFake) {
	t.Helper()
	s, f := chainReposWithFake(t)
	c, _, _ := s.CampaignStart("ship", t0)
	c.Items = planned()
	c.Phase = phaseExecuting
	return s, c, f
}

func TestParseExtensionAcceptsNewItemsThatDependOnExistingOnes(t *testing.T) {
	_, c, _ := campaignWithItems(t)
	items, err := ParseExtension(extension, c)
	if err != nil || len(items) != 2 || items[0].Status != "proposed" || items[1].DependsOn[0] != "go-builder" {
		t.Fatalf("items=%+v err=%v", items, err)
	}
}

func TestParseExtensionRejectsClashesUnknownDependenciesAndCycles(t *testing.T) {
	_, c, _ := campaignWithItems(t)
	wrap := func(items string) string { return "```json\n{\"items\":[" + items + "]}\n```" }
	for name, body := range map[string]string{
		"existing id":  wrap(`{"id":"spec","title":"again"}`),
		"unknown dep":  wrap(`{"id":"x","title":"x","depends_on":["ghost"]}`),
		"cycle":        wrap(`{"id":"a","title":"a","depends_on":["b"]},{"id":"b","title":"b","depends_on":["a"]}`),
		"empty":        wrap(""),
		"bad id":       wrap(`{"id":"Bad Id","title":"x"}`),
		"missing text": "no block here",
	} {
		if _, err := ParseExtension(body, c); err == nil {
			t.Errorf("%s must be rejected", name)
		}
	}
}

func TestExtendAsksTheMayorOnceAndAddsTheProposedItemsWithoutRunningThem(t *testing.T) {
	s, c, f := campaignWithItems(t)
	if err := s.QueueCampaignExtend("Future builder in Go, transportable, runs on any runner."); err != nil {
		t.Fatal(err)
	}
	s.CampaignStep(c, t0)
	prompt := strings.Join(mailSent(f), " ")
	for _, want := range []string{"Future builder in Go", "Do not start any work", "ONLY additional items", `"items"`} {
		if !strings.Contains(prompt, want) {
			t.Errorf("extend request must contain %q", want)
		}
	}
	if !c.ExtendAsked || len(c.Items) != 3 {
		t.Fatalf("asked=%v items=%d", c.ExtendAsked, len(c.Items))
	}
	if !s.campaignMail(c, mailItem{Body: extension}, t0) || len(c.Items) != 5 || c.ExtendAsked {
		t.Fatalf("extension not applied: asked=%v items=%d", c.ExtendAsked, len(c.Items))
	}
	if c.item("go-builder").Status != "proposed" || c.item("runner-model").Status != "proposed" {
		t.Fatal("new items must wait for the user's selection")
	}
	if len(c.Decisions) == 0 || !strings.Contains(c.Decisions[len(c.Decisions)-1].Answer, "Future builder in Go") {
		t.Fatalf("the direction must be remembered: %+v", c.Decisions)
	}
	if !strings.Contains(strings.Join(titles(t, s), "|"), "Plan extended") {
		t.Fatalf("the user must be told: %v", titles(t, s))
	}
}

func TestOrdinaryMailAndInvalidExtensionsAreHandledSafely(t *testing.T) {
	s, c, _ := campaignWithItems(t)
	if s.campaignMail(c, mailItem{Body: extension}, t0) {
		t.Fatal("an extension nobody asked for must not change the plan")
	}
	c.ExtendAsked = true
	if s.campaignMail(c, mailItem{Body: "just a progress update"}, t0) || !c.ExtendAsked {
		t.Fatal("ordinary mail must pass through and keep waiting")
	}
	bad := "```json\n{\"items\":[{\"id\":\"spec\",\"title\":\"clash\"}]}\n```"
	if !s.campaignMail(c, mailItem{Body: bad}, t0) || c.ExtendAsked || len(c.Items) != 3 {
		t.Fatalf("an invalid extension is consumed, reported and changes nothing: asked=%v items=%d", c.ExtendAsked, len(c.Items))
	}
}

func approvalSwarm(t *testing.T) (*Swarm, *Campaign) {
	t.Helper()
	s, c, _ := campaignWithItems(t)
	c.item("spec").Status = "blocked"
	st := s.loadState()
	st.Gated["x-1@abc"] = GateResult{Status: "pass", Published: "gastown/x-1", Files: []string{"one.txt"}, At: t0}
	s.saveState(st)
	return s, c
}

func TestApproveMarksABlockedItemDoneOnlyWithGateVerifiedBranchesAndAdvancesTheBase(t *testing.T) {
	s, c := approvalSwarm(t)
	before := tipOf(t, s.RigRepo(), "main")
	if err := s.QueueCampaignApprove("spec", []string{"gastown/x-1"}); err != nil {
		t.Fatal(err)
	}
	s.CampaignStep(c, t0)
	spec := c.item("spec")
	if spec.Status != "done" || len(spec.Branches) != 1 || !strings.Contains(spec.Summary, "approved by the user") {
		t.Fatalf("spec = %+v", spec)
	}
	if tipOf(t, s.RigRepo(), "main") == before {
		t.Fatal("the approved work must become part of the base")
	}
	last := c.Decisions[len(c.Decisions)-1]
	if last.Question != "approve spec" || !strings.Contains(last.Answer, "gastown/x-1") {
		t.Fatalf("decision = %+v", last)
	}
}

func TestApproveRefusesBranchesTheGateNeverAccepted(t *testing.T) {
	s, c := approvalSwarm(t)
	for _, branches := range [][]string{{"gastown/x-2"}, {"gastown/x-1", "gastown/x-2"}, {"main"}, nil} {
		if err := s.QueueCampaignApprove("spec", branches); err != nil {
			continue
		}
		s.CampaignStep(c, t0)
		if c.item("spec").Status == "done" {
			t.Fatalf("%v: an item must never be done without gate-verified branches", branches)
		}
	}
	if err := s.QueueCampaignApprove("ghost", []string{"gastown/x-1"}); err == nil {
		s.CampaignStep(c, t0)
	}
	told := false
	for _, n := range notifications(t, s) {
		if strings.Contains(n["title"], "Cannot approve") {
			told = true
		}
	}
	if !told {
		t.Fatalf("the refusal must be reported: %v", titles(t, s))
	}
}

func TestApproveAndExtendCommandsQueueForTheSupervisor(t *testing.T) {
	s, _ := newCampaignSwarm(t)
	if err := s.save(); err != nil {
		t.Fatal(err)
	}
	var out, errOut strings.Builder
	if code := CampaignMain(s.R.Config, []string{"approve", "toy", "spec", "gastown/x-1", "gastown/x-2"}, &out, &errOut); code != 0 {
		t.Fatalf("approve code=%d err=%s", code, errOut.String())
	}
	if code := CampaignMain(s.R.Config, []string{"extend", "toy", "a", "builder", "in", "Go"}, &out, &errOut); code != 0 {
		t.Fatalf("extend code=%d err=%s", code, errOut.String())
	}
	got := s.drainReplies()
	if len(got) != 2 || got[0].Kind != "approve" || got[0].Question != "spec" || got[0].Text != "gastown/x-1 gastown/x-2" || got[1].Kind != "extend" || got[1].Text != "a builder in Go" {
		t.Fatalf("queued = %+v", got)
	}
	if code := CampaignMain(s.R.Config, []string{"approve", "toy", "spec"}, &out, &errOut); code == 0 {
		t.Fatal("approve without branches must fail")
	}
}
