package gastown

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

type CampaignItem struct {
	ID            string   `json:"id"`
	Title         string   `json:"title"`
	Why           string   `json:"why"`
	DependsOn     []string `json:"depends_on"`
	NeedsDecision bool     `json:"needs_decision"`
	Status        string   `json:"status"`
	GoalAt        string   `json:"goal_at,omitempty"`
	Branches      []string `json:"branches,omitempty"`
	Summary       string   `json:"summary,omitempty"`
}

type CampaignDecision struct {
	At       time.Time `json:"at"`
	Question string    `json:"question"`
	Answer   string    `json:"answer"`
}

type CampaignLearning struct {
	At   time.Time `json:"at"`
	Item string    `json:"item"`
	Text string    `json:"text"`
}

// CampaignProcess is the delivery process the Mayor proposes for an intent:
// how the result is tested, built and shipped. The user confirms or changes it
// through answers; every item goal carries it.
type CampaignProcess struct {
	Test  string `json:"test"`
	Build string `json:"build"`
	Ship  string `json:"ship"`
}

// CampaignQuestion is something the Mayor needs to know from the user, for
// example which build resources exist.
type CampaignQuestion struct {
	ID         string    `json:"id"`
	Text       string    `json:"text"`
	Options    []string  `json:"options,omitempty"`
	Answer     string    `json:"answer,omitempty"`
	AnsweredAt time.Time `json:"answered_at,omitempty"`
}

// Campaign is the supervisor-owned memory of one intent. Models never write it.
type Campaign struct {
	Intent      string             `json:"intent"`
	Phase       string             `json:"phase"`
	Process     CampaignProcess    `json:"process"`
	Questions   []CampaignQuestion `json:"questions"`
	Items       []CampaignItem     `json:"items"`
	Decisions   []CampaignDecision `json:"decisions"`
	Learnings   []CampaignLearning `json:"learnings"`
	PlanAsks    int                `json:"plan_asks"`
	LastDigest  time.Time          `json:"last_digest"`
	StartedAt   time.Time          `json:"started_at"`
	AskedSelect bool               `json:"asked_select,omitempty"`
	dirty       bool
}

const (
	phasePlanning  = "planning"
	phaseSelecting = "awaiting_selection"
	phaseExecuting = "executing"
	phaseDone      = "done"
)

var (
	itemIDPattern = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{0,40}$`)
	fencedJSON    = regexp.MustCompile("(?s)```(?:json)?\\s*(\\{.*?\\})\\s*```")
)

func (s *Swarm) campaignPath() string { return filepath.Join(s.Dir(), "campaign.json") }

func LoadCampaign(path string) (*Campaign, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	c := &Campaign{}
	if err := json.Unmarshal(data, c); err != nil {
		return nil, err
	}
	return c, nil
}

func SaveCampaign(path string, c *Campaign) error {
	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, append(data, '\n'), 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func (c *Campaign) item(id string) *CampaignItem {
	for i := range c.Items {
		if c.Items[i].ID == id {
			return &c.Items[i]
		}
	}
	return nil
}

func fencedBlocks(body string) []string {
	var out []string
	for _, m := range fencedJSON.FindAllStringSubmatch(body, -1) {
		out = append(out, m[1])
	}
	return out
}

// CampaignPlan is what the Mayor proposes: the delivery process, the questions
// it needs answered and the items.
type CampaignPlan struct {
	Process   CampaignProcess    `json:"process"`
	Questions []CampaignQuestion `json:"questions"`
	Items     []CampaignItem     `json:"items"`
}

// ParsePlan extracts and validates a plan: a complete delivery process, unique
// question and item ids, known dependencies, no cycles.
func ParsePlan(body string) (CampaignPlan, error) {
	var plan CampaignPlan
	found := false
	for _, block := range fencedBlocks(body) {
		var candidate CampaignPlan
		if json.Unmarshal([]byte(block), &candidate) == nil && candidate.Items != nil {
			plan, found = candidate, true
			break
		}
	}
	if !found {
		return plan, errors.New("no fenced ```json block with an \"items\" array")
	}
	return plan, validatePlan(&plan)
}

func validatePlan(plan *CampaignPlan) error {
	if len(plan.Items) == 0 {
		return errors.New("the plan has no items")
	}
	for name, v := range map[string]string{"test": plan.Process.Test, "build": plan.Process.Build, "ship": plan.Process.Ship} {
		if strings.TrimSpace(v) == "" {
			return fmt.Errorf("process.%s is required: say how the result will be %s", name, map[string]string{"test": "tested", "build": "built", "ship": "shipped"}[name])
		}
	}
	qids := map[string]bool{}
	for i := range plan.Questions {
		q := &plan.Questions[i]
		if !itemIDPattern.MatchString(q.ID) || strings.TrimSpace(q.Text) == "" || qids[q.ID] {
			return fmt.Errorf("question %q needs a unique lowercase id and a text", q.ID)
		}
		qids[q.ID] = true
		q.Answer, q.AnsweredAt = "", time.Time{}
	}
	ids := map[string]bool{}
	for _, it := range plan.Items {
		if !itemIDPattern.MatchString(it.ID) {
			return fmt.Errorf("item id %q must match %s", it.ID, itemIDPattern)
		}
		if ids[it.ID] {
			return fmt.Errorf("duplicate item id %q", it.ID)
		}
		if strings.TrimSpace(it.Title) == "" {
			return fmt.Errorf("item %q has no title", it.ID)
		}
		ids[it.ID] = true
	}
	deps := map[string][]string{}
	for i := range plan.Items {
		it := &plan.Items[i]
		for _, d := range it.DependsOn {
			if !ids[d] {
				return fmt.Errorf("item %q depends on unknown item %q", it.ID, d)
			}
			if d == it.ID {
				return fmt.Errorf("item %q depends on itself", it.ID)
			}
		}
		deps[it.ID] = it.DependsOn
		it.Status = "proposed"
		it.GoalAt, it.Branches, it.Summary = "", nil, ""
	}
	state := map[string]int{}
	var visit func(id string) bool
	visit = func(id string) bool {
		switch state[id] {
		case 1:
			return false
		case 2:
			return true
		}
		state[id] = 1
		for _, d := range deps[id] {
			if !visit(d) {
				return false
			}
		}
		state[id] = 2
		return true
	}
	for _, it := range plan.Items {
		if !visit(it.ID) {
			return errors.New("the dependencies contain a cycle")
		}
	}
	return nil
}

// ParseSelection reads {"select": [...]} and keeps only ids that exist and are
// still proposed.
func ParseSelection(body string, c *Campaign) ([]string, bool) {
	for _, block := range fencedBlocks(body) {
		var sel struct {
			Select []string `json:"select"`
		}
		if json.Unmarshal([]byte(block), &sel) != nil || sel.Select == nil {
			continue
		}
		var out []string
		seen := map[string]bool{}
		for _, id := range sel.Select {
			if it := c.item(id); it != nil && it.Status == "proposed" && !seen[id] {
				seen[id] = true
				out = append(out, id)
			}
		}
		return out, true
	}
	return nil, false
}

var selectionWords = regexp.MustCompile(`[\s,;]+`)

// LiteralSelection resolves a reply that is only item ids ("a c", "all"), so
// the plain case never costs a model round trip.
func LiteralSelection(text string, c *Campaign) ([]string, bool) {
	text = strings.ToLower(strings.TrimSpace(text))
	if text == "" {
		return nil, false
	}
	var out []string
	if text == "all" || text == "todo" || text == "todos" {
		for _, it := range c.Items {
			if it.Status == "proposed" {
				out = append(out, it.ID)
			}
		}
		return out, len(out) > 0
	}
	seen := map[string]bool{}
	for _, word := range selectionWords.Split(text, -1) {
		if word == "" || word == "y" || word == "and" {
			continue
		}
		it := c.item(word)
		if it == nil {
			return nil, false
		}
		if it.Status == "proposed" && !seen[word] {
			seen[word] = true
			out = append(out, word)
		}
	}
	return out, len(out) > 0
}

// NextRunnable returns the first selected item, in plan order, whose
// dependencies are done and that is not waiting for a decision.
func NextRunnable(c *Campaign) *CampaignItem {
	for i := range c.Items {
		it := &c.Items[i]
		if it.Status != "selected" {
			continue
		}
		ready := true
		for _, d := range it.DependsOn {
			if dep := c.item(d); dep == nil || dep.Status != "done" {
				ready = false
			}
		}
		if ready {
			return it
		}
	}
	return nil
}

func (c *Campaign) counts() map[string]int {
	out := map[string]int{}
	for _, it := range c.Items {
		out[it.Status]++
	}
	return out
}

// RenderCampaign is the CAMPAIGN.md published for the user to pull into the
// project's own odd/ directory.
func RenderCampaign(c *Campaign) string {
	var b strings.Builder
	fmt.Fprintf(&b, "# Campaign\n\nIntent: %s\n\nPhase: %s\n\n## Delivery process\n\n- test: %s\n- build: %s\n- ship: %s\n\n## Questions\n\n", c.Intent, c.Phase, c.Process.Test, c.Process.Build, c.Process.Ship)
	for _, q := range c.Questions {
		answer := "(unanswered)"
		if q.Answer != "" {
			answer = q.Answer
		}
		fmt.Fprintf(&b, "- %s: %s -> %s\n", q.ID, q.Text, answer)
	}
	b.WriteString("\n## Items\n\n")
	for _, it := range c.Items {
		fmt.Fprintf(&b, "- [%s] **%s** (%s) %s\n", map[bool]string{true: "x", false: " "}[it.Status == "done"], it.ID, it.Status, it.Title)
		if it.Why != "" {
			fmt.Fprintf(&b, "  - why: %s\n", it.Why)
		}
		if len(it.DependsOn) > 0 {
			fmt.Fprintf(&b, "  - depends on: %s\n", strings.Join(it.DependsOn, ", "))
		}
		if it.Summary != "" {
			fmt.Fprintf(&b, "  - result: %s\n", it.Summary)
		}
		if len(it.Branches) > 0 {
			fmt.Fprintf(&b, "  - branches: %s\n", strings.Join(it.Branches, ", "))
		}
	}
	b.WriteString("\n## Decisions\n\n")
	for _, d := range c.Decisions {
		fmt.Fprintf(&b, "- %s | %s -> %s\n", d.At.Format("2006-01-02 15:04"), d.Question, d.Answer)
	}
	b.WriteString("\n## Learnings\n\n")
	for _, l := range c.Learnings {
		fmt.Fprintf(&b, "- %s | %s: %s\n", l.At.Format("2006-01-02 15:04"), l.Item, l.Text)
	}
	return b.String()
}

// PublishCampaign commits CAMPAIGN.md to branch gastown/campaign of the staging
// repository, keeping that branch's history.
func PublishCampaign(staging, workDir, markdown string) error {
	if err := os.RemoveAll(workDir); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(workDir), 0o700); err != nil {
		return err
	}
	if _, err := runGit("", "clone", "-q", staging, workDir); err != nil {
		return err
	}
	if _, err := runGit(workDir, "ls-remote", "--exit-code", "--heads", "origin", "gastown/campaign"); err == nil {
		if _, err := runGit(workDir, "checkout", "-q", "-B", "campaign", "origin/gastown/campaign"); err != nil {
			return err
		}
	} else if _, err := runGit(workDir, "checkout", "-q", "--orphan", "campaign"); err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(workDir, "CAMPAIGN.md"), []byte(markdown), 0o644); err != nil {
		return err
	}
	if _, err := runGit(workDir, "add", "CAMPAIGN.md"); err != nil {
		return err
	}
	if out, _ := runGit(workDir, "status", "--porcelain"); strings.TrimSpace(out) == "" {
		return nil
	}
	if _, err := runGit(workDir, "commit", "-q", "-m", "campaign: update CAMPAIGN.md"); err != nil {
		return err
	}
	_, err := runGit(workDir, "push", "-q", "origin", "campaign:refs/heads/gastown/campaign")
	return err
}

// ResumeCampaign returns interrupted items to selected so their goals are sent
// again to a fresh Mayor. Items that already ended (done, blocked) are kept.
// It reports how many items it reset.
func ResumeCampaign(c *Campaign) int {
	n := 0
	for i := range c.Items {
		if c.Items[i].Status == "running" {
			c.Items[i].Status, c.Items[i].GoalAt = "selected", ""
			n++
		}
	}
	if n > 0 {
		c.dirty = true
	}
	return n
}

// hoistFlags moves the named flags (with their value) in front of the first
// positional argument, so they work before or after the project name. The
// remaining free text is never parsed as flags.
func hoistFlags(args []string, names ...string) []string {
	var flags, rest []string
	match := func(a string) (name string, inline, ok bool) {
		for _, n := range names {
			if a == "--"+n {
				return n, false, true
			}
			if strings.HasPrefix(a, "--"+n+"=") {
				return n, true, true
			}
		}
		return "", false, false
	}
	for i := 0; i < len(args); i++ {
		if _, inline, ok := match(args[i]); ok {
			flags = append(flags, args[i])
			if !inline && i+1 < len(args) {
				i++
				flags = append(flags, args[i])
			}
			continue
		}
		rest = append(rest, args[i])
	}
	return append(flags, rest...)
}
