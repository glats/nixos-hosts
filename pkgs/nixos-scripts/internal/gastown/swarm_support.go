package gastown

import (
	"encoding/json"
	"os"
	"os/exec"
	"regexp"
	"time"
)

var limitPattern = regexp.MustCompile(`(?i)hit your usage limit|usage limit (reached|exceeded)|rate.?limit(ed| exceeded| reached)|too many requests|\b429 |\b429\b[^.\d]|quota (exceeded|exhausted)|try again (in|at|later)`)

// LimitHit reports whether agent output shows a provider usage or rate limit.
func LimitHit(text string) bool { return limitPattern.MatchString(text) }

// PickAgent returns the first agent in the chain that is not cooling down. When
// every agent is cooling it returns the one that recovers first and false.
func PickAgent(chain []string, cooldowns map[string]time.Time, now time.Time) (string, bool) {
	var earliest string
	var earliestAt time.Time
	for _, name := range chain {
		until, cooling := cooldowns[name]
		if !cooling || !until.After(now) {
			return name, true
		}
		if earliest == "" || until.Before(earliestAt) {
			earliest, earliestAt = name, until
		}
	}
	return earliest, false
}

// NewItems returns the ids not seen before, in order, and records them.
func NewItems(seen map[string]bool, ids []string) []string {
	var fresh []string
	for _, id := range ids {
		if !seen[id] {
			seen[id] = true
			fresh = append(fresh, id)
		}
	}
	return fresh
}

type Notifier struct {
	LogPath string
	Cmd     string
}

// Notify always appends to the log and then runs the user's delivery command
// with the message in GASTOWN_NOTIFY_* variables.
func (n *Notifier) Notify(severity, title, body string) error {
	entry, _ := json.Marshal(map[string]string{"time": time.Now().UTC().Format(time.RFC3339), "severity": severity, "title": title, "body": body})
	if n.LogPath != "" {
		if f, err := os.OpenFile(n.LogPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600); err == nil {
			_, _ = f.Write(append(entry, '\n'))
			_ = f.Close()
		}
	}
	if n.Cmd == "" {
		return nil
	}
	cmd := exec.Command("/bin/sh", "-c", n.Cmd)
	cmd.Env = append(os.Environ(), "GASTOWN_NOTIFY_SEVERITY="+severity, "GASTOWN_NOTIFY_TITLE="+title, "GASTOWN_NOTIFY_BODY="+body)
	return cmd.Run()
}
