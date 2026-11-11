package gastown

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

// UsageRecord is the token usage of one agent session with one model.
// Input excludes cached tokens, so the columns add up without double counting.
type UsageRecord struct {
	Agent      string    `json:"agent"`
	Session    string    `json:"session"`
	Model      string    `json:"model"`
	Role       string    `json:"role"`
	At         time.Time `json:"at"`
	GoalAt     time.Time `json:"goal_at"`
	Input      int64     `json:"input"`
	Cached     int64     `json:"cached"`
	CacheWrite int64     `json:"cache_write"`
	Output     int64     `json:"output"`
	Reasoning  int64     `json:"reasoning"`
	Source     string    `json:"source"`
}

func (u UsageRecord) key() string { return u.Agent + "\x00" + u.Session + "\x00" + u.Model }

func (u UsageRecord) total() int64 { return u.Input + u.Cached + u.CacheWrite + u.Output }

var roleDirs = map[string]string{"mayor": "mayor", "deacon": "deacon", "polecats": "polecat", "witness": "witness", "refinery": "refinery", "crew": "crew"}

// RoleFromDir names the Gas Town role that works in dir, judged by the path
// below the town root.
func RoleFromDir(town, dir string) string {
	rel, err := filepath.Rel(town, dir)
	if err != nil || strings.HasPrefix(rel, "..") {
		return "other"
	}
	for _, part := range strings.Split(rel, string(filepath.Separator)) {
		if role, ok := roleDirs[part]; ok {
			return role
		}
	}
	return "other"
}

func parseTime(text string) time.Time {
	t, _ := time.Parse(time.RFC3339Nano, text)
	return t
}

// ParseCodexRollout reads one Codex rollout file: the last cumulative
// token_count event is the session total. It returns false when the session
// never reported usage.
func ParseCodexRollout(r io.Reader, town, source string) (UsageRecord, bool) {
	rec := UsageRecord{Agent: "codex", Source: source}
	var seen bool
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 1<<20), 64<<20)
	for scanner.Scan() {
		var line struct {
			Timestamp string `json:"timestamp"`
			Type      string `json:"type"`
			Payload   struct {
				Type  string `json:"type"`
				ID    string `json:"id"`
				Cwd   string `json:"cwd"`
				Model string `json:"model"`
				Info  *struct {
					Total struct {
						Input     int64 `json:"input_tokens"`
						Cached    int64 `json:"cached_input_tokens"`
						Output    int64 `json:"output_tokens"`
						Reasoning int64 `json:"reasoning_output_tokens"`
					} `json:"total_token_usage"`
				} `json:"info"`
			} `json:"payload"`
		}
		if json.Unmarshal(scanner.Bytes(), &line) != nil {
			continue
		}
		switch {
		case line.Type == "session_meta":
			rec.Session, rec.Role, rec.At = line.Payload.ID, RoleFromDir(town, line.Payload.Cwd), parseTime(line.Timestamp)
		case line.Type == "turn_context" && line.Payload.Model != "":
			rec.Model = line.Payload.Model
		case line.Payload.Type == "token_count" && line.Payload.Info != nil:
			t := line.Payload.Info.Total
			rec.Input, rec.Cached, rec.Output, rec.Reasoning = t.Input-t.Cached, t.Cached, t.Output, t.Reasoning
			seen = true
		}
	}
	return rec, seen && rec.Session != ""
}

// ParseClaudeTranscript sums the usage of every assistant message of one
// Claude Code transcript, per model. A message is written once per content
// block, so it counts once per message id.
func ParseClaudeTranscript(r io.Reader, town, source string) []UsageRecord {
	type usage struct{ in, cached, write, out int64 }
	type message struct {
		model string
		usage usage
	}
	messages := map[string]message{}
	var order []string
	var session, dir string
	var at time.Time
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 1<<20), 64<<20)
	for scanner.Scan() {
		var line struct {
			Timestamp string `json:"timestamp"`
			SessionID string `json:"sessionId"`
			Cwd       string `json:"cwd"`
			Message   struct {
				ID    string `json:"id"`
				Model string `json:"model"`
				Usage *struct {
					Input      int64 `json:"input_tokens"`
					Output     int64 `json:"output_tokens"`
					CacheWrite int64 `json:"cache_creation_input_tokens"`
					CacheRead  int64 `json:"cache_read_input_tokens"`
				} `json:"usage"`
			} `json:"message"`
		}
		if json.Unmarshal(scanner.Bytes(), &line) != nil {
			continue
		}
		if session == "" && line.SessionID != "" {
			session, dir, at = line.SessionID, line.Cwd, parseTime(line.Timestamp)
		}
		u := line.Message.Usage
		if u == nil || line.Message.ID == "" || line.Message.Model == "" || line.Message.Model == "<synthetic>" {
			continue
		}
		if _, known := messages[line.Message.ID]; !known {
			order = append(order, line.Message.ID)
		}
		messages[line.Message.ID] = message{model: line.Message.Model, usage: usage{u.Input, u.CacheRead, u.CacheWrite, u.Output}}
	}
	perModel := map[string]*UsageRecord{}
	var models []string
	for _, id := range order {
		m := messages[id]
		rec := perModel[m.model]
		if rec == nil {
			rec = &UsageRecord{Agent: "claude", Session: session, Model: m.model, Role: RoleFromDir(town, dir), At: at, Source: source}
			perModel[m.model] = rec
			models = append(models, m.model)
		}
		rec.Input += m.usage.in
		rec.Cached += m.usage.cached
		rec.CacheWrite += m.usage.write
		rec.Output += m.usage.out
	}
	var out []UsageRecord
	for _, model := range models {
		if rec := perModel[model]; session != "" && rec.total() > 0 {
			out = append(out, *rec)
		}
	}
	return out
}

const openCodeUsageQuery = "select id, directory, model, tokens_input, tokens_output, tokens_reasoning, tokens_cache_read, tokens_cache_write, time_created from session_v2 where tokens_input + tokens_output + tokens_cache_read > 0"

// ParseOpenCodeSessions reads the JSON rows of openCodeUsageQuery.
func ParseOpenCodeSessions(data []byte, town, source string) ([]UsageRecord, error) {
	var raw []map[string]any
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, err
	}
	var out []UsageRecord
	num := func(row map[string]any, key string) int64 {
		switch v := row[key].(type) {
		case float64:
			return int64(v)
		case string:
			n, _ := strconv.ParseInt(v, 10, 64)
			return n
		}
		return 0
	}
	str := func(row map[string]any, key string) string { s, _ := row[key].(string); return s }
	for _, row := range raw {
		model := str(row, "model")
		var parsed struct {
			ID         string `json:"id"`
			ProviderID string `json:"providerID"`
		}
		if json.Unmarshal([]byte(model), &parsed) == nil && parsed.ID != "" {
			model = parsed.ProviderID + "/" + parsed.ID
		}
		out = append(out, UsageRecord{Agent: "opencode", Session: str(row, "id"), Model: model, Role: RoleFromDir(town, str(row, "directory")),
			At: time.UnixMilli(num(row, "time_created")).UTC(), Input: num(row, "tokens_input"), Output: num(row, "tokens_output"),
			Reasoning: num(row, "tokens_reasoning"), Cached: num(row, "tokens_cache_read"), CacheWrite: num(row, "tokens_cache_write"), Source: source})
	}
	return out, nil
}

// CollectUsage reads every agent session stored in the shared agent home.
func (s *Swarm) CollectUsage() []UsageRecord {
	home := filepath.Join(s.Town(), ".agent-home")
	town := s.Town()
	var out []UsageRecord
	walk := func(root string, visit func(path string, f *os.File)) {
		_ = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
			if err != nil || d.IsDir() || !strings.HasSuffix(path, ".jsonl") {
				return nil
			}
			if f, openErr := os.Open(path); openErr == nil {
				defer f.Close()
				visit(path, f)
			}
			return nil
		})
	}
	walk(filepath.Join(home, ".codex", "sessions"), func(path string, f *os.File) {
		if rec, ok := ParseCodexRollout(f, town, filepath.Base(path)); ok {
			out = append(out, rec)
		}
	})
	walk(filepath.Join(home, ".claude", "projects"), func(path string, f *os.File) {
		out = append(out, ParseClaudeTranscript(f, town, filepath.Base(path))...)
	})
	db := filepath.Join(home, ".local", "share", "opencode", "opencode.db")
	if _, err := os.Stat(db); err == nil && s.R.Config.Sqlite != "" {
		res, err := s.R.Exec.Run(Command{Name: s.R.Config.Sqlite, Args: []string{"-readonly", "-json", db, openCodeUsageQuery}, Timeout: time.Minute})
		if err == nil && res.Exit == 0 && len(strings.TrimSpace(string(res.Stdout))) > 0 {
			if recs, parseErr := ParseOpenCodeSessions(res.Stdout, town, "opencode.db"); parseErr == nil {
				out = append(out, recs...)
			}
		}
	}
	return out
}

func (s *Swarm) ledgerPath() string { return filepath.Join(s.Dir(), "ledger.jsonl") }

// LoadLedger returns the persisted usage records.
func LoadLedger(path string) []UsageRecord {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	var out []UsageRecord
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 1<<20), 64<<20)
	for scanner.Scan() {
		var rec UsageRecord
		if json.Unmarshal(scanner.Bytes(), &rec) == nil {
			out = append(out, rec)
		}
	}
	return out
}

// MergeLedger replaces records by session and model, so a session that is
// still running updates its line instead of adding one, and keeps records of
// sessions whose files have since disappeared.
func MergeLedger(existing, fresh []UsageRecord) []UsageRecord {
	index := map[string]UsageRecord{}
	for _, rec := range existing {
		index[rec.key()] = rec
	}
	for _, rec := range fresh {
		if old, ok := index[rec.key()]; ok && rec.GoalAt.IsZero() {
			rec.GoalAt = old.GoalAt
		}
		index[rec.key()] = rec
	}
	out := make([]UsageRecord, 0, len(index))
	for _, rec := range index {
		out = append(out, rec)
	}
	sort.Slice(out, func(i, j int) bool {
		if !out[i].At.Equal(out[j].At) {
			return out[i].At.Before(out[j].At)
		}
		return out[i].key() < out[j].key()
	})
	return out
}

// UpdateLedger collects the current usage and rewrites ledger.jsonl.
func (s *Swarm) UpdateLedger(goalAt time.Time) []UsageRecord {
	fresh := s.CollectUsage()
	for i := range fresh {
		fresh[i].GoalAt = goalAt
	}
	merged := MergeLedger(LoadLedger(s.ledgerPath()), fresh)
	var buf strings.Builder
	for _, rec := range merged {
		line, _ := json.Marshal(rec)
		buf.Write(line)
		buf.WriteByte('\n')
	}
	tmp := s.ledgerPath() + ".tmp"
	if os.WriteFile(tmp, []byte(buf.String()), 0o600) == nil {
		_ = os.Rename(tmp, s.ledgerPath())
	}
	return merged
}

func humanTokens(n int64) string {
	switch {
	case n >= 1_000_000:
		return fmt.Sprintf("%.1fM", float64(n)/1e6)
	case n >= 10_000:
		return fmt.Sprintf("%dk", n/1000)
	}
	return strconv.FormatInt(n, 10)
}

// FormatUsage prints totals by role and model for the sessions that started
// at or after since (the zero time means every session).
func FormatUsage(recs []UsageRecord, since time.Time) string {
	type group struct{ role, agent, model string }
	totals := map[group]*UsageRecord{}
	var order []group
	for _, rec := range recs {
		if rec.At.Before(since) {
			continue
		}
		g := group{rec.Role, rec.Agent, rec.Model}
		t := totals[g]
		if t == nil {
			t = &UsageRecord{}
			totals[g] = t
			order = append(order, g)
		}
		t.Input += rec.Input
		t.Cached += rec.Cached
		t.CacheWrite += rec.CacheWrite
		t.Output += rec.Output
		t.Reasoning += rec.Reasoning
	}
	if len(order) == 0 {
		return "no token usage recorded"
	}
	sort.Slice(order, func(i, j int) bool { return order[i].role+order[i].model < order[j].role+order[j].model })
	var lines []string
	var all UsageRecord
	for _, g := range order {
		t := totals[g]
		lines = append(lines, fmt.Sprintf("%-9s %-8s %-40s input %s cached %s output %s reasoning %s", g.role, g.agent, g.model,
			humanTokens(t.Input), humanTokens(t.Cached), humanTokens(t.Output), humanTokens(t.Reasoning)))
		all.Input += t.Input
		all.Cached += t.Cached
		all.Output += t.Output
		all.Reasoning += t.Reasoning
	}
	lines = append(lines, fmt.Sprintf("%-59s input %s cached %s output %s reasoning %s", "total", humanTokens(all.Input), humanTokens(all.Cached),
		humanTokens(all.Output), humanTokens(all.Reasoning)))
	return strings.Join(lines, "\n")
}

// Usage prints the ledger totals; since is "goal" (current goal) or "all".
func (s *Swarm) Usage(since string) error {
	goalAt := s.loadState().GoalAt
	recs := s.UpdateLedger(goalAt)
	var from time.Time
	switch since {
	case "all":
	case "goal", "":
		from = goalAt
	default:
		return fmt.Errorf("--since must be goal or all, got %q", since)
	}
	fmt.Fprintln(s.Out, FormatUsage(recs, from))
	return nil
}
