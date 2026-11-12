package gastown

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	campaignBlockedAfter = 30 * time.Minute
	campaignDigestEvery  = 4 * time.Hour
)

func (s *Swarm) repliesDir() string { return filepath.Join(s.Dir(), "campaign-replies") }

type queuedInput struct {
	Kind     string `json:"kind"`
	Question string `json:"question,omitempty"`
	Text     string `json:"text"`
}

func (s *Swarm) queue(in queuedInput) error {
	if strings.TrimSpace(in.Text) == "" {
		return fmt.Errorf("empty text")
	}
	if err := os.MkdirAll(s.repliesDir(), 0o700); err != nil {
		return err
	}
	data, _ := json.Marshal(in)
	name := strconv.FormatInt(time.Now().UnixNano(), 10) + ".json"
	return os.WriteFile(filepath.Join(s.repliesDir(), name), data, 0o600)
}

// QueueCampaignReply stores a selection or steering reply for the running
// supervisor, which consumes it on its next round. It also works while no
// supervisor runs.
func (s *Swarm) QueueCampaignReply(text string) error {
	return s.queue(queuedInput{Kind: "reply", Text: text})
}

// QueueCampaignExtend asks the supervisor to have the Mayor propose more items.
func (s *Swarm) QueueCampaignExtend(direction string) error {
	return s.queue(queuedInput{Kind: "extend", Text: direction})
}

// QueueCampaignApprove records the user's approval of an item whose branches
// the trusted gate accepted. The supervisor re-checks that before acting.
func (s *Swarm) QueueCampaignApprove(item string, branches []string) error {
	if len(branches) == 0 {
		return fmt.Errorf("approve needs the gate-accepted branch(es), for example gastown/ma-dms")
	}
	return s.queue(queuedInput{Kind: "approve", Question: item, Text: strings.Join(branches, " ")})
}

// QueueCampaignAnswer stores the answer to one of the Mayor's questions.
func (s *Swarm) QueueCampaignAnswer(question, text string) error {
	return s.queue(queuedInput{Kind: "answer", Question: question, Text: text})
}

func (s *Swarm) drainReplies() []queuedInput {
	entries, err := os.ReadDir(s.repliesDir())
	if err != nil {
		return nil
	}
	var names []string
	for _, e := range entries {
		names = append(names, e.Name())
	}
	sort.Strings(names)
	var out []queuedInput
	for _, name := range names {
		path := filepath.Join(s.repliesDir(), name)
		var in queuedInput
		if data, err := os.ReadFile(path); err == nil && json.Unmarshal(data, &in) == nil {
			out = append(out, in)
		}
		_ = os.Remove(path)
	}
	return out
}

// CampaignStart creates the campaign, or returns the saved one so a restart
// resumes where it stopped.
func (s *Swarm) CampaignStart(intent string, now time.Time) (*Campaign, bool, error) {
	if c, err := LoadCampaign(s.campaignPath()); err == nil {
		return c, true, nil
	}
	if strings.TrimSpace(intent) == "" {
		return nil, false, fmt.Errorf("empty intent")
	}
	c := &Campaign{Intent: strings.TrimSpace(intent), Phase: phasePlanning, StartedAt: now, LastDigest: now}
	return c, false, SaveCampaign(s.campaignPath(), c)
}

const stationLimits = `STATION LIMITS you must plan around. Workers are confined: no root, no devices, no virtual machines, writable only inside their own worktree, and they cannot reach the user's files or credentials. The trusted gate runs only these offline checks: %s
Anything that needs root, a disk, a VM, network downloads, signing keys or a publishing account is NOT something a worker can run: name it as a resource you need, say what you would do with it, and ask the user what exists.`

func (s *Swarm) planPrompt(c *Campaign, problem string) string {
	state, _ := os.ReadFile(s.campaignPath())
	text := "CAMPAIGN PLANNING. Do not start any work, create no bead and sling nothing yet.\nThe human's intent: " + c.Intent +
		"\n\nWhat this campaign already knows (campaign.json):\n" + string(state) + "\n\n" +
		fmt.Sprintf(stationLimits, strings.Join(s.Cfg.Checks, " ; ")) +
		"\n\nPropose, in this order: (1) the delivery process: how the result is tested, how it is built, how it is shipped; " +
		"(2) the questions you need the user to answer, for example which resources exist (machines, VMs, accounts, domains, existing projects or sites) and which option they prefer, with the options you see; " +
		"(3) the capabilities the intent needs as small items another worker could finish and the checks can verify. " +
		"Mark needs_decision true on any item that cannot proceed without an answer or a decision from the human. " +
		"Reply with gt mail reply to this message, with a short explanation and then exactly one fenced json block:\n" +
		"```json\n{\"process\":{\"test\":\"...\",\"build\":\"...\",\"ship\":\"...\"},\"questions\":[{\"id\":\"short-id\",\"text\":\"...\",\"options\":[\"...\"]}],\"items\":[{\"id\":\"short-lowercase-id\",\"title\":\"...\",\"why\":\"...\",\"depends_on\":[],\"needs_decision\":false}]}\n```\n"
	if problem != "" {
		text += "\nYour previous plan was rejected: " + problem + ". Send a corrected plan.\n"
	}
	return text
}

func (s *Swarm) selectPrompt(c *Campaign, reply string) string {
	var lines []string
	for _, it := range c.Items {
		if it.Status == "proposed" {
			lines = append(lines, "- "+it.ID+": "+it.Title)
		}
	}
	return "CAMPAIGN SELECTION. Do not start any work. The human replied to the plan with: \"" + reply + "\"\nOpen items:\n" + strings.Join(lines, "\n") +
		"\n\nDecide which item ids that reply selects. Answer with gt mail reply and exactly one fenced json block, using only ids listed above:\n```json\n{\"select\":[\"id\"]}\n```\n"
}

func (s *Swarm) itemGoal(c *Campaign, it *CampaignItem) string {
	var b strings.Builder
	fmt.Fprintf(&b, "Campaign intent: %s\n\nYour item now: [%s] %s\nWhy: %s\nComplete only this item.\nDispatch beads for this item only. The other campaign items are started later by the supervisor, in dependency order; do not create beads for them, even if you know the plan, and send the goal complete escalation when this item alone is done.\n", c.Intent, it.ID, it.Title, it.Why)
	fmt.Fprintf(&b, "\nAgreed delivery process: test: %s | build: %s | ship: %s\n", c.Process.Test, c.Process.Build, c.Process.Ship)
	for _, q := range c.Questions {
		if q.Answer != "" {
			b.WriteString("Answer to \"" + q.Text + "\": " + q.Answer + "\n")
		}
	}
	var done []string
	for _, d := range c.Items {
		if d.Status == "done" {
			done = append(done, "- "+d.ID+": "+d.Title+" (result: "+clip(d.Summary, 200)+")")
		}
	}
	if len(done) > 0 {
		b.WriteString("\nAlready done in this campaign:\n" + strings.Join(done, "\n") + "\n")
	}
	if len(c.Decisions) > 0 {
		b.WriteString("\nDecisions the human gave:\n")
		for _, d := range c.Decisions {
			b.WriteString("- " + d.Question + " -> " + d.Answer + "\n")
		}
	}
	if len(c.Learnings) > 0 {
		b.WriteString("\nWhat the campaign has learned:\n")
		for _, l := range c.Learnings {
			b.WriteString("- " + l.Item + ": " + l.Text + "\n")
		}
	}
	return b.String()
}

func (s *Swarm) applySelection(c *Campaign, ids []string, now time.Time) {
	for _, id := range ids {
		it := c.item(id)
		if it == nil || it.Status != "proposed" {
			continue
		}
		it.Status = "selected"
		if it.NeedsDecision {
			it.Status = "blocked"
			s.notify("high", "Needs you: "+it.Title, clip(it.Why, 400)+"\nreply: gastown-run campaign reply "+s.Cfg.Project+" \"...\"")
		}
	}
	c.Phase, c.AskedSelect = phaseExecuting, false
	c.dirty = true
	s.notify("low", "Campaign: "+strconv.Itoa(len(ids))+" item(s) selected", "starting in dependency order")
}

func (s *Swarm) planNotice(c *Campaign) {
	var lines []string
	for i, it := range c.Items {
		line := strconv.Itoa(i+1) + ". " + it.ID + ": " + it.Title
		if len(it.DependsOn) > 0 {
			line += " (after " + strings.Join(it.DependsOn, ", ") + ")"
		}
		if it.NeedsDecision {
			line += " [needs your decision]"
		}
		lines = append(lines, line)
	}
	text := "Process: test: " + c.Process.Test + " | build: " + c.Process.Build + " | ship: " + c.Process.Ship + "\n"
	for _, q := range c.Questions {
		text += "Question " + q.ID + ": " + q.Text
		if len(q.Options) > 0 {
			text += " (" + strings.Join(q.Options, " / ") + ")"
		}
		text += "\n"
	}
	if len(c.Questions) > 0 {
		text += "answer with: gastown-run campaign answer " + s.Cfg.Project + " --question <id> \"...\"\n"
	}
	s.notify("medium", "Campaign plan ready", text+strings.Join(lines, "\n")+"\nchoose with: gastown-run campaign reply "+s.Cfg.Project+" \"a c\" (item ids, or all)")
}

// campaignMail consumes Mayor mail that carries the plan or the selection, and
// reports whether it did.
func (s *Swarm) campaignMail(c *Campaign, m mailItem, now time.Time) bool {
	if s.campaignExtensionMail(c, m) {
		return true
	}
	switch c.Phase {
	case phasePlanning:
		if c.PlanAsks == 0 || len(fencedBlocks(m.Body)) == 0 {
			return false
		}
		plan, err := ParsePlan(m.Body)
		if err != nil {
			c.PlanAsks++
			c.dirty = true
			if c.PlanAsks <= 2 {
				_ = s.mail("Campaign plan rejected", s.planPrompt(c, err.Error()))
			} else {
				s.notify("high", "Campaign plan invalid twice", err.Error()+"\nThe Mayor could not produce a valid plan; reply with gastown-run campaign reply "+s.Cfg.Project+" \"<guidance>\" to ask again.")
			}
			return true
		}
		c.Process, c.Questions, c.Items, c.Phase = plan.Process, plan.Questions, plan.Items, phaseSelecting
		c.dirty = true
		s.planNotice(c)
		return true
	case phaseSelecting:
		if !c.AskedSelect {
			return false
		}
		ids, ok := ParseSelection(m.Body, c)
		if !ok {
			return false
		}
		s.applySelection(c, ids, now)
		return true
	}
	return false
}

func (s *Swarm) handleInput(c *Campaign, in queuedInput, now time.Time) {
	switch in.Kind {
	case "answer":
		s.handleAnswer(c, in.Question, in.Text, now)
		return
	case "extend":
		s.handleExtend(c, in.Text, now)
		return
	case "approve":
		s.handleApprove(c, in.Question, strings.Fields(in.Text), now)
		return
	}
	s.handleReply(c, in.Text, now)
}

// handleAnswer records the user's answer to a question. Without a question id
// it answers the only open question; otherwise it is kept as a general note.
func (s *Swarm) handleAnswer(c *Campaign, id, text string, now time.Time) {
	var target *CampaignQuestion
	var open []*CampaignQuestion
	for i := range c.Questions {
		q := &c.Questions[i]
		if id != "" && q.ID == id {
			target = q
		}
		if q.Answer == "" {
			open = append(open, q)
		}
	}
	if target == nil && id == "" && len(open) == 1 {
		target = open[0]
	}
	question := "note"
	if target != nil {
		target.Answer, target.AnsweredAt = text, now
		question = target.Text
	} else {
		s.notify("medium", "Answer kept as a note", "no single open question matched ("+firstNonEmpty(id, "no id")+"); it is part of every later goal")
	}
	c.Decisions = append(c.Decisions, CampaignDecision{At: now, Question: question, Answer: text})
	c.dirty = true
	for i := range c.Items {
		if c.Items[i].Status == "blocked" && c.Items[i].NeedsDecision {
			c.Items[i].Status = "selected"
		}
	}
}

func (s *Swarm) handleReply(c *Campaign, text string, now time.Time) {
	switch {
	case c.Phase == phasePlanning && c.PlanAsks >= 3:
		c.Decisions = append(c.Decisions, CampaignDecision{At: now, Question: "guidance after invalid plans", Answer: text})
		c.PlanAsks = 1
		c.dirty = true
		_ = s.mail("Campaign guidance", s.planPrompt(c, "")+"\nGuidance from the human: "+text+"\n")
	case c.Phase == phaseSelecting:
		if ids, ok := LiteralSelection(text, c); ok {
			c.Decisions = append(c.Decisions, CampaignDecision{At: now, Question: "which items to pursue", Answer: text})
			s.applySelection(c, ids, now)
			return
		}
		c.Decisions = append(c.Decisions, CampaignDecision{At: now, Question: "which items to pursue", Answer: text})
		c.AskedSelect, c.dirty = true, true
		_ = s.mail("Campaign selection", s.selectPrompt(c, text))
	default:
		question := "review"
		for i := range c.Items {
			if c.Items[i].Status == "blocked" {
				question = "unblock " + c.Items[i].ID
				c.Items[i].Status = "selected"
			}
		}
		c.Decisions = append(c.Decisions, CampaignDecision{At: now, Question: question, Answer: text})
		c.dirty = true
		if c.runningItem() != nil {
			_ = s.Reply(text)
		}
	}
}

func (c *Campaign) runningItem() *CampaignItem {
	for i := range c.Items {
		if c.Items[i].Status == "running" {
			return &c.Items[i]
		}
	}
	return nil
}

func (s *Swarm) stepItems(c *Campaign, now time.Time) {
	if running := c.runningItem(); running != nil {
		st := s.loadState()
		switch {
		case st.Complete && VerifiedSinceGoal(st) > 0 && !s.workersActive() && s.allGated(st):
			s.integrate(st)
			var branches, files []string
			for _, res := range st.Gated {
				if res.Status == "pass" && res.Published != "" && !res.At.Before(st.GoalAt) {
					branches = append(branches, res.Published)
					files = append(files, res.Files...)
				}
			}
			sort.Strings(branches)
			sort.Strings(files)
			if adv := s.AdvanceBase(branches); adv.Status != "pass" && adv.Status != "none" {
				running.Status = "blocked"
				c.dirty = true
				s.notify("high", "Item blocked: "+running.Title, "its verified branches ("+strings.Join(branches, ", ")+") cannot be added to the base: "+adv.problem()+"\nreply: gastown-run campaign reply "+s.Cfg.Project+" \"...\"")
				return
			}
			running.Status, running.Branches = "done", branches
			running.Summary = "verified " + strconv.Itoa(len(branches)) + " branch(es); files: " + strings.Join(dedupe(files), ", ")
			c.Learnings = append(c.Learnings, CampaignLearning{At: now, Item: running.ID, Text: running.Summary})
			c.dirty = true
			s.notify("low", "Item verified: "+running.Title, running.Summary+"\nbranches: "+strings.Join(branches, ", "))
		case !st.Complete && VerifiedSinceGoal(st) == 0 && !s.workersActive() && !st.LastActivity.IsZero() && now.Sub(st.LastActivity) >= campaignBlockedAfter:
			running.Status = "blocked"
			c.dirty = true
			s.notify("high", "Item blocked: "+running.Title, "nothing verified and nothing happening for "+campaignBlockedAfter.String()+"\nreply: gastown-run campaign reply "+s.Cfg.Project+" \"...\"")
		}
		return
	}
	next := NextRunnable(c)
	if next == nil {
		s.finishPhase(c)
		return
	}
	if err := s.Goal(s.itemGoal(c, next)); err != nil {
		s.notify("high", "Cannot start item "+next.ID, err.Error())
		return
	}
	st := s.loadState()
	st.LastActivity = now
	s.saveState(st)
	next.Status, next.GoalAt = "running", now.Format(time.RFC3339)
	c.dirty = true
	s.notify("low", "Item started: "+next.Title, "id "+next.ID)
}

func dedupe(in []string) []string {
	var out []string
	for i, v := range in {
		if i == 0 || v != in[i-1] {
			out = append(out, v)
		}
	}
	return out
}

func (s *Swarm) finishPhase(c *Campaign) {
	counts := c.counts()
	if counts["selected"] > 0 || counts["blocked"] > 0 || counts["running"] > 0 {
		return
	}
	if counts["proposed"] > 0 {
		c.Phase = phaseSelecting
		c.dirty = true
		s.notify("medium", "Selected items are done", strconv.Itoa(counts["proposed"])+" proposed item(s) remain\nchoose with: gastown-run campaign reply "+s.Cfg.Project+" \"<ids>\"")
		return
	}
	c.Phase = phaseDone
	c.dirty = true
	s.notify("low", "Campaign complete", "every selected item is verified")
}

// CampaignStep runs one round of the campaign: user replies, the plan, the
// items and the periodic digest. It saves and publishes when anything changed.
func (s *Swarm) CampaignStep(c *Campaign, now time.Time) {
	for _, in := range s.drainReplies() {
		s.handleInput(c, in, now)
	}
	switch c.Phase {
	case phasePlanning:
		if c.PlanAsks == 0 {
			if err := s.mail("Campaign plan request", s.planPrompt(c, "")); err != nil {
				s.notify("high", "Cannot ask the Mayor for a plan", err.Error())
			} else {
				c.PlanAsks, c.dirty = 1, true
			}
		}
	case phaseExecuting:
		s.stepItems(c, now)
	}
	if now.Sub(c.LastDigest) >= campaignDigestEvery {
		c.LastDigest, c.dirty = now, true
		counts := c.counts()
		s.notify("low", "Campaign digest", fmt.Sprintf("phase %s | done %d | running %d | blocked %d | selected %d | proposed %d\n%s", c.Phase,
			counts["done"], counts["running"], counts["blocked"], counts["selected"], counts["proposed"], FormatUsage(s.UpdateLedger(s.loadState().GoalAt), c.StartedAt)))
	}
	if c.dirty {
		c.dirty = false
		if err := SaveCampaign(s.campaignPath(), c); err != nil {
			s.notify("high", "Cannot save the campaign", err.Error())
		}
		if err := PublishCampaign(s.Staging(), filepath.Join(s.Dir(), "campaign-publish"), RenderCampaign(c)); err != nil {
			fmt.Fprintln(s.Out, "campaign publish:", err)
		}
	}
}

// CampaignWatch supervises the swarm and the campaign until stopped, the
// context ends or the runtime limit passes.
func (s *Swarm) CampaignWatch(ctx context.Context, c *Campaign, interval, maxRuntime time.Duration) {
	deadline := time.Now().Add(maxRuntime)
	s.mailHook = func(m mailItem) bool { return s.campaignMail(c, m, time.Now()) }
	for {
		s.Tick(time.Now())
		s.CampaignStep(c, time.Now())
		if _, err := os.Stat(s.StopFile()); err == nil {
			s.notify("medium", "Campaign stopped by STOP file", s.Cfg.Project+" (resume with campaign start)")
			return
		}
		if time.Now().After(deadline) {
			s.notify("high", "Campaign runtime limit reached", "stopping; the campaign resumes with campaign start")
			return
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(interval):
		}
	}
}

func (s *Swarm) extendPrompt(c *Campaign, direction string) string {
	state, _ := os.ReadFile(s.campaignPath())
	return "CAMPAIGN EXTENSION. Do not start any work, create no bead and sling nothing.\nNew direction from the human: " + direction +
		"\n\nThe campaign as it stands (campaign.json):\n" + string(state) + "\n\n" +
		fmt.Sprintf(stationLimits, strings.Join(s.Cfg.Checks, " ; ")) +
		"\n\nPropose ONLY additional items that this direction needs, small enough for a worker to finish and the checks to verify. " +
		"Use new ids; depends_on may name existing items. Mark needs_decision true when the human must choose. " +
		"Reply with gt mail reply and exactly one fenced json block:\n```json\n{\"items\":[{\"id\":\"short-lowercase-id\",\"title\":\"...\",\"why\":\"...\",\"depends_on\":[],\"needs_decision\":false}]}\n```\n"
}

func (s *Swarm) handleExtend(c *Campaign, direction string, now time.Time) {
	c.Decisions = append(c.Decisions, CampaignDecision{At: now, Question: "new direction", Answer: direction})
	c.ExtendAsked, c.dirty = true, true
	if err := s.mail("Campaign extension request", s.extendPrompt(c, direction)); err != nil {
		c.ExtendAsked = false
		s.notify("high", "Cannot ask the Mayor to extend the plan", err.Error())
	}
}

func (s *Swarm) campaignExtensionMail(c *Campaign, m mailItem) bool {
	if !c.ExtendAsked || len(fencedBlocks(m.Body)) == 0 {
		return false
	}
	items, err := ParseExtension(m.Body, c)
	if err != nil {
		c.ExtendAsked, c.dirty = false, true
		s.notify("high", "Plan extension rejected", err.Error()+"\nask again with: gastown-run campaign extend "+s.Cfg.Project+" \"...\"")
		return true
	}
	c.Items = append(c.Items, items...)
	c.ExtendAsked, c.dirty = false, true
	var lines []string
	for _, it := range items {
		line := it.ID + ": " + it.Title
		if len(it.DependsOn) > 0 {
			line += " (after " + strings.Join(it.DependsOn, ", ") + ")"
		}
		if it.NeedsDecision {
			line += " [needs your decision]"
		}
		lines = append(lines, line)
	}
	s.notify("medium", "Plan extended: "+strconv.Itoa(len(items))+" new item(s)", strings.Join(lines, "\n")+"\nchoose with: gastown-run campaign reply "+s.Cfg.Project+" \"<ids>\"")
	return true
}

func (s *Swarm) handleApprove(c *Campaign, id string, branches []string, now time.Time) {
	refuse := func(why string) {
		s.notify("high", "Cannot approve "+id, why)
	}
	it := c.item(id)
	if it == nil {
		refuse("no such item")
		return
	}
	st := s.loadState()
	verified := map[string]bool{}
	for _, res := range st.Gated {
		if res.Status == "pass" && res.Published != "" {
			verified[res.Published] = true
		}
	}
	for _, b := range branches {
		if !verified[b] {
			refuse(b + " was never accepted by the trusted gate; an item is only done with gate-verified branches")
			return
		}
	}
	if len(branches) == 0 {
		refuse("no branches given")
		return
	}
	if adv := s.AdvanceBase(branches); adv.Status != "pass" && adv.Status != "none" {
		refuse("the branches cannot be added to the base: " + adv.problem())
		return
	}
	sort.Strings(branches)
	it.Status, it.Branches = "done", branches
	it.Summary = "approved by the user on " + now.Format("2006-01-02") + "; gate-verified branches: " + strings.Join(branches, ", ")
	c.Decisions = append(c.Decisions, CampaignDecision{At: now, Question: "approve " + id, Answer: "approved by the user with " + strings.Join(branches, ", ")})
	c.Learnings = append(c.Learnings, CampaignLearning{At: now, Item: id, Text: it.Summary})
	c.dirty = true
	s.notify("low", "Item approved: "+it.Title, it.Summary)
}
