package gastown

import (
	"path/filepath"
	"strings"
	"testing"
)

func TestLoginCommandUsesTheAgentHomeAndOnlyForSubscriptionProviders(t *testing.T) {
	town := t.TempDir()
	cmd, err := loginCommand("/nix/opencode", town, "anthropic")
	if err != nil {
		t.Fatal(err)
	}
	if strings.Join(cmd.Args, " ") != "/nix/opencode auth login anthropic" {
		t.Fatalf("args = %v", cmd.Args)
	}
	home := filepath.Join(town, ".agent-home")
	last := ""
	for _, e := range cmd.Env {
		if strings.HasPrefix(e, "HOME=") {
			last = e
		}
	}
	if last != "HOME="+home {
		t.Fatalf("the agent must not use the real home: %q", last)
	}
	for _, provider := range []string{"nvidia", "ollama-cloud", "nope"} {
		if _, err := loginCommand("/nix/opencode", town, provider); err == nil {
			t.Errorf("accepted %q, which authenticates with a key", provider)
		}
	}
	if _, err := loginCommand("", town, "openai"); err == nil {
		t.Error("a missing opencode binary must be an error")
	}
}
