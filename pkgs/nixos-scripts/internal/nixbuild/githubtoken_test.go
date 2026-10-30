package nixbuild

import (
	"errors"
	"strings"
	"testing"
)

func envOf(m map[string]string) func(string) string {
	return func(k string) string { return m[k] }
}

func TestGitHubAuthKeepsExistingToken(t *testing.T) {
	called := false
	got := GitHubAuthEnv(envOf(map[string]string{"GITHUB_TOKEN": "existing"}), func() (string, error) {
		called = true
		return "from-gh", nil
	})
	if called {
		t.Fatal("gh must not be asked when GITHUB_TOKEN is set")
	}
	if got["GITHUB_TOKEN"] != "" {
		t.Fatalf("existing token must not be overridden: %v", got)
	}
	if !strings.Contains(got["NIX_CONFIG"], "access-tokens = github.com=existing") {
		t.Fatalf("NIX_CONFIG = %q", got["NIX_CONFIG"])
	}
}

func TestGitHubAuthUsesGHCliWhenUnset(t *testing.T) {
	got := GitHubAuthEnv(envOf(nil), func() (string, error) { return "from-gh\n", nil })
	if got["GITHUB_TOKEN"] != "from-gh" {
		t.Fatalf("GITHUB_TOKEN = %q", got["GITHUB_TOKEN"])
	}
	if got["NIX_CONFIG"] != "access-tokens = github.com=from-gh" {
		t.Fatalf("NIX_CONFIG = %q", got["NIX_CONFIG"])
	}
}

func TestGitHubAuthAppendsToExistingNixConfig(t *testing.T) {
	got := GitHubAuthEnv(envOf(map[string]string{"NIX_CONFIG": "experimental-features = nix-command flakes"}), func() (string, error) {
		return "tok", nil
	})
	want := "experimental-features = nix-command flakes\naccess-tokens = github.com=tok"
	if got["NIX_CONFIG"] != want {
		t.Fatalf("NIX_CONFIG = %q, want %q", got["NIX_CONFIG"], want)
	}
}

func TestGitHubAuthSilentWithoutToken(t *testing.T) {
	for name, gh := range map[string]func() (string, error){
		"gh fails":  func() (string, error) { return "", errors.New("not logged in") },
		"gh empty":  func() (string, error) { return "  \n", nil },
		"gh absent": nil,
	} {
		t.Run(name, func(t *testing.T) {
			if got := GitHubAuthEnv(envOf(nil), gh); len(got) != 0 {
				t.Fatalf("no env expected, got %v", got)
			}
		})
	}
}
