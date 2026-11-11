package gastown

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func confineSpec() ConfineSpec {
	return ConfineSpec{
		Root: "/state/swarm/town", Cwd: "/state/swarm/town/app/polecats/a/app", Home: "/state/swarm/town/.agent-home",
		RealHome: "/home/u", Bwrap: "/nix/bwrap", Path: "/nix/tools/bin:/nix/gt/bin",
		HomeBinds: []string{".codex"}, AllowEnv: []string{"NVIDIA_API_KEY"},
		Command: []string{"/nix/codex/bin/codex", "--flag"},
	}
}

func argvText(t *testing.T, s ConfineSpec, environ []string) string {
	t.Helper()
	argv, err := ConfineArgv(s, environ)
	if err != nil {
		t.Fatal(err)
	}
	return strings.Join(argv, "\x00")
}

func TestConfineBindsOnlyTheTownAndSelectedHomeEntries(t *testing.T) {
	text := argvText(t, confineSpec(), nil)
	for _, want := range []string{
		"/nix/bwrap", "--unshare-all", "--share-net", "--die-with-parent",
		"--bind\x00/state/swarm/town\x00/state/swarm/town",
		"--bind\x00/home/u/.codex\x00/state/swarm/town/.agent-home/.codex",
		"--ro-bind\x00/nix/store\x00/nix/store",
		"--chdir\x00/state/swarm/town/app/polecats/a/app",
		"--setenv\x00HOME\x00/state/swarm/town/.agent-home", "--setenv\x00PATH\x00/nix/tools/bin:/nix/gt/bin",
		"--\x00/nix/codex/bin/codex\x00--flag",
	} {
		if !strings.Contains(text, want) {
			t.Errorf("argv missing %q", strings.ReplaceAll(want, "\x00", " "))
		}
	}
	for _, forbidden := range []string{"\x00/home/u\x00/home/u", "/home/u/.ssh", "/home/u/.gnupg", "--new-session"} {
		if strings.Contains(text, forbidden) {
			t.Errorf("argv must not contain %q", strings.ReplaceAll(forbidden, "\x00", " "))
		}
	}
}

func TestConfineEnvironmentIsAllowlisted(t *testing.T) {
	environ := []string{"GT_ROOT=/state/swarm/town", "BD_ACTOR=app/polecat/a", "BEADS_DOLT_PORT=1", "GIT_AUTHOR_NAME=a",
		"NVIDIA_API_KEY=secret", "AWS_SECRET_ACCESS_KEY=leak", "SSH_AUTH_SOCK=/run/agent", "GITHUB_TOKEN=leak", "HOME=/home/u", "PATH=/usr/bin"}
	text := argvText(t, confineSpec(), environ)
	for _, want := range []string{"GT_ROOT", "BD_ACTOR", "BEADS_DOLT_PORT", "GIT_AUTHOR_NAME", "NVIDIA_API_KEY"} {
		if !strings.Contains(text, "--setenv\x00"+want+"\x00") {
			t.Errorf("%s must pass through", want)
		}
	}
	for _, leak := range []string{"AWS_SECRET_ACCESS_KEY", "SSH_AUTH_SOCK", "GITHUB_TOKEN", "/home/u\x00--"} {
		if strings.Contains(text, leak) {
			t.Errorf("%s must not reach the agent", leak)
		}
	}
	if strings.Contains(text, "--setenv\x00PATH\x00/usr/bin") || !strings.Contains(text, "--setenv\x00HOME\x00/state/swarm/town/.agent-home") {
		t.Error("PATH and HOME must come from the spec, not the caller")
	}
}

func TestConfineRefusesUnsafeSpecs(t *testing.T) {
	cases := map[string]func(*ConfineSpec){
		"cwd outside root":  func(s *ConfineSpec) { s.Cwd = "/home/u/code" },
		"cwd traversal":     func(s *ConfineSpec) { s.Cwd = "/state/swarm/town/../../etc" },
		"home outside root": func(s *ConfineSpec) { s.Home = "/home/u" },
		"ssh bind":          func(s *ConfineSpec) { s.HomeBinds = []string{".ssh"} },
		"gnupg bind":        func(s *ConfineSpec) { s.HomeBinds = []string{".gnupg"} },
		"nested secret":     func(s *ConfineSpec) { s.HomeBinds = []string{".config/sops/age"} },
		"absolute bind":     func(s *ConfineSpec) { s.HomeBinds = []string{"/home/u/.ssh"} },
		"dotdot bind":       func(s *ConfineSpec) { s.HomeBinds = []string{"../.ssh"} },
		"relative extra rw": func(s *ConfineSpec) { s.RW = []string{"data"} },
		"no command":        func(s *ConfineSpec) { s.Command = nil },
		"root is home":      func(s *ConfineSpec) { s.Root = "/home/u"; s.Cwd = "/home/u/x"; s.Home = "/home/u/h" },
	}
	for name, mutate := range cases {
		s := confineSpec()
		mutate(&s)
		if _, err := ConfineArgv(s, nil); err == nil {
			t.Errorf("%s: accepted", name)
		}
	}
}

func TestTrustProjectIsIdempotentAndPreservesExistingConfig(t *testing.T) {
	path := t.TempDir() + "/.codex/config.toml"
	if err := TrustProject(path, "/town/app/polecats/a/app"); err != nil {
		t.Fatal(err)
	}
	if err := TrustProject(path, "/town/app/polecats/a/app"); err != nil {
		t.Fatal(err)
	}
	if err := TrustProject(path, "/town"); err != nil {
		t.Fatal(err)
	}
	data := readFile(t, path)
	if strings.Count(data, `[projects."/town/app/polecats/a/app"]`) != 1 || strings.Count(data, `[projects."/town"]`) != 1 || strings.Count(data, `trust_level = "trusted"`) != 2 {
		t.Fatalf("unexpected config:\n%s", data)
	}
}

func TestTrustProjectRejectsPathsThatCouldBreakTheTOMLTable(t *testing.T) {
	path := t.TempDir() + "/config.toml"
	for _, bad := range []string{`/town/"x`, "/town/\nx", "relative/path", ""} {
		if err := TrustProject(path, bad); err == nil {
			t.Errorf("accepted %q", bad)
		}
	}
}

func TestGitRootFindsTheNearestRepositoryOrFallsBack(t *testing.T) {
	dir := t.TempDir()
	gitIn(t, dir, "init", "-q", "-b", "main")
	sub := dir + "/a/b"
	if err := mkdirAll(sub); err != nil {
		t.Fatal(err)
	}
	if got := GitRoot(sub); got != dir {
		t.Fatalf("GitRoot=%q want %q", got, dir)
	}
	other := t.TempDir()
	if got := GitRoot(other); got != other {
		t.Fatalf("outside a repository GitRoot must fall back to the directory itself, got %q", got)
	}
}

func TestConfineAllowsBindingASingleCredentialFile(t *testing.T) {
	s := confineSpec()
	s.HomeBinds = []string{".codex/auth.json"}
	text := argvText(t, s, nil)
	if !strings.Contains(text, "--bind\x00/home/u/.codex/auth.json\x00/state/swarm/town/.agent-home/.codex/auth.json") {
		t.Fatal("single-file bind missing")
	}
}

func TestPrepareClaudePreAnswersFirstRunDialogsAndKeepsExistingSettings(t *testing.T) {
	home := t.TempDir()
	if err := os.WriteFile(filepath.Join(home, ".claude.json"), []byte(`{"userID":"keep","projects":{"/other":{"x":1}}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 2; i++ {
		if err := PrepareClaude(home, "/town/rig"); err != nil {
			t.Fatal(err)
		}
	}
	var state map[string]any
	data, _ := os.ReadFile(filepath.Join(home, ".claude.json"))
	if err := json.Unmarshal(data, &state); err != nil {
		t.Fatal(err)
	}
	projects := state["projects"].(map[string]any)
	if state["hasCompletedOnboarding"] != true || state["userID"] != "keep" || projects["/other"] == nil ||
		projects["/town/rig"].(map[string]any)["hasTrustDialogAccepted"] != true {
		t.Fatalf("state not prepared: %s", data)
	}
	var settings map[string]any
	data, _ = os.ReadFile(filepath.Join(home, ".claude", "settings.json"))
	_ = json.Unmarshal(data, &settings)
	if settings["skipDangerousModePermissionPrompt"] != true || settings["theme"] != "dark" {
		t.Fatalf("settings not prepared: %s", data)
	}
	if err := PrepareClaude(home, "relative"); err == nil {
		t.Fatal("a relative project path must be refused")
	}
}

func TestConfineMountsReadOnlyFilesIntoTheAgentHome(t *testing.T) {
	s := confineSpec()
	s.RoFiles = []string{"/nix/store/x-gastown-run/share/gastown/polecat-odd.md=.codex/AGENTS.md"}
	argv, err := ConfineArgv(s, nil)
	if err != nil {
		t.Fatal(err)
	}
	text := strings.Join(argv, "\x00")
	want := "--ro-bind\x00/nix/store/x-gastown-run/share/gastown/polecat-odd.md\x00" + filepath.Join(s.Home, ".codex/AGENTS.md")
	if !strings.Contains(text, want) {
		t.Fatalf("missing read-only file mount in %q", strings.ReplaceAll(text, "\x00", " "))
	}
	for _, bad := range []string{"x=../escape", "x=/abs/path", "=.codex/AGENTS.md", "no-separator", "/etc/passwd=.codex/AGENTS.md", "/nix/store/x=."} {
		s.RoFiles = []string{bad}
		if _, err := ConfineArgv(s, nil); err == nil {
			t.Errorf("%q must be refused", bad)
		}
	}
}
