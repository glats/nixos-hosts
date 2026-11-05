package gastown

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestLimitHitDetectsRealLimitsButNotTheCodexBanner(t *testing.T) {
	for _, hit := range []string{
		"You've hit your usage limit. Upgrade to Pro or try again at 3:04 PM.",
		"Error: rate limit exceeded for model", "429 Too Many Requests", "quota exhausted for this key",
		"Please try again later.",
	} {
		if !LimitHit(hit) {
			t.Errorf("missed limit: %q", hit)
		}
	}
	for _, fine := range []string{
		"• You have 1 usage limit reset available. Run /usage to use one.",
		"gpt-5.6-luna low · /tmp/town/mayor", "go test ./... ok 0.429s", "created 4290 files",
	} {
		if LimitHit(fine) {
			t.Errorf("false positive: %q", fine)
		}
	}
}

func TestPickAgentSkipsCoolingAgentsAndReportsExhaustion(t *testing.T) {
	now := time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC)
	chain := []string{"a", "b", "c"}
	if got, ok := PickAgent(chain, nil, now); !ok || got != "a" {
		t.Fatalf("first healthy agent expected, got %q %v", got, ok)
	}
	cool := map[string]time.Time{"a": now.Add(10 * time.Minute)}
	if got, ok := PickAgent(chain, cool, now); !ok || got != "b" {
		t.Fatalf("must skip a, got %q %v", got, ok)
	}
	cool["b"], cool["c"] = now.Add(5*time.Minute), now.Add(20*time.Minute)
	if got, ok := PickAgent(chain, cool, now); ok || got != "b" {
		t.Fatalf("all cooling: want earliest expiry b and ok=false, got %q %v", got, ok)
	}
	cool["a"] = now.Add(-time.Second)
	if got, ok := PickAgent(chain, cool, now); !ok || got != "a" {
		t.Fatalf("an expired cooldown must make the agent healthy again, got %q %v", got, ok)
	}
}

func TestNotifierLogsEveryMessageAndRunsTheUserCommand(t *testing.T) {
	dir := t.TempDir()
	out := filepath.Join(dir, "env.txt")
	n := &Notifier{LogPath: filepath.Join(dir, "n.jsonl"), Cmd: `printf '%s|%s|%s' "$GASTOWN_NOTIFY_SEVERITY" "$GASTOWN_NOTIFY_TITLE" "$GASTOWN_NOTIFY_BODY" > ` + out}
	if err := n.Notify("high", "needs you", "mayor asks: which license?"); err != nil {
		t.Fatal(err)
	}
	if got := readFile(t, out); got != "high|needs you|mayor asks: which license?" {
		t.Fatalf("command env wrong: %q", got)
	}
	if log := readFile(t, n.LogPath); !strings.Contains(log, `"title":"needs you"`) || strings.Count(log, "\n") != 1 {
		t.Fatalf("log wrong: %q", log)
	}
}

func TestNotifierSurvivesAFailingCommandAndStillLogs(t *testing.T) {
	n := &Notifier{LogPath: filepath.Join(t.TempDir(), "n.jsonl"), Cmd: "exit 3"}
	if err := n.Notify("low", "t", "b"); err == nil {
		t.Fatal("a failing user command must be reported")
	}
	if _, err := os.Stat(n.LogPath); err != nil {
		t.Fatal("the message must be logged even when delivery fails")
	}
}

func TestNewItemsReturnsOnlyUnseenIDsInOrder(t *testing.T) {
	seen := map[string]bool{"a": true}
	got := NewItems(seen, []string{"a", "b", "c", "b"})
	if strings.Join(got, ",") != "b,c" || !seen["b"] || !seen["c"] {
		t.Fatalf("got %v seen=%v", got, seen)
	}
}
