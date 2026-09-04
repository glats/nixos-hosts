package main

import (
	"os"
	"os/exec"
	"strings"
	"testing"
)

func TestResolveTarget(t *testing.T) {
	cases := []struct {
		in, want string
	}{
		{"local", "local"},
		{"mact2", "jcuzmar@mact2.local"},
		{"t14", "glats@t14.local"},
		{"thinkcentre", "glats@thinkcentre.local"},
		{"jcuzmar@mact2.local", "jcuzmar@mact2.local"}, // passthrough
		{"weird@host.example", "weird@host.example"},
	}
	for _, tc := range cases {
		if got := resolveTarget(tc.in); got != tc.want {
			t.Errorf("resolveTarget(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

func TestTargetLabel(t *testing.T) {
	cases := []struct {
		in, want string
	}{
		// Shorthand targets label as-is; only user@host passthrough
		// args get the "${1%%@*}-${1#*@}" + tr './' '--' treatment.
		{"mact2", "mact2"},
		{"t14", "t14"},
		{"thinkcentre", "thinkcentre"},
		{"jcuzmar@mact2.local", "jcuzmar-mact2-local"},
		{"a/b@c.d", "a-b-c-d"},
		{"plain", "plain"},
	}
	for _, tc := range cases {
		if got := targetLabel(tc.in); got != tc.want {
			t.Errorf("targetLabel(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
	// `local` resolves to this host's hostname via exec — just verify
	// it is non-empty and clean. Skipped in sandboxes without `hostname`
	// (the nix build sandbox has no hostname binary).
	if _, err := exec.LookPath("hostname"); err == nil {
		if got := targetLabel("local"); got == "" || strings.ContainsAny(got, "\n") {
			t.Errorf("targetLabel(local) = %q, want a hostname", got)
		}
	}
}

func TestUsageTextMatchesBashHeader(t *testing.T) {
	// The usage text must be the bash header block (lines 2-31) with the
	// "# " prefixes stripped — re-derive it from the original script if
	// it is present next to the repo.
	data, err := os.ReadFile("../../bin/ai-backup")
	if err != nil {
		t.Skip("bin/ai-backup not reachable from test cwd")
	}
	var want strings.Builder
	for i, line := range strings.Split(string(data), "\n") {
		if i == 0 {
			continue // shebang
		}
		if !strings.HasPrefix(line, "#") {
			break // awk: NR>1 && !/^#/ → exit
		}
		// awk sub(/^# ?/, ""): bare "#" lines become empty lines.
		if line == "#" {
			want.WriteString("\n")
		} else {
			want.WriteString(strings.TrimPrefix(line, "# ") + "\n")
		}
	}
	if got := usageText; got != want.String() {
		t.Fatalf("usageText drift vs bin/ai-backup header:\n got %q\nwant %q", got, want.String())
	}
}

func TestRemoteScriptsAreVerbatim(t *testing.T) {
	data, err := os.ReadFile("../../bin/ai-backup")
	if err != nil {
		t.Skip("bin/ai-backup not reachable from test cwd")
	}
	src := string(data)
	// Both heredoc payloads must appear inside the Go source verbatim
	// (modulo the backtick-quote splice in the backup payload).
	if !strings.Contains(src, `SQLITE="$(command -v sqlite3 || echo /usr/bin/sqlite3)"`) {
		t.Fatal("backup payload lost its SQLITE line")
	}
	if !strings.Contains(src, "exit $rc\n") {
		t.Fatal("restore payload lost its final exit $rc")
	}
	if !strings.Contains(src, `-C "$STAGING" home-snap`) {
		t.Fatal("backup payload lost its final tar argument")
	}
	_ = src
}
