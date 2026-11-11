package gastown

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

type WatchState struct {
	Seen         map[string]bool       `json:"seen"`
	Gated        map[string]GateResult `json:"gated"`
	Cooldowns    map[string]time.Time  `json:"cooldowns"`
	Active       map[string]string     `json:"active"`
	Complete     bool                  `json:"complete"`
	Paused       bool                  `json:"paused"`
	LastActivity time.Time             `json:"last_activity"`
	GoalAt       time.Time             `json:"goal_at"`
}

type escItem struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Status      string `json:"status"`
}

type mailItem struct {
	ID       string `json:"id"`
	From     string `json:"from"`
	Subject  string `json:"subject"`
	Body     string `json:"body"`
	Read     bool   `json:"read"`
	Priority string `json:"priority"`
}

type polecatItem struct {
	Name           string `json:"name"`
	SessionRunning bool   `json:"session_running"`
}

var descriptionSeverity = regexp.MustCompile(`(?im)^severity:\s*(low|medium|high|critical)\b`)

var severityPrefix = regexp.MustCompile(`^\[(LOW|MEDIUM|HIGH|CRITICAL)\]\s*`)

func (s *Swarm) statePath() string { return filepath.Join(s.Dir(), "watch.json") }

func (s *Swarm) loadState() *WatchState {
	st := &WatchState{}
	if data, err := os.ReadFile(s.statePath()); err == nil {
		_ = json.Unmarshal(data, st)
	}
	if st.Seen == nil {
		st.Seen = map[string]bool{}
	}
	if st.Gated == nil {
		st.Gated = map[string]GateResult{}
	}
	if st.Cooldowns == nil {
		st.Cooldowns = map[string]time.Time{}
	}
	if st.Active == nil {
		st.Active = map[string]string{}
	}
	return st
}

func (s *Swarm) saveState(st *WatchState) {
	data, _ := json.MarshalIndent(st, "", "  ")
	tmp := s.statePath() + ".tmp"
	if os.WriteFile(tmp, data, 0o600) == nil {
		_ = os.Rename(tmp, s.statePath())
	}
}

func (s *Swarm) notifier() *Notifier {
	return &Notifier{LogPath: filepath.Join(s.Dir(), "notifications.jsonl"), Cmd: s.Cfg.NotifyCmd}
}

func clip(text string, n int) string {
	text = strings.TrimSpace(text)
	if len(text) > n {
		return text[:n] + "..."
	}
	return text
}

func (s *Swarm) humanEnv() []string { return append(s.env(), "GT_ROLE=overseer") }

func (s *Swarm) jsonOut(env []string, dst any, name string, args ...string) error {
	res, err := s.R.Exec.Run(Command{Name: name, Args: args, Dir: s.Town(), Env: env, Timeout: time.Minute})
	if err != nil {
		return err
	}
	if res.Exit != 0 {
		return fmt.Errorf("%s %s: exit %d", filepath.Base(name), strings.Join(args, " "), res.Exit)
	}
	return json.Unmarshal(res.Stdout, dst)
}

func (s *Swarm) notify(severity, title, body string) {
	if err := s.notifier().Notify(severity, title, body); err != nil {
		fmt.Fprintln(s.Out, "notify:", err)
	}
	fmt.Fprintf(s.Out, "[%s] %s\n", severity, title)
}

func (s *Swarm) tickEscalations(st *WatchState) {
	var items []escItem
	if err := s.jsonOut(s.humanEnv(), &items, s.R.Config.GT, "escalate", "list", "--json"); err != nil {
		return
	}
	byID := map[string]escItem{}
	var ids []string
	for _, it := range items {
		if it.Status == "open" {
			byID[it.ID] = it
			ids = append(ids, it.ID)
		}
	}
	for _, id := range NewItems(st.Seen, prefixed("esc:", ids)) {
		st.LastActivity = time.Now()
		it := byID[strings.TrimPrefix(id, "esc:")]
		severity := "medium"
		if m := severityPrefix.FindStringSubmatch(it.Title); m != nil {
			severity = strings.ToLower(m[1])
		} else if m := descriptionSeverity.FindStringSubmatch(it.Description); m != nil {
			severity = strings.ToLower(m[1])
		}
		title := severityPrefix.ReplaceAllString(it.Title, "")
		if strings.Contains(strings.ToLower(title), "goal complete") {
			if VerifiedSinceGoal(st) == 0 {
				s.notify("high", "Mayor declared the goal complete but no verified branch exists", "claim, not verified: "+clip(it.Description, 500)+"\nThe gate has accepted nothing since the goal was sent, so this is not accepted as done.")
				continue
			}
			st.Complete = true
			s.notify("low", "Goal complete", clip(it.Description, 600)+"\n(accepted: "+strconv.Itoa(VerifiedSinceGoal(st))+" verified branch(es))")
			continue
		}
		s.notify(severity, "Needs you: "+title, clip(it.Description, 700)+"\nreply: gastown-run swarm reply "+s.Cfg.Project+" \"...\"")
	}
}

func prefixed(prefix string, ids []string) []string {
	out := make([]string, len(ids))
	for i, id := range ids {
		out[i] = prefix + id
	}
	return out
}

func (s *Swarm) tickMail(st *WatchState) {
	var items []mailItem
	if err := s.jsonOut(s.humanEnv(), &items, s.R.Config.GT, "mail", "inbox", "--json"); err != nil {
		return
	}
	byID := map[string]mailItem{}
	var ids []string
	for _, m := range items {
		if !m.Read {
			byID[m.ID] = m
			ids = append(ids, m.ID)
		}
	}
	for _, id := range NewItems(st.Seen, prefixed("mail:", ids)) {
		st.LastActivity = time.Now()
		m := byID[strings.TrimPrefix(id, "mail:")]
		s.notify("medium", "Mayor (unverified): "+m.Subject, "claim, not verified by the gate: "+clip(m.Body, 650))
	}
}

func (s *Swarm) tickGate(st *WatchState) {
	out, err := runGit("", "-C", s.RigRepo(), "for-each-ref", "--format=%(refname:short)", "refs/heads/polecat/")
	if err != nil {
		return
	}
	for _, branch := range strings.Fields(out) {
		parts := strings.Split(branch, "/")
		if len(parts) < 3 {
			continue
		}
		bead, _, _ := strings.Cut(parts[len(parts)-1], "+")
		polecat := parts[1]
		if !ValidBeadID(bead) {
			continue
		}
		tip, _ := runGit("", "-C", s.RigRepo(), "rev-parse", branch)
		key := bead + "@" + strings.TrimSpace(tip)
		if _, done := st.Gated[key]; done || !s.beadClosed(bead) {
			continue
		}
		workDir := filepath.Join(s.Dir(), "gate", bead)
		res := s.R.Gate(GateInput{RigRepo: s.RigRepo(), Branch: branch, Base: s.base(), Bead: bead, Staging: s.Staging(), WorkDir: workDir, Protect: s.Cfg.Protect},
			func(dir string, _ []string) []CheckResult {
				return s.R.RunChecks(dir, s.Cfg.Checks, filepath.Join(s.Dir(), "gate-logs", bead))
			})
		res.At = time.Now()
		st.Gated[key] = res
		st.LastActivity = time.Now()
		s.wakeMayor(bead, res)
		switch res.Status {
		case "pass":
			body := fmt.Sprintf("files: %s\nreview: git fetch %s %s", strings.Join(res.Files, ", "), s.Staging(), res.Published)
			if len(res.Dropped) > 0 {
				body += "\ndropped Gas Town files: " + strings.Join(res.Dropped, ", ")
			}
			for _, n := range res.Notes {
				body += "\nnote: " + n
			}
			s.notify("low", "Ready for review: "+bead, body)
			_, _ = s.gt("polecat", "nuke", s.Cfg.Project+"/"+polecat, "--force")
		case "empty":
			s.notify("low", "No project changes in "+bead, "the worker only left Gas Town files; nothing to review")
			_, _ = s.gt("polecat", "nuke", s.Cfg.Project+"/"+polecat, "--force")
		case "fail":
			reason := "the checks failed"
			if res.Detail != "" {
				reason = res.Detail
			}
			s.notify("high", "Rejected "+bead+": "+reason, "the branch was NOT published. Logs: "+filepath.Join(s.Dir(), "gate-logs", bead))
		default:
			s.notify("high", "Gate error for "+bead, clip(res.Detail, 500))
		}
	}
}

func (s *Swarm) beadClosed(bead string) bool {
	var one []struct {
		Status string `json:"status"`
	}
	env := s.env()
	res, err := s.R.Exec.Run(Command{Name: s.R.Config.BD, Args: []string{"show", bead, "--json"}, Dir: filepath.Join(s.Town(), s.Cfg.Project), Env: env, Timeout: time.Minute})
	if err != nil || res.Exit != 0 || json.Unmarshal(res.Stdout, &one) != nil || len(one) == 0 {
		return false
	}
	return one[0].Status == "closed"
}

func (s *Swarm) tickProviders(st *WatchState, now time.Time) {
	_, chains, err := s.presets()
	if err != nil || len(chains["polecat"]) < 2 {
		return
	}
	chain := chains["polecat"]
	if st.Active["polecat"] == "" {
		st.Active["polecat"] = chain[0]
	}
	var polecats []polecatItem
	if err := s.jsonOut(s.env(), &polecats, s.R.Config.GT, "polecat", "list", s.Cfg.Project, "--json"); err == nil {
		for _, p := range polecats {
			if !p.SessionRunning {
				continue
			}
			res, perr := s.R.Exec.Run(Command{Name: s.R.Config.GT, Args: []string{"peek", s.Cfg.Project + "/" + p.Name, "40"}, Dir: s.Town(), Env: s.env(), Timeout: time.Minute})
			if perr == nil && LimitHit(string(res.Stdout)) {
				st.Cooldowns[st.Active["polecat"]] = now.Add(30 * time.Minute)
				s.notify("high", "Provider limit on "+st.Active["polecat"], "worker "+p.Name+" hit a limit; cooling this agent for 30 minutes")
				break
			}
		}
	}
	pick, healthy := PickAgent(chain, st.Cooldowns, now)
	switch {
	case !healthy && !st.Paused:
		st.Paused = true
		_, _ = s.gt("scheduler", "pause")
		s.notify("critical", "All providers are limited", "dispatch paused; the first recovers at "+st.Cooldowns[pick].Format(time.RFC3339))
	case healthy && st.Paused:
		st.Paused = false
		_, _ = s.gt("scheduler", "resume")
		s.notify("medium", "Dispatch resumed", "agent "+pick+" is available again")
	}
	if healthy && pick != st.Active["polecat"] {
		from := st.Active["polecat"]
		st.Active["polecat"] = pick
		roles := s.roleAgents(st.Active)
		if err := s.writeRoleAgents(roles); err == nil {
			s.notify("medium", "Switched worker agent", from+" -> "+pick)
		}
	}
}

// Tick runs one supervision round: it surfaces what needs the human, gates
// finished work and keeps the worker provider healthy.
func (s *Swarm) Tick(now time.Time) *WatchState {
	st := s.loadState()
	s.tickEscalations(st)
	s.tickMail(st)
	s.tickGate(st)
	s.tickProviders(st, now)
	s.UpdateLedger(st.GoalAt)
	active := s.workersActive()
	if active {
		st.LastActivity = now
	}
	if IdleComplete(st, now, s.idleAfter(), active) {
		st.Complete = true
		s.notify("low", "Swarm idle: treating the goal as complete", "all work is gated and nothing has happened for "+s.idleAfter().String())
	}
	s.saveState(st)
	return st
}

// Watch supervises until the goal is complete and gated, a STOP file appears,
// the context ends or the runtime limit passes.
func (s *Swarm) Watch(ctx context.Context, interval, maxRuntime time.Duration, untilComplete bool) {
	deadline := time.Now().Add(maxRuntime)
	for {
		st := s.Tick(time.Now())
		if _, err := os.Stat(s.StopFile()); err == nil {
			s.notify("medium", "Swarm stopped by STOP file", s.Cfg.Project)
			return
		}
		if untilComplete && ShouldFinish(st, time.Now(), s.idleAfter(), s.allGated(st), s.workersActive()) {
			s.integrate(st)
			s.finishNotice(st)
			return
		}
		if time.Now().After(deadline) {
			s.notify("high", "Swarm runtime limit reached", "stopping; unfinished work stays in "+s.Dir())
			return
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(interval):
		}
	}
}

func (s *Swarm) finishNotice(st *WatchState) {
	recs := s.UpdateLedger(st.GoalAt)
	s.notify("low", "Swarm finished", "goal verified and nothing left to do; shutting the swarm down\ntokens:\n"+FormatUsage(recs, st.GoalAt))
}

func (s *Swarm) allGated(st *WatchState) bool {
	out, err := runGit("", "-C", s.RigRepo(), "for-each-ref", "--format=%(refname:short)", "refs/heads/polecat/")
	if err != nil {
		return false
	}
	for _, branch := range strings.Fields(out) {
		bead, _, _ := strings.Cut(branch[strings.LastIndex(branch, "/")+1:], "+")
		if !ValidBeadID(bead) {
			continue
		}
		if ahead, err := runGit("", "-C", s.RigRepo(), "rev-list", "--count", s.base()+".."+branch); err != nil || strings.TrimSpace(ahead) == "0" {
			continue
		}
		tip, _ := runGit("", "-C", s.RigRepo(), "rev-parse", branch)
		if res, done := st.Gated[bead+"@"+strings.TrimSpace(tip)]; !done || res.Status == "fail" || res.Status == "error" {
			return false
		}
	}
	return true
}

func (s *Swarm) Status() error {
	st := s.loadState()
	fmt.Fprintf(s.Out, "project %s | active worker agent: %s\n", s.Cfg.Project, firstNonEmpty(st.Active["polecat"], "(default)"))
	for _, args := range [][]string{{"scheduler", "status"}, {"polecat", "list", s.Cfg.Project}} {
		if out, err := s.gt(args...); err == nil {
			fmt.Fprint(s.Out, string(out))
		}
	}
	fmt.Fprintf(s.Out, "gated: %d | goal complete: %v | paused: %v\n", len(st.Gated), st.Complete, st.Paused)
	for key, res := range st.Gated {
		fmt.Fprintf(s.Out, "  %s: %s %s\n", key, res.Status, res.Published)
	}
	return nil
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

// VerifiedSinceGoal counts branches that passed the gate after the goal was sent.
func VerifiedSinceGoal(st *WatchState) int {
	n := 0
	for _, res := range st.Gated {
		if res.Status == "pass" && !res.At.Before(st.GoalAt) {
			n++
		}
	}
	return n
}

func (s *Swarm) wakeMayor(bead string, res GateResult) {
	text := fmt.Sprintf("Trusted gate verdict for bead %s: %s. Accepted files: %s. Dropped Gas Town files: %s. This verdict is authoritative; do not re-verify it. Continue with any remaining work; if everything is done send the goal complete escalation.",
		bead, res.Status, strings.Join(res.Files, ", "), strings.Join(res.Dropped, ", "))
	_, _ = s.gt("nudge", "mayor", text)
}

// IdleComplete reports whether a swarm that has gated work has been quiet long
// enough, with no active workers, to be treated as finished without waiting for
// a model to say so.
func IdleComplete(st *WatchState, now time.Time, quiet time.Duration, workersActive bool) bool {
	return !st.Complete && !workersActive && VerifiedSinceGoal(st) > 0 && !st.LastActivity.IsZero() && now.Sub(st.LastActivity) >= quiet
}

func (s *Swarm) workersActive() bool {
	var status struct {
		QueuedTotal   int `json:"queued_total"`
		ActivePolecat int `json:"active_polecats"`
	}
	if err := s.jsonOut(s.env(), &status, s.R.Config.GT, "scheduler", "status", "--json"); err != nil {
		return true
	}
	return status.QueuedTotal > 0 || status.ActivePolecat > 0
}

func (s *Swarm) idleAfter() time.Duration {
	if s.Cfg.IdleMinutes > 0 {
		return time.Duration(s.Cfg.IdleMinutes) * time.Minute
	}
	return 4 * time.Minute
}

// ShouldFinish reports when a verified, completed goal can shut the swarm
// down: every branch is gated, or nothing has happened for the quiet period.
func ShouldFinish(st *WatchState, now time.Time, quiet time.Duration, allGated, workersActive bool) bool {
	if !st.Complete || workersActive {
		return false
	}
	return allGated || (!st.LastActivity.IsZero() && now.Sub(st.LastActivity) >= quiet)
}

// integrate combines the branches accepted for this goal and checks the whole.
func (s *Swarm) integrate(st *WatchState) {
	var branches []string
	for _, res := range st.Gated {
		if res.Status == "pass" && res.Published != "" && !res.At.Before(st.GoalAt) {
			branches = append(branches, res.Published)
		}
	}
	sort.Strings(branches)
	r := Integrate(s.Staging(), filepath.Join(s.Dir(), "integrate"), s.base(), branches,
		func(dir string, _ []string) []CheckResult {
			return s.R.RunChecks(dir, s.Cfg.Checks, filepath.Join(s.Dir(), "gate-logs", "integrated"))
		})
	switch r.Status {
	case "pass":
		s.notify("low", "Integrated result ready", "all accepted branches merged and the checks pass on the whole: git fetch "+s.Staging()+" "+r.Published)
	case "conflict":
		s.notify("high", "Accepted branches conflict", "they do not merge cleanly: "+r.Conflict+" conflicts with the others. Merge them by hand from "+s.Staging())
	case "fail":
		s.notify("high", "Branches pass alone but fail together", "the checks fail on the combined result; review the branches in "+s.Staging())
	case "error":
		s.notify("high", "Integration error", clip(r.Detail, 400))
	}
}
