package gastown

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

const goodPlan = "Here is the plan.\n```json\n" + `{"items":[
 {"id":"spec","title":"Write the spec","why":"base","depends_on":[],"needs_decision":false},
 {"id":"build","title":"Build the thing","why":"needs spec","depends_on":["spec"],"needs_decision":false},
 {"id":"iso","title":"Pick the ISO layout","why":"user choice","depends_on":[],"needs_decision":true}]}` + "\n```\n"

var t0 = time.Date(2026, 11, 10, 12, 0, 0, 0, time.UTC)

func newCampaignSwarm(t *testing.T) (*Swarm, *swarmFake) {
	t.Helper()
	f := &swarmFake{esc: `[]`, mail: `[]`, polecats: `[]`}
	exec := func(c Command) (Result, error) {
		key := filepath.Base(c.Name) + " " + strings.Join(c.Args, " ")
		if strings.HasPrefix(key, "gt scheduler status") {
			f.calls = append(f.calls, key)
			return Result{Stdout: []byte(`{"queued_total":0,"active_polecats":0}`)}, nil
		}
		return f.exec(c)
	}
	s := newSwarm(t, f, "codex:m:low")
	s.R.Exec = fnExec(exec)
	for _, bare := range []string{s.Staging(), s.RigRepo()} {
		if err := os.MkdirAll(bare, 0o700); err != nil {
			t.Fatal(err)
		}
		if _, err := runGit(bare, "init", "-q", "--bare", "-b", "main"); err != nil {
			t.Fatal(err)
		}
	}
	return s, f
}

func mailSent(f *swarmFake) []string {
	var out []string
	for _, c := range f.calls {
		if strings.HasPrefix(c, "gt mail send") {
			out = append(out, c)
		}
	}
	return out
}

func titles(t *testing.T, s *Swarm) []string {
	t.Helper()
	var out []string
	for _, n := range notifications(t, s) {
		out = append(out, n["title"])
	}
	return out
}

func TestParsePlanAcceptsAValidPlanAndRejectsBrokenOnes(t *testing.T) {
	items, err := ParsePlan(goodPlan)
	if err != nil || len(items) != 3 || items[1].DependsOn[0] != "spec" || items[0].Status != "proposed" || !items[2].NeedsDecision {
		t.Fatalf("items=%+v err=%v", items, err)
	}
	wrap := func(items string) string { return "```json\n{\"items\":[" + items + "]}\n```" }
	for name, body := range map[string]string{
		"no block":      "just words",
		"no items":      "```json\n{\"select\":[\"a\"]}\n```",
		"empty":         wrap(""),
		"duplicate":     wrap(`{"id":"a","title":"x"},{"id":"a","title":"y"}`),
		"unknown dep":   wrap(`{"id":"a","title":"x","depends_on":["zz"]}`),
		"self dep":      wrap(`{"id":"a","title":"x","depends_on":["a"]}`),
		"cycle":         wrap(`{"id":"a","title":"x","depends_on":["b"]},{"id":"b","title":"y","depends_on":["a"]}`),
		"bad id":        wrap(`{"id":"Bad Id","title":"x"}`),
		"missing title": wrap(`{"id":"a","title":" "}`),
	} {
		if _, err := ParsePlan(body); err == nil {
			t.Errorf("%s must be rejected", name)
		}
	}
}

func TestSelectionAppliesOnlyKnownProposedIDs(t *testing.T) {
	items, _ := ParsePlan(goodPlan)
	c := &Campaign{Items: items}
	ids, ok := ParseSelection("```json\n{\"select\":[\"spec\",\"ghost\",\"spec\"]}\n```", c)
	if !ok || len(ids) != 1 || ids[0] != "spec" {
		t.Fatalf("ids=%v ok=%v", ids, ok)
	}
	c.item("spec").Status = "running"
	if ids, _ := ParseSelection("```json\n{\"select\":[\"spec\"]}\n```", c); len(ids) != 0 {
		t.Fatalf("a running item cannot be selected again: %v", ids)
	}
	if ids, ok := LiteralSelection("build, iso", c); !ok || len(ids) != 2 {
		t.Fatalf("literal ids: %v %v", ids, ok)
	}
	if _, ok := LiteralSelection("do the first and the third", c); ok {
		t.Fatal("free text goes to the Mayor, not the literal path")
	}
	if ids, ok := LiteralSelection("all", c); !ok || len(ids) != 2 {
		t.Fatalf("all proposed: %v %v", ids, ok)
	}
}

func TestNextRunnableFollowsDependencies(t *testing.T) {
	items, _ := ParsePlan(goodPlan)
	c := &Campaign{Items: items}
	c.item("build").Status, c.item("spec").Status = "selected", "selected"
	if got := NextRunnable(c); got == nil || got.ID != "spec" {
		t.Fatalf("spec first, got %+v", got)
	}
	c.item("spec").Status = "running"
	if got := NextRunnable(c); got != nil {
		t.Fatalf("build must wait for spec, got %+v", got)
	}
	c.item("spec").Status = "done"
	if got := NextRunnable(c); got == nil || got.ID != "build" {
		t.Fatalf("build after spec, got %+v", got)
	}
}

func TestCampaignSurvivesARestart(t *testing.T) {
	s, _ := newCampaignSwarm(t)
	c, resumed, err := s.CampaignStart("quiero shipear distros", t0)
	if err != nil || resumed || c.Phase != phasePlanning {
		t.Fatalf("c=%+v resumed=%v err=%v", c, resumed, err)
	}
	c.Items, _ = ParsePlan(goodPlan)
	c.Phase = phaseSelecting
	c.Decisions = append(c.Decisions, CampaignDecision{At: t0, Question: "q", Answer: "a"})
	if err := SaveCampaign(s.campaignPath(), c); err != nil {
		t.Fatal(err)
	}
	again, resumed, err := s.CampaignStart("a different intent", t0.Add(time.Hour))
	if err != nil || !resumed || again.Intent != "quiero shipear distros" || len(again.Items) != 3 || len(again.Decisions) != 1 || again.Phase != phaseSelecting {
		t.Fatalf("resume lost state: %+v resumed=%v err=%v", again, resumed, err)
	}
	if _, _, err := (&Swarm{R: s.R, Cfg: SwarmConfig{Project: "empty"}}).CampaignStart(" ", t0); err == nil {
		t.Fatal("a new campaign needs an intent")
	}
}

func TestRenderCampaignListsItemsDecisionsAndLearnings(t *testing.T) {
	items, _ := ParsePlan(goodPlan)
	items[0].Status, items[0].Summary, items[0].Branches = "done", "verified 1 branch(es)", []string{"gastown/x-1"}
	c := &Campaign{Intent: "ship distros", Phase: phaseExecuting, Items: items,
		Decisions: []CampaignDecision{{At: t0, Question: "which items", Answer: "spec"}}, Learnings: []CampaignLearning{{At: t0, Item: "spec", Text: "needs rpm"}}}
	md := RenderCampaign(c)
	for _, want := range []string{"Intent: ship distros", "- [x] **spec** (done)", "depends on: spec", "gastown/x-1", "which items -> spec", "spec: needs rpm"} {
		if !strings.Contains(md, want) {
			t.Errorf("missing %q in\n%s", want, md)
		}
	}
}

func TestPublishCampaignKeepsHistoryAndSkipsNoChange(t *testing.T) {
	s, _ := newCampaignSwarm(t)
	work := filepath.Join(s.Dir(), "pub")
	for _, md := range []string{"one\n", "one\n", "two\n"} {
		if err := PublishCampaign(s.Staging(), work, md); err != nil {
			t.Fatal(err)
		}
	}
	count, err := runGit("", "-C", s.Staging(), "rev-list", "--count", "gastown/campaign")
	if err != nil || strings.TrimSpace(count) != "2" {
		t.Fatalf("two real changes make two commits, got %q err=%v", count, err)
	}
	if body, _ := runGit("", "-C", s.Staging(), "show", "gastown/campaign:CAMPAIGN.md"); body != "two\n" {
		t.Fatalf("published body = %q", body)
	}
}

func TestPlanningAsksTheMayorOnceThenAcceptsTheValidPlan(t *testing.T) {
	s, f := newCampaignSwarm(t)
	c, _, _ := s.CampaignStart("quiero shipear distros", t0)
	s.CampaignStep(c, t0)
	s.CampaignStep(c, t0.Add(time.Minute))
	if len(mailSent(f)) != 1 || !strings.Contains(strings.Join(mailSent(f), " "), "quiero shipear distros") {
		t.Fatalf("the Mayor is asked exactly once for a plan: %v", mailSent(f))
	}
	if !s.campaignMail(c, mailItem{Body: goodPlan}, t0) || c.Phase != phaseSelecting || len(c.Items) != 3 {
		t.Fatalf("plan not accepted: %+v", c)
	}
	s.CampaignStep(c, t0.Add(2*time.Minute))
	if got := titles(t, s); len(got) == 0 || got[0] != "Campaign plan ready" {
		t.Fatalf("notifications = %v", got)
	}
	saved, err := LoadCampaign(s.campaignPath())
	if err != nil || saved.Phase != phaseSelecting {
		t.Fatalf("saved campaign = %+v err=%v", saved, err)
	}
	if body, _ := runGit("", "-C", s.Staging(), "show", "gastown/campaign:CAMPAIGN.md"); !strings.Contains(body, "Write the spec") {
		t.Fatalf("CAMPAIGN.md not published: %q", body)
	}
}

func TestInvalidPlansAreRetriedOnceThenEscalatedToTheUser(t *testing.T) {
	s, f := newCampaignSwarm(t)
	c, _, _ := s.CampaignStart("x", t0)
	s.CampaignStep(c, t0)
	bad := "```json\n{\"items\":[{\"id\":\"a\",\"title\":\"x\",\"depends_on\":[\"zz\"]}]}\n```"
	s.campaignMail(c, mailItem{Body: bad}, t0)
	if len(mailSent(f)) != 2 || !strings.Contains(strings.Join(mailSent(f), " "), "rejected") {
		t.Fatalf("the Mayor gets one more try: %v", mailSent(f))
	}
	s.campaignMail(c, mailItem{Body: bad}, t0)
	if len(mailSent(f)) != 2 || titles(t, s)[len(titles(t, s))-1] != "Campaign plan invalid twice" {
		t.Fatalf("second failure goes to the user: mail=%v titles=%v", mailSent(f), titles(t, s))
	}
	if c.Phase != phasePlanning {
		t.Fatalf("phase = %s", c.Phase)
	}
}

func TestReplySelectsItemsBlocksDecisionsAndNeverRunsUnselectedOnes(t *testing.T) {
	s, f := newCampaignSwarm(t)
	c, _, _ := s.CampaignStart("x", t0)
	c.Items, _ = ParsePlan(goodPlan)
	c.Phase = phaseSelecting
	if err := s.QueueCampaignReply("spec iso"); err != nil {
		t.Fatal(err)
	}
	s.CampaignStep(c, t0)
	if c.Phase != phaseExecuting || c.item("spec").Status != "running" || c.item("iso").Status != "blocked" || c.item("build").Status != "proposed" {
		t.Fatalf("items = %+v", c.Items)
	}
	if len(c.Decisions) != 1 || c.Decisions[0].Answer != "spec iso" {
		t.Fatalf("decision not persisted: %+v", c.Decisions)
	}
	goal := strings.Join(mailSent(f), " ")
	if !strings.Contains(goal, "Dispatch beads for this item only") || !strings.Contains(goal, "do not create beads for them") {
		t.Fatalf("the goal must forbid dispatching other items: %s", goal)
	}
	if !strings.Contains(goal, "Goal: Campaign intent: x") || !strings.Contains(goal, "[spec] Write the spec") || strings.Contains(goal, "[build]") {
		t.Fatalf("only the selected item becomes a goal: %s", goal)
	}
	got := strings.Join(titles(t, s), "|")
	for _, want := range []string{"Needs you: Pick the ISO layout", "Item started: Write the spec"} {
		if !strings.Contains(got, want) {
			t.Errorf("missing notification %q in %s", want, got)
		}
	}
}

func TestFreeTextSelectionGoesToTheMayorAndItsJSONAnswerIsApplied(t *testing.T) {
	s, f := newCampaignSwarm(t)
	c, _, _ := s.CampaignStart("x", t0)
	c.Items, _ = ParsePlan(goodPlan)
	c.Phase = phaseSelecting
	s.handleReply(c, "the first and the second please", t0)
	if !c.AskedSelect || !strings.Contains(strings.Join(mailSent(f), " "), "CAMPAIGN SELECTION") {
		t.Fatalf("the Mayor must interpret free text: asked=%v mail=%v", c.AskedSelect, mailSent(f))
	}
	if !s.campaignMail(c, mailItem{Body: "```json\n{\"select\":[\"spec\",\"build\",\"ghost\"]}\n```"}, t0) {
		t.Fatal("selection mail must be consumed")
	}
	if c.item("spec").Status != "selected" || c.item("build").Status != "selected" || c.item("iso").Status != "proposed" || c.Phase != phaseExecuting {
		t.Fatalf("items = %+v", c.Items)
	}
}

func completeGoal(t *testing.T, s *Swarm, goalAt time.Time) {
	t.Helper()
	st := s.loadState()
	st.GoalAt, st.Complete, st.LastActivity = goalAt, true, goalAt
	st.Gated["x-1@abc"] = GateResult{Status: "pass", Published: "gastown/x-1", Files: []string{"b.go", "a.go"}, At: goalAt.Add(time.Minute)}
	s.saveState(st)
}

func TestAnItemIsDoneOnlyWithAVerifiedBranchAndFeedsTheNextOne(t *testing.T) {
	s, f := newCampaignSwarm(t)
	c, _, _ := s.CampaignStart("ship", t0)
	c.Items, _ = ParsePlan(goodPlan)
	c.Phase = phaseExecuting
	c.item("spec").Status, c.item("build").Status = "selected", "selected"
	s.CampaignStep(c, t0)
	if c.item("spec").Status != "running" {
		t.Fatalf("spec should start: %+v", c.Items)
	}
	st := s.loadState()
	st.Complete = true
	s.saveState(st)
	s.CampaignStep(c, t0.Add(time.Minute))
	if c.item("spec").Status != "running" {
		t.Fatal("the Mayor claiming completion without a verified branch must not finish the item")
	}
	completeGoal(t, s, st.GoalAt)
	s.CampaignStep(c, t0.Add(2*time.Minute))
	spec := c.item("spec")
	if spec.Status != "done" || len(spec.Branches) != 1 || !strings.Contains(spec.Summary, "a.go, b.go") || len(c.Learnings) != 1 {
		t.Fatalf("spec = %+v learnings=%+v", spec, c.Learnings)
	}
	s.CampaignStep(c, t0.Add(3*time.Minute))
	if c.item("build").Status != "running" {
		t.Fatalf("build starts after spec: %+v", c.Items)
	}
	last := mailSent(f)[len(mailSent(f))-1]
	if !strings.Contains(last, "Already done in this campaign") || !strings.Contains(last, "[build]") {
		t.Fatalf("the next goal must carry what was learned: %s", last)
	}
}

func TestAnItemWithNothingVerifiedBecomesBlockedAndAReplyUnblocksIt(t *testing.T) {
	s, f := newCampaignSwarm(t)
	c, _, _ := s.CampaignStart("ship", t0)
	c.Items, _ = ParsePlan(goodPlan)
	c.Phase = phaseExecuting
	c.item("spec").Status = "selected"
	s.CampaignStep(c, t0)
	s.CampaignStep(c, t0.Add(campaignBlockedAfter+time.Minute))
	if c.item("spec").Status != "blocked" || titles(t, s)[len(titles(t, s))-1] != "Item blocked: Write the spec" {
		t.Fatalf("spec = %+v titles=%v", c.item("spec"), titles(t, s))
	}
	before := len(mailSent(f))
	s.handleReply(c, "use rpm 4.19", t0.Add(time.Hour))
	if c.item("spec").Status != "selected" || c.Decisions[len(c.Decisions)-1].Question != "unblock spec" || len(mailSent(f)) != before {
		t.Fatalf("a reply unblocks the item without bothering the Mayor: %+v mail=%d", c.item("spec"), len(mailSent(f)))
	}
	s.CampaignStep(c, t0.Add(time.Hour+time.Minute))
	if c.item("spec").Status != "running" || !strings.Contains(mailSent(f)[len(mailSent(f))-1], "use rpm 4.19") {
		t.Fatalf("the restarted goal must carry the decision: %+v", c.item("spec"))
	}
}

func TestCampaignFinishesWhenNothingIsLeftAndOffersRemainingProposals(t *testing.T) {
	s, _ := newCampaignSwarm(t)
	c, _, _ := s.CampaignStart("ship", t0)
	c.Items, _ = ParsePlan(goodPlan)
	c.Phase = phaseExecuting
	c.item("spec").Status, c.item("build").Status, c.item("iso").Status = "done", "done", "proposed"
	s.CampaignStep(c, t0)
	if c.Phase != phaseSelecting || !strings.Contains(strings.Join(titles(t, s), "|"), "Selected items are done") {
		t.Fatalf("phase=%s titles=%v", c.Phase, titles(t, s))
	}
	c.Phase, c.item("iso").Status = phaseExecuting, "dropped"
	s.CampaignStep(c, t0)
	if c.Phase != phaseDone || titles(t, s)[len(titles(t, s))-1] != "Campaign complete" {
		t.Fatalf("phase=%s titles=%v", c.Phase, titles(t, s))
	}
}

func TestCampaignDigestRunsEveryFourHours(t *testing.T) {
	s, _ := newCampaignSwarm(t)
	c, _, _ := s.CampaignStart("ship", t0)
	c.Phase = phaseSelecting
	s.CampaignStep(c, t0.Add(time.Hour))
	if strings.Contains(strings.Join(titles(t, s), "|"), "Campaign digest") {
		t.Fatal("no digest before four hours")
	}
	s.CampaignStep(c, t0.Add(4*time.Hour+time.Minute))
	if !strings.Contains(strings.Join(titles(t, s), "|"), "Campaign digest") {
		t.Fatalf("digest missing: %v", titles(t, s))
	}
}

func TestQueuedRepliesAreConsumedInOrderOnce(t *testing.T) {
	s, _ := newCampaignSwarm(t)
	for _, r := range []string{"first", "second"} {
		if err := s.QueueCampaignReply(r); err != nil {
			t.Fatal(err)
		}
		time.Sleep(2 * time.Millisecond)
	}
	if got := s.drainReplies(); len(got) != 2 || got[0] != "first" || got[1] != "second" {
		t.Fatalf("replies = %v", got)
	}
	if got := s.drainReplies(); len(got) != 0 {
		t.Fatalf("replies must be consumed once: %v", got)
	}
	if err := s.QueueCampaignReply("  "); err == nil {
		t.Fatal("empty replies are refused")
	}
}

func TestMayorMailOutsidePlanningFlowsStillReachTheUser(t *testing.T) {
	s, _ := newCampaignSwarm(t)
	c, _, _ := s.CampaignStart("ship", t0)
	c.Phase = phaseExecuting
	if s.campaignMail(c, mailItem{Body: "```json\n{\"items\":[]}\n```"}, t0) || s.campaignMail(c, mailItem{Body: "progress update"}, t0) {
		t.Fatal("ordinary Mayor mail must not be swallowed while items execute")
	}
}

func TestCampaignCommandsReplyStatusAndStop(t *testing.T) {
	s, _ := newCampaignSwarm(t)
	if err := s.save(); err != nil {
		t.Fatal(err)
	}
	camp, _, _ := s.CampaignStart("ship distros", t0)
	camp.Items, _ = ParsePlan(goodPlan)
	camp.Phase = phaseSelecting
	if err := SaveCampaign(s.campaignPath(), camp); err != nil {
		t.Fatal(err)
	}
	var out, errOut strings.Builder
	if code := CampaignMain(s.R.Config, []string{"status", "toy"}, &out, &errOut); code != 0 ||
		!strings.Contains(out.String(), "phase: awaiting_selection") || !strings.Contains(out.String(), "build") {
		t.Fatalf("status code=%d out=%q err=%q", code, out.String(), errOut.String())
	}
	if code := CampaignMain(s.R.Config, []string{"reply", "toy", "spec", "iso"}, &out, &errOut); code != 0 {
		t.Fatalf("reply code=%d err=%q", code, errOut.String())
	}
	if got := s.drainReplies(); len(got) != 1 || got[0] != "spec iso" {
		t.Fatalf("queued replies = %v", got)
	}
	if code := CampaignMain(s.R.Config, []string{"stop", "toy"}, &out, &errOut); code != 0 {
		t.Fatalf("stop code=%d", code)
	}
	if _, err := os.Stat(s.StopFile()); err != nil {
		t.Fatal("stop must create the STOP file")
	}
	if code := CampaignMain(s.R.Config, []string{"status", "nope"}, &out, &errOut); code == 0 {
		t.Fatal("an unknown project must fail")
	}
	if code := CampaignMain(s.R.Config, nil, &out, &errOut); code != 2 {
		t.Fatalf("no arguments prints usage, got %d", code)
	}
}
