package gastown

import (
	"io/fs"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func testConfig() Config {
	return Config{
		Bash: "/nix/bash", GT: "/nix/gt", BD: "/nix/bd", Tmux: "/nix/tmux", Codex: "/nix/codex", Bwrap: "/nix/bwrap",
		ToolPath: "/nix/tools/bin", SystemPath: "/nix/sys/bin", NativeHome: "/home/u",
		State: "/state", DoltPort: 45678, Model: "gpt-5.6-luna", Effort: "low",
	}
}

func joined(args []string) string { return strings.Join(args, "\x00") }

func TestValidBeadID(t *testing.T) {
	for id, want := range map[string]bool{
		"ls-96n": true, "proj-a1b2": true, "": false, "ls-": false,
		"ls-96n; rm": false, "../x": false, "-x-1": false, "LS-1": false,
	} {
		if got := ValidBeadID(id); got != want {
			t.Errorf("ValidBeadID(%q)=%v want %v", id, got, want)
		}
	}
}

func TestValidBeacon(t *testing.T) {
	ws := "/state/town/app/crew/worker"
	good := "[GAS TOWN] crew worker (rig: app) <- human • 2026-11-04T10:00 • start"
	if !ValidBeacon([]string{good}, ws, ws, "app", "worker") {
		t.Fatal("valid beacon rejected")
	}
	cases := map[string]struct {
		argv []string
		cwd  string
	}{
		"extra arg":  {[]string{good, "x"}, ws},
		"no arg":     {nil, ws},
		"wrong cwd":  {[]string{good}, "/elsewhere"},
		"wrong rig":  {[]string{strings.Replace(good, "app", "other", 1)}, ws},
		"free text":  {[]string{"run rm -rf"}, ws},
		"wrong role": {[]string{strings.Replace(good, "crew", "mayor", 1)}, ws},
	}
	for name, c := range cases {
		if ValidBeacon(c.argv, c.cwd, ws, "app", "worker") {
			t.Errorf("%s: accepted", name)
		}
	}
}

func TestPolicyArgsConfinesExecutor(t *testing.T) {
	ws := "/state/town/app/crew/worker"
	text := joined(PolicyArgs(testConfig(), ws, "/state/runs/j1"))
	for _, want := range []string{
		`default_permissions="pilot"`, `approval_policy="never"`, `web_search="disabled"`,
		`network={enabled=false}`, `"` + ws + `"="write"`, `"` + ws + `/.git"="read"`,
		`"` + ws + `/.beads"="read"`, `"` + ws + `/.runtime"="read"`, `"/home"="deny"`, `"/tmp"="deny"`,
		`"/run/current-system"="read"`, `mcp_servers={}`, `"PATH"="/nix/tools/bin"`,
		`sqlite_home="/state/runs/j1/state"`, `features.use_linux_sandbox_bwrap=true`, `features.multi_agent=false`,
	} {
		if !strings.Contains(text, want) {
			t.Errorf("policy missing %s", want)
		}
	}
}

func TestCodexArgsPinModelAndAuth(t *testing.T) {
	args := CodexArgs(testConfig(), "/ws", "/job", "PROMPT")
	text := joined(args)
	for _, want := range []string{"exec", "--ignore-user-config", "--ephemeral", "--json", "gpt-5.6-luna",
		`model_provider="openai"`, `forced_login_method="chatgpt"`, `model_reasoning_effort="low"`} {
		if !strings.Contains(text, want) {
			t.Errorf("codex args missing %s", want)
		}
	}
	if args[len(args)-1] != "PROMPT" {
		t.Fatal("prompt must be the final argument")
	}
}

func TestCoordinatorEnvExcludesNativeHome(t *testing.T) {
	env := CoordinatorEnv(testConfig(), "/state/town", "app", "worker")
	for _, e := range env {
		if strings.Contains(e, "/home/u") {
			t.Fatalf("native home leaked into coordinator env: %s", e)
		}
	}
	text := strings.Join(env, "\n")
	for _, want := range []string{"GT_ROOT=/state/town", "GT_RIG=app", "GT_CREW=worker", "BD_ACTOR=app/crew/worker",
		"GT_DOLT_PORT=45678", "BD_NO_PUSH=true", "HOME=/state/home"} {
		if !strings.Contains(text, want) {
			t.Errorf("env missing %s", want)
		}
	}
}

func TestInspectStream(t *testing.T) {
	stream := `{"type":"item.completed","item":{"id":"1","type":"command_execution","exit_code":0}}
not json
{"type":"item.completed","item":{"id":"2","type":"command_execution","exit_code":1}}
{"type":"turn.completed","usage":{"input_tokens":5}}`
	got := InspectStream([]byte(stream))
	if got.Commands != 2 || got.Forbidden || !got.TurnCompleted {
		t.Fatalf("unexpected inspection: %+v", got)
	}
	forbidden := InspectStream([]byte(`{"type":"item.started","item":{"id":"9","type":"web_search"}}`))
	if !forbidden.Forbidden {
		t.Fatal("web_search must be forbidden")
	}
}

func TestTaskPromptBindsExecutorRules(t *testing.T) {
	prompt := TaskPrompt(testConfig(), "add a flag", []string{"go test ./...", "go vet ./..."})
	for _, want := range []string{"add a flag", "go test ./...", "go vet ./...", `"shell": "/nix/bash"`, `"login": false`,
		"Do not run gt or bd", "Do not commit"} {
		if !strings.Contains(prompt, want) {
			t.Errorf("prompt missing %q", want)
		}
	}
}

func TestConfigFromEnv(t *testing.T) {
	env := map[string]string{"GASTOWN_GT": "/g", "GASTOWN_BD": "/b", "GASTOWN_TMUX": "/t", "GASTOWN_CODEX": "/c",
		"GASTOWN_BWRAP": "/w", "GASTOWN_BASH": "/sh", "GASTOWN_TOOL_PATH": "/tp", "GASTOWN_SYSTEM_PATH": "/sp",
		"HOME": "/home/u", "XDG_STATE_HOME": "/xdg"}
	c, err := ConfigFromEnv(func(k string) string { return env[k] })
	if err != nil || c.State != "/xdg/gastown" || c.DoltPort != 45678 || c.Model != "gpt-5.6-luna" || c.Effort != "low" || c.NativeHome != "/home/u" {
		t.Fatalf("unexpected config: %+v err=%v", c, err)
	}
	delete(env, "GASTOWN_CODEX")
	if _, err := ConfigFromEnv(func(k string) string { return env[k] }); err == nil {
		t.Fatal("missing executable must be an error")
	}
}

func TestLoadTasksRejectsIncompleteTasks(t *testing.T) {
	if _, err := ParseTasks([]byte(`[{"title":"a","prompt":"b","checks":["true"]}]`)); err != nil {
		t.Fatal(err)
	}
	for _, bad := range []string{`[]`, `[{"title":"","prompt":"b","checks":["true"]}]`, `[{"title":"a","prompt":"b","checks":[]}]`, `not json`} {
		if _, err := ParseTasks([]byte(bad)); err == nil {
			t.Errorf("accepted %s", bad)
		}
	}
}

func gitIn(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-c", "user.name=t", "-c", "user.email=t@l"}, args...)...)
	cmd.Dir = dir
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
	return string(out)
}

func TestExcludeInfraKeepsToolFilesOutOfCommits(t *testing.T) {
	dir := t.TempDir()
	gitIn(t, dir, "init", "-q", "-b", "main")
	if err := os.WriteFile(filepath.Join(dir, "main.go"), []byte("package main\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	gitIn(t, dir, "add", "-A")
	gitIn(t, dir, "commit", "-q", "-m", "init")
	_ = os.MkdirAll(filepath.Join(dir, ".beads"), 0o700)
	_ = os.WriteFile(filepath.Join(dir, ".beads", "x"), []byte("x"), 0o600)
	_ = os.WriteFile(filepath.Join(dir, ".gitignore"), []byte(".logs/\n"), 0o600)
	if strings.TrimSpace(gitIn(t, dir, "status", "--porcelain")) == "" {
		t.Fatal("precondition: tool files should be untracked")
	}
	if err := ExcludeInfra(dir); err != nil {
		t.Fatal(err)
	}
	if got := strings.TrimSpace(gitIn(t, dir, "status", "--porcelain")); got != "" {
		t.Fatalf("workspace should be clean, got %q", got)
	}
	if err := os.WriteFile(filepath.Join(dir, "main.go"), []byte("package main\n// edit\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if got := gitIn(t, dir, "status", "--porcelain"); !strings.Contains(got, "main.go") {
		t.Fatalf("real edits must stay visible, got %q", got)
	}
}

func TestExcludeInfraDoesNotHideTrackedGitignore(t *testing.T) {
	dir := t.TempDir()
	gitIn(t, dir, "init", "-q", "-b", "main")
	_ = os.WriteFile(filepath.Join(dir, ".gitignore"), []byte("bin/\n"), 0o600)
	gitIn(t, dir, "add", "-A")
	gitIn(t, dir, "commit", "-q", "-m", "init")
	if err := ExcludeInfra(dir); err != nil {
		t.Fatal(err)
	}
	_ = os.WriteFile(filepath.Join(dir, ".gitignore"), []byte("bin/\nobj/\n"), 0o600)
	if got := gitIn(t, dir, "status", "--porcelain"); !strings.Contains(got, ".gitignore") {
		t.Fatalf("a tracked .gitignore edit must stay visible, got %q", got)
	}
}

func TestEvaluateProbeAcceptsOnlyTheExpectedBoundary(t *testing.T) {
	good := "write_workspace=allowed\nwrite_git=denied\nwrite_beads=denied\nread_outside=denied\nwrite_outside=denied\nlist_home=denied\nnetwork=denied\n"
	if err := EvaluateProbe(good); err != nil {
		t.Fatalf("expected boundary rejected: %v", err)
	}
	for name, mutate := range map[string]func(string) string{
		"git writable":      func(s string) string { return strings.Replace(s, "write_git=denied", "write_git=allowed", 1) },
		"outside readable":  func(s string) string { return strings.Replace(s, "read_outside=denied", "read_outside=allowed", 1) },
		"network reachable": func(s string) string { return strings.Replace(s, "network=denied", "network=allowed", 1) },
		"workspace blocked": func(s string) string {
			return strings.Replace(s, "write_workspace=allowed", "write_workspace=denied", 1)
		},
		"probe missing": func(s string) string { return strings.Replace(s, "network=denied\n", "", 1) },
		"empty":         func(string) string { return "" },
	} {
		if EvaluateProbe(mutate(good)) == nil {
			t.Errorf("%s: accepted", name)
		}
	}
}

func TestProbeScriptTargetsCanaryAndPort(t *testing.T) {
	script := ProbeScript("/state/doctor/canary", 45678)
	for _, want := range []string{"/state/doctor/canary", "45678", "write_git", "network"} {
		if !strings.Contains(script, want) {
			t.Errorf("script missing %q", want)
		}
	}
}

func TestProbeScriptSeesThroughAnUnconfinedProcess(t *testing.T) {
	bash, err := exec.LookPath("bash")
	if err != nil {
		t.Skip("bash unavailable")
	}
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Skip("loopback unavailable")
	}
	defer listener.Close()
	dir := t.TempDir()
	gitIn(t, dir, "init", "-q", "-b", "main")
	_ = os.MkdirAll(filepath.Join(dir, ".beads"), 0o700)
	_ = os.WriteFile(filepath.Join(dir, ".beads", "keep"), []byte("keep\n"), 0o600)
	canaryDir := t.TempDir()
	canary := filepath.Join(canaryDir, "canary")
	_ = os.WriteFile(canary, []byte("c\n"), 0o600)
	before := snapshotTree(t, dir) + snapshotTree(t, canaryDir)
	cmd := exec.Command(bash, "-c", ProbeScript(canary, listener.Addr().(*net.TCPAddr).Port))
	cmd.Dir = dir
	out, _ := cmd.Output()
	if after := snapshotTree(t, dir) + snapshotTree(t, canaryDir); after != before {
		t.Fatalf("probes must not modify the worker, task metadata or canary:\nbefore:\n%s\nafter:\n%s", before, after)
	}
	for _, name := range []string{"write_workspace", "write_git", "write_beads", "read_outside", "write_outside", "network"} {
		if !strings.Contains(string(out), name+"=allowed") {
			t.Errorf("an unconfined process must be seen as allowed for %s; output:\n%s", name, out)
		}
	}
	if EvaluateProbe(string(out)) == nil {
		t.Fatal("an unconfined process must fail the boundary evaluation")
	}
}

func snapshotTree(t *testing.T, root string) string {
	t.Helper()
	var b strings.Builder
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(root, path)
		if d.IsDir() {
			b.WriteString("dir " + rel + "\n")
			return nil
		}
		data, readErr := os.ReadFile(path)
		if readErr != nil {
			return readErr
		}
		b.WriteString("file " + rel + " " + string(data) + "\n")
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return b.String()
}

func TestValidNameRejectsDigitsThatGasTownCannotUseInBeadIDs(t *testing.T) {
	for name, want := range map[string]bool{"demo": true, "my-app": true, "jd1": false, "app2": false, "9x": false, "": false, "Up": false, "../x": false} {
		if got := ValidName(name); got != want {
			t.Errorf("ValidName(%q)=%v want %v", name, got, want)
		}
	}
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func mkdirAll(path string) error { return os.MkdirAll(path, 0o700) }
