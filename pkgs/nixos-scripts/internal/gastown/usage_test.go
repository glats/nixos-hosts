package gastown

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

const codexRollout = `{"timestamp":"2026-11-10T23:35:42.100Z","type":"session_meta","payload":{"id":"cx-1","cwd":"/state/town/mayor"}}
{"timestamp":"2026-11-10T23:35:43.000Z","type":"turn_context","payload":{"model":"gpt-5.6-luna"}}
{"timestamp":"2026-11-10T23:35:50.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":400,"output_tokens":50,"reasoning_output_tokens":10}}}}
{"timestamp":"2026-11-10T23:36:50.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":26373,"cached_input_tokens":12928,"output_tokens":119,"reasoning_output_tokens":13}}}}
{"timestamp":"2026-11-10T23:36:51.000Z","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{}}}
`

const claudeTranscript = `{"type":"queue-operation","sessionId":"cl-1","timestamp":"2026-11-10T20:59:59.000Z"}
{"type":"user","sessionId":"cl-1","cwd":"/state/town/toy/polecats/nux/toy","timestamp":"2026-11-10T21:00:00.000Z","message":{"role":"user"}}
{"type":"assistant","sessionId":"cl-1","message":{"id":"m1","model":"claude-sonnet-5-5","usage":{"input_tokens":10,"output_tokens":5,"cache_creation_input_tokens":100,"cache_read_input_tokens":200}}}
{"type":"assistant","sessionId":"cl-1","message":{"id":"m1","model":"claude-sonnet-5-5","usage":{"input_tokens":10,"output_tokens":7,"cache_creation_input_tokens":100,"cache_read_input_tokens":200}}}
{"type":"assistant","sessionId":"cl-1","message":{"id":"m2","model":"claude-sonnet-5-5","usage":{"input_tokens":20,"output_tokens":30,"cache_creation_input_tokens":0,"cache_read_input_tokens":300}}}
{"type":"assistant","sessionId":"cl-1","message":{"id":"m3","model":"<synthetic>","usage":{"input_tokens":0,"output_tokens":0}}}
{"type":"assistant","sessionId":"cl-1","message":{"id":"m4","model":"claude-haiku-4-5","usage":{"input_tokens":1,"output_tokens":2}}}
`

func TestParseCodexRolloutTakesTheLastCumulativeTotalAndSplitsCachedInput(t *testing.T) {
	rec, ok := ParseCodexRollout(strings.NewReader(codexRollout), "/state/town", "rollout.jsonl")
	if !ok || rec.Session != "cx-1" || rec.Model != "gpt-5.6-luna" || rec.Role != "mayor" || rec.Agent != "codex" {
		t.Fatalf("record = %+v ok=%v", rec, ok)
	}
	if rec.Input != 26373-12928 || rec.Cached != 12928 || rec.Output != 119 || rec.Reasoning != 13 {
		t.Fatalf("tokens = %+v", rec)
	}
	if rec.At.IsZero() {
		t.Fatal("the session start time is needed for --since")
	}
	if _, ok := ParseCodexRollout(strings.NewReader(`{"type":"session_meta","payload":{"id":"x","cwd":"/state/town/mayor"}}`+"\n"), "/state/town", "r"); ok {
		t.Fatal("a session without usage must not produce a record")
	}
}

func TestParseClaudeTranscriptCountsEachMessageOnceAndSkipsSynthetic(t *testing.T) {
	recs := ParseClaudeTranscript(strings.NewReader(claudeTranscript), "/state/town", "cl.jsonl")
	if len(recs) != 2 {
		t.Fatalf("want one record per model, got %+v", recs)
	}
	sonnet, haiku := recs[0], recs[1]
	if sonnet.Model != "claude-sonnet-5-5" || sonnet.Role != "polecat" || sonnet.Session != "cl-1" {
		t.Fatalf("sonnet = %+v", sonnet)
	}
	if sonnet.Input != 30 || sonnet.Output != 37 || sonnet.Cached != 500 || sonnet.CacheWrite != 100 {
		t.Fatalf("m1 counts once with its last usage, m2 once: %+v", sonnet)
	}
	if haiku.Model != "claude-haiku-4-5" || haiku.Input != 1 || haiku.Output != 2 {
		t.Fatalf("haiku = %+v", haiku)
	}
}

func TestParseOpenCodeSessionsReadsSqliteJSONRows(t *testing.T) {
	data := `[{"id":"ses_1","directory":"/state/town/mayor","model":"{\"id\":\"glm-5.3\",\"providerID\":\"ollama-cloud\"}","tokens_input":67365,"tokens_output":17959,"tokens_reasoning":0,"tokens_cache_read":1701120,"tokens_cache_write":0,"time_created":1794355332538}]`
	recs, err := ParseOpenCodeSessions([]byte(data), "/state/town", "opencode.db")
	if err != nil || len(recs) != 1 {
		t.Fatalf("recs=%+v err=%v", recs, err)
	}
	r := recs[0]
	if r.Agent != "opencode" || r.Model != "ollama-cloud/glm-5.3" || r.Role != "mayor" || r.Input != 67365 || r.Cached != 1701120 || r.Output != 17959 {
		t.Fatalf("record = %+v", r)
	}
	if !r.At.Equal(time.UnixMilli(1794355332538)) {
		t.Fatalf("at = %v", r.At)
	}
	if _, err := ParseOpenCodeSessions([]byte("not json"), "/t", "x"); err == nil {
		t.Fatal("bad rows must be an error")
	}
}

func TestRoleFromDirNamesTheGasTownRole(t *testing.T) {
	for dir, want := range map[string]string{
		"/t/mayor": "mayor", "/t/rig/polecats/nux/rig": "polecat", "/t/rig/witness": "witness", "/t/rig/refinery/rig": "refinery",
		"/t/deacon": "deacon", "/t/rig/crew/a": "crew", "/t/other": "other", "/elsewhere/mayor": "other",
	} {
		if got := RoleFromDir("/t", dir); got != want {
			t.Errorf("%s = %s, want %s", dir, got, want)
		}
	}
}

func TestMergeLedgerUpdatesRunningSessionsAndKeepsVanishedOnes(t *testing.T) {
	at := time.Date(2026, 11, 10, 1, 0, 0, 0, time.UTC)
	old := []UsageRecord{{Agent: "codex", Session: "a", Model: "m", Output: 5, At: at}, {Agent: "claude", Session: "gone", Model: "m", Output: 9, At: at.Add(time.Minute)}}
	got := MergeLedger(old, []UsageRecord{{Agent: "codex", Session: "a", Model: "m", Output: 8, At: at}})
	if len(got) != 2 || got[0].Output != 8 || got[1].Session != "gone" {
		t.Fatalf("merged = %+v", got)
	}
}

func TestFormatUsageTotalsByRoleAndModelSinceTheGoal(t *testing.T) {
	goal := time.Date(2026, 11, 10, 12, 0, 0, 0, time.UTC)
	recs := []UsageRecord{
		{Agent: "codex", Role: "mayor", Model: "gpt", Input: 100, Output: 10, At: goal.Add(-time.Hour)},
		{Agent: "opencode", Role: "polecat", Model: "ollama-cloud/glm", Input: 2000, Cached: 1_500_000, Output: 300, At: goal.Add(time.Minute)},
		{Agent: "opencode", Role: "polecat", Model: "ollama-cloud/glm", Input: 1000, Output: 200, At: goal.Add(time.Hour)},
	}
	text := FormatUsage(recs, goal)
	for _, want := range []string{"polecat", "ollama-cloud/glm", "input 3000", "cached 1.5M", "output 500", "total"} {
		if !strings.Contains(text, want) {
			t.Errorf("missing %q in\n%s", want, text)
		}
	}
	if strings.Contains(text, "gpt") {
		t.Errorf("sessions before the goal must be excluded:\n%s", text)
	}
	if !strings.Contains(FormatUsage(recs, time.Time{}), "gpt") {
		t.Error("the zero time includes every session")
	}
	if FormatUsage(nil, time.Time{}) != "no token usage recorded" {
		t.Error("empty ledger message")
	}
}

func TestCollectUsageReadsEveryAgentHomeSourceAndTheLedgerIsStable(t *testing.T) {
	f := &swarmFake{}
	sqlite := ""
	exec := func(c Command) (Result, error) {
		if c.Name == "/nix/sqlite" {
			sqlite = strings.Join(c.Args, " ")
			return Result{Stdout: []byte(`[{"id":"ses_1","directory":"` + "TOWN" + `/mayor","model":"{\"id\":\"glm-5.3\",\"providerID\":\"ollama-cloud\"}","tokens_input":10,"tokens_output":5,"tokens_reasoning":0,"tokens_cache_read":20,"tokens_cache_write":0,"time_created":1794355332538}]`)}, nil
		}
		return f.exec(c)
	}
	s := newSwarm(t, f, "codex:m:low")
	s.R.Exec = fnExec(exec)
	s.R.Config.Sqlite = "/nix/sqlite"
	home := filepath.Join(s.Town(), ".agent-home")
	for path, body := range map[string]string{
		filepath.Join(home, ".codex", "sessions", "2026", "11", "10", "rollout.jsonl"): strings.ReplaceAll(codexRollout, "/state/town", s.Town()),
		filepath.Join(home, ".claude", "projects", "-x", "cl.jsonl"):                   strings.ReplaceAll(claudeTranscript, "/state/town", s.Town()),
		filepath.Join(home, ".local", "share", "opencode", "opencode.db"):              "db",
	} {
		if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	first := s.UpdateLedger(time.Date(2026, 11, 10, 20, 0, 0, 0, time.UTC))
	second := s.UpdateLedger(time.Date(2026, 11, 10, 20, 0, 0, 0, time.UTC))
	if len(first) != 4 || len(second) != 4 {
		t.Fatalf("codex + 2 claude models + opencode = 4 records, got %d then %d", len(first), len(second))
	}
	if !strings.Contains(sqlite, "-readonly") || !strings.Contains(sqlite, "-json") || !strings.Contains(sqlite, "session_v2") {
		t.Errorf("sqlite call = %q", sqlite)
	}
	if len(LoadLedger(s.ledgerPath())) != 4 {
		t.Fatal("the ledger file must hold the same records")
	}
}

func TestSwarmFinishedNotificationCarriesTheTokenTotals(t *testing.T) {
	f := &swarmFake{esc: `[]`, mail: `[]`, polecats: `[]`}
	s := newSwarm(t, f, "codex:m:low")
	home := filepath.Join(s.Town(), ".agent-home", ".codex", "sessions")
	if err := os.MkdirAll(home, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, "r.jsonl"), []byte(strings.ReplaceAll(codexRollout, "/state/town", s.Town())), 0o600); err != nil {
		t.Fatal(err)
	}
	s.finishNotice(&WatchState{})
	var body string
	for _, n := range notifications(t, s) {
		if n["title"] == "Swarm finished" {
			body = n["body"]
		}
	}
	if !strings.Contains(body, "tokens:") || !strings.Contains(body, "gpt-5.6-luna") {
		t.Fatalf("finish notice must carry the totals: %q", body)
	}
}
