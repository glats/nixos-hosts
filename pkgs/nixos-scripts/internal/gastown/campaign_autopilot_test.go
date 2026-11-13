package gastown

import (
	"strings"
	"testing"
)

func autopilotCampaign(t *testing.T) (*Swarm, *Campaign) {
	t.Helper()
	s, c, _ := campaignWithItems(t)
	return s, c
}

func TestAutopilotSelectsOnlyItemsWithoutDecisionsAndResolvedDependencies(t *testing.T) {
	s, c := autopilotCampaign(t)
	c.Autopilot = true
	s.CampaignStep(c, t0)
	if c.item("spec").Status != "running" && c.item("spec").Status != "selected" {
		t.Fatalf("spec has no dependencies and needs no decision: %s", c.item("spec").Status)
	}
	if got := c.item("build").Status; got != "selected" {
		t.Fatalf("build depends on a selected item and needs no decision, got %s", got)
	}
	if got := c.item("iso").Status; got != "proposed" {
		t.Fatalf("an item that needs the user's decision must never be auto-selected, got %s", got)
	}
	if !strings.Contains(strings.Join(titles(t, s), "|"), "Autopilot selected") {
		t.Fatalf("the user must see what autopilot picked: %v", titles(t, s))
	}
}

func TestAutopilotRespectsTheCapOnActiveItems(t *testing.T) {
	s, c := autopilotCampaign(t)
	c.Items = nil
	for _, id := range []string{"a1", "a2", "a3", "a4", "a5"} {
		c.Items = append(c.Items, CampaignItem{ID: id, Title: id, Status: "proposed"})
	}
	c.Autopilot = true
	s.CampaignStep(c, t0)
	active := 0
	for _, it := range c.Items {
		if it.Status == "selected" || it.Status == "running" {
			active++
		}
	}
	if active != autopilotMaxActive {
		t.Fatalf("autopilot keeps at most %d items active, got %d", autopilotMaxActive, active)
	}
}

func TestAutopilotIsOffByDefaultAndTogglesThroughTheQueue(t *testing.T) {
	s, c := autopilotCampaign(t)
	s.CampaignStep(c, t0)
	if c.item("spec").Status != "proposed" {
		t.Fatalf("nothing is selected without autopilot or the user: %s", c.item("spec").Status)
	}
	if err := s.QueueCampaignAutopilot(true); err != nil {
		t.Fatal(err)
	}
	s.CampaignStep(c, t0)
	if !c.Autopilot || c.item("spec").Status == "proposed" {
		t.Fatalf("autopilot on must start picking: on=%v spec=%s", c.Autopilot, c.item("spec").Status)
	}
	if err := s.QueueCampaignAutopilot(false); err != nil {
		t.Fatal(err)
	}
	s.CampaignStep(c, t0)
	if c.Autopilot {
		t.Fatal("autopilot off must stick")
	}
	saved := *c
	if err := SaveCampaign(s.campaignPath(), &saved); err != nil {
		t.Fatal(err)
	}
	again, err := LoadCampaign(s.campaignPath())
	if err != nil || again.Autopilot {
		t.Fatalf("the flag must persist: %+v err=%v", again, err)
	}
}

func TestSelectingByIDsWorksWhileTheCampaignIsExecuting(t *testing.T) {
	s, c := autopilotCampaign(t)
	s.handleReply(c, "build", t0)
	if c.item("build").Status != "selected" {
		t.Fatalf("a literal id list must select even in the executing phase: %s", c.item("build").Status)
	}
	c.item("spec").Status = "blocked"
	s.handleReply(c, "use rpm 4.19", t0)
	if c.item("spec").Status != "selected" {
		t.Fatalf("free text still unblocks and steers: %s", c.item("spec").Status)
	}
	s.handleReply(c, "all", t0)
	if c.item("iso").Status != "proposed" {
		t.Fatalf("the word all outside the selection phase must not select everything: %s", c.item("iso").Status)
	}
}

func TestAutopilotCommandQueuesTheToggle(t *testing.T) {
	s, _ := newCampaignSwarm(t)
	if err := s.save(); err != nil {
		t.Fatal(err)
	}
	var out, errOut strings.Builder
	for _, mode := range []string{"on", "off"} {
		if code := CampaignMain(s.R.Config, []string{"autopilot", "toy", mode}, &out, &errOut); code != 0 {
			t.Fatalf("%s: code=%d err=%s", mode, code, errOut.String())
		}
	}
	got := s.drainReplies()
	if len(got) != 2 || got[0].Kind != "autopilot" || got[0].Text != "on" || got[1].Text != "off" {
		t.Fatalf("queued = %+v", got)
	}
	if code := CampaignMain(s.R.Config, []string{"autopilot", "toy", "maybe"}, &out, &errOut); code == 0 {
		t.Fatal("only on and off are accepted")
	}
}
