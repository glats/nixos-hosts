package gastown

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type fnExec func(Command) (Result, error)

func (f fnExec) Run(c Command) (Result, error) { return f(c) }

type swarmFake struct {
	esc, mail, polecats, peek string
	calls                     []string
}

func (f *swarmFake) exec(c Command) (Result, error) {
	key := filepath.Base(c.Name) + " " + strings.Join(c.Args, " ")
	f.calls = append(f.calls, key)
	out := func(s string) (Result, error) { return Result{Stdout: []byte(s)}, nil }
	switch {
	case strings.HasPrefix(key, "gt escalate list"):
		return out(f.esc)
	case strings.HasPrefix(key, "gt mail inbox"):
		return out(f.mail)
	case strings.HasPrefix(key, "gt polecat list"):
		return out(f.polecats)
	case strings.HasPrefix(key, "gt peek"):
		return out(f.peek)
	}
	return out("")
}

func newSwarm(t *testing.T, f *swarmFake, chain ...string) *Swarm {
	t.Helper()
	state := t.TempDir()
	c := testConfig()
	c.State = state
	s := &Swarm{R: &Runner{Config: c, Exec: fnExec(f.exec)}, Self: "/nix/gastown-run", Out: io.Discard,
		Cfg: SwarmConfig{Project: "toy", Checks: []string{"true"}, Chains: map[string][]string{"polecat": chain, "mayor": {chain[0]}}, DoltPort: 45900, MaxPolecats: 2}}
	if err := os.MkdirAll(filepath.Join(s.Town(), "settings"), 0o700); err != nil {
		t.Fatal(err)
	}
	return s
}

func notifications(t *testing.T, s *Swarm) []map[string]string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(s.Dir(), "notifications.jsonl"))
	if err != nil {
		return nil
	}
	var out []map[string]string
	for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
		var m map[string]string
		if json.Unmarshal([]byte(line), &m) == nil {
			out = append(out, m)
		}
	}
	return out
}

func TestTickNotifiesNewEscalationsOnceAndDetectsCompletion(t *testing.T) {
	f := &swarmFake{esc: `[{"id":"hq-1","title":"[HIGH] license?","description":"which license","status":"open"},` +
		`{"id":"hq-2","title":"[LOW] goal complete","description":"all done","status":"open"},{"id":"hq-3","title":"old","status":"closed"}]`,
		mail: `[]`, polecats: `[]`}
	s := newSwarm(t, f, "codex:m1:low")
	s.saveState(&WatchState{Gated: map[string]GateResult{"toy-1@abc": {Status: "pass", At: time.Now()}}})
	st := s.Tick(time.Now())
	got := notifications(t, s)
	if len(got) != 2 || got[0]["severity"] != "high" || !strings.Contains(got[0]["title"], "license?") || got[1]["title"] != "Goal complete" || !st.Complete {
		t.Fatalf("unexpected notifications: %v complete=%v", got, st.Complete)
	}
	s.Tick(time.Now())
	if again := notifications(t, s); len(again) != 2 {
		t.Fatalf("an escalation must be announced once, got %d", len(again))
	}
}

func TestTickSurfacesUnreadMayorMailOnceAndIgnoresReadMail(t *testing.T) {
	f := &swarmFake{esc: `[]`, polecats: `[]`, mail: `[{"id":"m1","from":"mayor/","subject":"Which database?","body":"A or B","read":false},{"id":"m2","subject":"old","read":true}]`}
	s := newSwarm(t, f, "codex:m1:low")
	s.Tick(time.Now())
	s.Tick(time.Now())
	got := notifications(t, s)
	if len(got) != 1 || !strings.Contains(got[0]["title"], "Which database?") {
		t.Fatalf("unexpected: %v", got)
	}
}

func TestTickSwitchesWorkerAgentWhenTheCurrentOneHitsALimit(t *testing.T) {
	f := &swarmFake{esc: `[]`, mail: `[]`, polecats: `[{"name":"obsidian","session_running":true}]`, peek: "You've hit your usage limit. Try again at 3 PM."}
	s := newSwarm(t, f, "codex:m1:low", "codex:m2:low")
	now := time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC)
	st := s.Tick(now)
	if st.Active["polecat"] != "codex-m2-low" {
		t.Fatalf("expected the fallback agent, got %q", st.Active["polecat"])
	}
	cfg := readFile(t, filepath.Join(s.Town(), "settings", "config.json"))
	if !strings.Contains(cfg, `"polecat": "codex-m2-low"`) || !strings.Contains(cfg, `"default_agent": "codex-m2-low"`) {
		t.Fatalf("settings not rewritten:\n%s", cfg)
	}
	titles := ""
	for _, n := range notifications(t, s) {
		titles += n["title"] + "|"
	}
	if !strings.Contains(titles, "Provider limit on codex-m1-low") || !strings.Contains(titles, "Switched worker agent") {
		t.Fatalf("missing notifications: %s", titles)
	}
	f.peek = "all fine"
	st = s.Tick(now.Add(time.Minute))
	if st.Active["polecat"] != "codex-m2-low" {
		t.Fatal("must stay on the healthy fallback while the first cools down")
	}
	st = s.Tick(now.Add(31 * time.Minute))
	if st.Active["polecat"] != "codex-m1-low" {
		t.Fatalf("must return to the preferred agent after its cooldown, got %q", st.Active["polecat"])
	}
}

func TestTickPausesDispatchWhenEveryProviderIsLimitedAndResumes(t *testing.T) {
	f := &swarmFake{esc: `[]`, mail: `[]`, polecats: `[{"name":"obsidian","session_running":true}]`, peek: "rate limit exceeded"}
	s := newSwarm(t, f, "codex:m1:low", "codex:m2:low")
	now := time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC)
	s.Tick(now)
	st := s.Tick(now.Add(time.Minute))
	if !st.Paused || !strings.Contains(strings.Join(f.calls, "\n"), "gt scheduler pause") {
		t.Fatalf("dispatch must pause when every agent is limited: paused=%v calls=%v", st.Paused, f.calls)
	}
	f.peek = "fine"
	st = s.Tick(now.Add(45 * time.Minute))
	if st.Paused || !strings.Contains(strings.Join(f.calls, "\n"), "gt scheduler resume") {
		t.Fatalf("dispatch must resume once an agent recovers: paused=%v", st.Paused)
	}
}

func TestAgentPresetConfinesAndRefusesUnknownSpecs(t *testing.T) {
	c := testConfig()
	c.Codex, c.NativeHome = "/nix/codex", "/home/u"
	name, preset, err := AgentPreset(c, "/nix/gastown-run", "/state/town", "codex:gpt-5.6-luna:low", nil)
	if err != nil || name != "codex-gpt-5-6-luna-low" {
		t.Fatalf("name=%q err=%v", name, err)
	}
	args := strings.Join(preset["args"].([]string), "\x00")
	for _, want := range []string{"confine", "--root\x00/state/town", "--real-home\x00/home/u", "--home-bind\x00.codex/auth.json", "--trust-codex-project",
		"--\x00/nix/codex", "model_reasoning_effort=\"low\"", "--dangerously-bypass-approvals-and-sandbox"} {
		if !strings.Contains(args, want) {
			t.Errorf("preset missing %q", strings.ReplaceAll(want, "\x00", " "))
		}
	}
	for _, bad := range []string{"codex:onlymodel", "claude:x", "opencode:x", ""} {
		if _, _, err := AgentPreset(c, "/x", "/state/town", bad, nil); err == nil {
			t.Errorf("accepted %q", bad)
		}
	}
}

func TestSwitchingAgentsPreservesOtherTownSettings(t *testing.T) {
	f := &swarmFake{esc: `[]`, mail: `[]`, polecats: `[{"name":"o","session_running":true}]`, peek: "You've hit your usage limit"}
	s := newSwarm(t, f, "codex:m1:low", "codex:m2:low")
	path := filepath.Join(s.Town(), "settings", "config.json")
	if err := os.WriteFile(path, []byte(`{"type":"town-settings","version":1,"default_agent":"x","role_agents":{},"scheduler":{"max_polecats":2},"other":"keep"}`), 0o600); err != nil {
		t.Fatal(err)
	}
	s.Tick(time.Now())
	data := readFile(t, path)
	for _, want := range []string{`"max_polecats": 2`, `"other": "keep"`, `"polecat": "codex-m2-low"`} {
		if !strings.Contains(data, want) {
			t.Fatalf("settings lost %q:\n%s", want, data)
		}
	}
}

func TestIdleCompletePolicy(t *testing.T) {
	now := time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC)
	quiet := now.Add(-5 * time.Minute)
	cases := []struct {
		name   string
		st     WatchState
		active bool
		want   bool
	}{
		{"quiet with gated work", WatchState{Gated: map[string]GateResult{"a": {Status: "pass"}}, LastActivity: quiet}, false, true},
		{"recent activity", WatchState{Gated: map[string]GateResult{"a": {Status: "pass"}}, LastActivity: now.Add(-time.Minute)}, false, false},
		{"workers still active", WatchState{Gated: map[string]GateResult{"a": {Status: "pass"}}, LastActivity: quiet}, true, false},
		{"nothing gated yet", WatchState{LastActivity: quiet}, false, false},
		{"already complete", WatchState{Complete: true, Gated: map[string]GateResult{"a": {Status: "pass"}}, LastActivity: quiet}, false, false},
	}
	for _, tc := range cases {
		if got := IdleComplete(&tc.st, now, 4*time.Minute, tc.active); got != tc.want {
			t.Errorf("%s: got %v want %v", tc.name, got, tc.want)
		}
	}
}

func rigWithBranch(t *testing.T, s *Swarm) {
	t.Helper()
	f := newGateFixture(t, map[string]string{"main.go": "package main\n"}, func(w string) { writeIn(t, w, "abs.go", "package main\n") })
	if err := os.MkdirAll(filepath.Dir(s.RigRepo()), 0o700); err != nil {
		t.Fatal(err)
	}
	gitIn(t, filepath.Dir(f.rig), "clone", "-q", "--bare", f.rig, s.RigRepo())
	gitIn(t, filepath.Dir(f.staging), "clone", "-q", "--bare", f.staging, s.Staging())
}

func TestTickGatesAFinishedBranchNotifiesAndWakesTheMayor(t *testing.T) {
	f := &swarmFake{esc: `[]`, mail: `[]`, polecats: `[]`}
	exec := func(c Command) (Result, error) {
		key := filepath.Base(c.Name) + " " + strings.Join(c.Args, " ")
		if strings.HasPrefix(key, "bd show") {
			return Result{Stdout: []byte(`[{"id":"toy-1","status":"closed"}]`)}, nil
		}
		return f.exec(c)
	}
	s := newSwarm(t, f, "codex:m1:low")
	s.R.Exec = fnExec(exec)
	rigWithBranch(t, s)
	st := s.Tick(time.Now())
	if len(st.Gated) != 1 {
		t.Fatalf("branch not gated: %+v", st.Gated)
	}
	calls := strings.Join(f.calls, "\n")
	if !strings.Contains(calls, "gt polecat nuke toy/a --force") {
		t.Fatalf("the finished worker must be released: %s", calls)
	}
	if !strings.Contains(calls, "gt nudge mayor") || !strings.Contains(calls, "toy-1") {
		t.Fatalf("the Mayor must be told the verdict: %s", calls)
	}
	titles := ""
	for _, n := range notifications(t, s) {
		titles += n["title"] + "|"
	}
	if !strings.Contains(titles, "Ready for review: toy-1") {
		t.Fatalf("missing review notification: %s", titles)
	}
	s.Tick(time.Now())
	if again := strings.Count(strings.Join(f.calls, "\n"), "gt nudge mayor"); again != 1 {
		t.Fatalf("a verdict must wake the Mayor once, got %d", again)
	}
}

func TestGoalCompleteWithoutAVerifiedBranchIsRejected(t *testing.T) {
	f := &swarmFake{esc: `[{"id":"hq-9","title":"[LOW] goal complete","description":"Sum implemented, commit 54ec50b","status":"open"}]`, mail: `[]`, polecats: `[]`}
	s := newSwarm(t, f, "codex:m1:low")
	st := s.Tick(time.Now())
	if st.Complete {
		t.Fatal("a model's claim must not complete the goal when nothing passed the gate")
	}
	got := notifications(t, s)
	if len(got) != 1 || got[0]["severity"] != "high" || !strings.Contains(got[0]["title"], "no verified") {
		t.Fatalf("expected a high alert about the unverified claim, got %v", got)
	}
}

func TestOnlyBranchesGatedAfterTheGoalCountAsVerified(t *testing.T) {
	goalAt := time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC)
	st := &WatchState{GoalAt: goalAt, Gated: map[string]GateResult{
		"old@1": {Status: "pass", At: goalAt.Add(-time.Hour)},
		"bad@2": {Status: "fail", At: goalAt.Add(time.Minute)},
	}}
	if VerifiedSinceGoal(st) != 0 {
		t.Fatal("an old pass and a failed gate must not count")
	}
	st.Gated["new@3"] = GateResult{Status: "pass", At: goalAt.Add(time.Minute)}
	if VerifiedSinceGoal(st) != 1 {
		t.Fatal("a pass after the goal must count")
	}
}

func TestMayorMailIsLabelledUnverified(t *testing.T) {
	f := &swarmFake{esc: `[]`, polecats: `[]`, mail: `[{"id":"m1","from":"mayor/","subject":"Sum implementation complete","body":"commit 54ec50b","read":false}]`}
	s := newSwarm(t, f, "codex:m1:low")
	s.Tick(time.Now())
	got := notifications(t, s)
	if len(got) != 1 || !strings.Contains(got[0]["title"], "unverified") || !strings.Contains(got[0]["body"], "not verified") {
		t.Fatalf("Mayor claims must be labelled, got %v", got)
	}
}

func TestEscalationSeverityFallsBackToTheDescription(t *testing.T) {
	f := &swarmFake{mail: `[]`, polecats: `[]`, esc: `[{"id":"hq-1","title":"Should Sum return 0?","description":"Should Sum return 0?\n\nseverity: high\nreason: options","status":"open"}]`}
	s := newSwarm(t, f, "codex:m1:low")
	s.Tick(time.Now())
	got := notifications(t, s)
	if len(got) != 1 || got[0]["severity"] != "high" {
		t.Fatalf("severity must come from the description when the title has no prefix: %v", got)
	}
}

func TestDownRemovesTheTemporaryTmuxDirectory(t *testing.T) {
	f := &swarmFake{}
	s := newSwarm(t, f, "codex:m1:low")
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	if err := os.MkdirAll(s.TmuxDir(), 0o700); err != nil {
		t.Fatal(err)
	}
	s.Down()
	if _, err := os.Stat(s.TmuxDir()); !os.IsNotExist(err) {
		t.Fatal("the tmux directory must be removed on down")
	}
}

func TestOpenCodePresetIsConfinedStandaloneAndNeverEmbedsTheKey(t *testing.T) {
	c := testConfig()
	c.OpenCode, c.NativeHome = "/nix/opencode", "/home/u"
	name, preset, err := AgentPreset(c, "/nix/gastown-run", "/state/town", "opencode:nvidia/nemotron-3-ultra-550b-a55b", nil)
	if err != nil || name != "opencode-nvidia-nemotron-3-ultra-550b-a55b" {
		t.Fatalf("name=%q err=%v", name, err)
	}
	args := strings.Join(preset["args"].([]string), "\x00")
	for _, want := range []string{"confine", "--env\x00NVIDIA_API_KEY", "--env\x00OPENCODE_PERMISSION", "--env\x00OPENCODE_CONFIG_CONTENT",
		"--\x00/nix/opencode\x00--standalone\x00--auto"} {
		if !strings.Contains(args, want) {
			t.Errorf("args missing %q", strings.ReplaceAll(want, "\x00", " "))
		}
	}
	if strings.Contains(args, "--home-bind") {
		t.Error("opencode must not bind any part of the real home")
	}
	env := preset["env"].(map[string]string)
	cfg := env["OPENCODE_CONFIG_CONTENT"]
	for _, want := range []string{`"model":"nvidia/nemotron-3-ultra-550b-a55b"`, `{env:NVIDIA_API_KEY}`, `integrate.api.nvidia.com`} {
		if !strings.Contains(cfg, want) {
			t.Errorf("inline config missing %q: %s", want, cfg)
		}
	}
	if preset["prompt_mode"] != "none" {
		t.Errorf("the startup prompt must go through Gas Town's nudge, got %v", preset["prompt_mode"])
	}
}

func TestOpenCodePresetRejectsUnknownProvidersAndMissingBinary(t *testing.T) {
	c := testConfig()
	c.OpenCode = "/nix/opencode"
	for _, spec := range []string{"opencode:unknown/model", "opencode:nvidia", "opencode:"} {
		if _, _, err := AgentPreset(c, "/x", "/state/town", spec, nil); err == nil {
			t.Errorf("accepted %q", spec)
		}
	}
	c.OpenCode = ""
	if _, _, err := AgentPreset(c, "/x", "/state/town", "opencode:nvidia/m", nil); err == nil {
		t.Error("a missing opencode binary must be an error")
	}
}

func TestAgentEnvNamesCoverEveryProviderAKeyIsNeededFor(t *testing.T) {
	got := AgentEnvNames([]string{"codex:m:low", "opencode:nvidia/m"}, []string{"EXTRA_KEY"})
	if strings.Join(got, ",") != "EXTRA_KEY,NVIDIA_API_KEY" {
		t.Fatalf("got %v", got)
	}
}

func TestProbeCommandTurnsAnOpenCodePresetIntoAOneShotRun(t *testing.T) {
	c := testConfig()
	c.OpenCode, c.NativeHome = "/nix/opencode", "/home/u"
	_, preset, err := AgentPreset(c, "/nix/gastown-run", "/state/town", "opencode:nvidia/nvidia/nemotron-3-ultra-550b-a55b", nil)
	if err != nil {
		t.Fatal(err)
	}
	cmd, env, ok := ProbeCommand(preset)
	if !ok || cmd.Name != "/nix/gastown-run" {
		t.Fatalf("probe not built: %+v ok=%v", cmd, ok)
	}
	args := strings.Join(cmd.Args, "\x00")
	if !strings.Contains(args, "--\x00/nix/opencode\x00run\x00--standalone\x00--auto\x00") || strings.HasSuffix(args, "--standalone\x00--auto") {
		t.Fatalf("expected a one-shot run, got %q", strings.ReplaceAll(args, "\x00", " "))
	}
	if env["OPENCODE_CONFIG_CONTENT"] == "" {
		t.Fatal("the probe must carry the same inline config as the agent")
	}
	_, codexPreset, _ := AgentPreset(c, "/nix/gastown-run", "/state/town", "codex:m:low", nil)
	if _, _, ok := ProbeCommand(codexPreset); ok {
		t.Fatal("codex agents use subscription quota and are not probed")
	}
}

func TestProbeVerdictReadsTheProviderAnswer(t *testing.T) {
	if ok, _ := ProbeVerdict("> build · x\nok\n"); !ok {
		t.Fatal("a plain ok answer is healthy")
	}
	ok, why := ProbeVerdict("Error: The model 'x' has reached its end of life on 2026-08-07 and is no longer available.")
	if ok || !strings.Contains(why, "end of life") {
		t.Fatalf("EOL must be unhealthy with the reason: %v %q", ok, why)
	}
	if ok, _ := ProbeVerdict("Error: Provider request failed with HTTP 404: 404 page not found"); ok {
		t.Fatal("404 must be unhealthy")
	}
	if ok, _ := ProbeVerdict(""); ok {
		t.Fatal("no answer must be unhealthy")
	}
}

func TestSwarmEnvironmentCarriesOnlyTheProviderKeysTheAgentsNeed(t *testing.T) {
	t.Setenv("NVIDIA_API_KEY", "nv-secret")
	t.Setenv("GROQ_API_KEY", "groq-secret")
	t.Setenv("AWS_SECRET_ACCESS_KEY", "leak")
	f := &swarmFake{}
	s := newSwarm(t, f, "opencode:nvidia/nvidia/nemotron-3-ultra-550b-a55b", "codex:m:low")
	text := strings.Join(s.env(), "\n")
	if !strings.Contains(text, "NVIDIA_API_KEY=nv-secret") {
		t.Fatal("the opencode provider key must reach the processes that start the agents")
	}
	for _, leak := range []string{"GROQ_API_KEY", "AWS_SECRET_ACCESS_KEY"} {
		if strings.Contains(text, leak) {
			t.Fatalf("%s must not be forwarded", leak)
		}
	}
}

func gitRefIn(t *testing.T, repo string, args ...string) string {
	t.Helper()
	return gitIn(t, repo, args...)
}

func TestAllGatedIgnoresBranchesWithoutChangesAndBlocksOnPendingWork(t *testing.T) {
	f := &swarmFake{esc: `[]`, mail: `[]`, polecats: `[]`}
	state := "closed"
	exec := func(c Command) (Result, error) {
		if strings.HasPrefix(filepath.Base(c.Name)+" "+strings.Join(c.Args, " "), "bd show") {
			return Result{Stdout: []byte(`[{"id":"toy-1","status":"` + state + `"}]`)}, nil
		}
		return f.exec(c)
	}
	s := newSwarm(t, f, "codex:m1:low")
	s.R.Exec = fnExec(exec)
	rigWithBranch(t, s)
	main := strings.TrimSpace(gitRefIn(t, s.RigRepo(), "rev-parse", "main"))
	gitRefIn(t, s.RigRepo(), "branch", "polecat/idle/toy-9+zz", main)

	st := s.loadState()
	if s.allGated(st) {
		t.Fatal("a branch with commits and no verdict is pending work")
	}
	st = s.Tick(time.Now())
	if !s.allGated(st) {
		t.Fatalf("once the changed branch is gated, an empty identity branch must not block: %+v", st.Gated)
	}
	state = "open"
	gitRefIn(t, s.RigRepo(), "update-ref", "refs/heads/polecat/b/toy-2+aa", strings.TrimSpace(gitRefIn(t, s.RigRepo(), "rev-parse", "polecat/a/toy-1+x")))
	if s.allGated(s.loadState()) {
		t.Fatal("a branch whose task is still open and has no verdict is pending")
	}
}

func TestShouldFinishDoesNotWaitForeverOnAnUnexplainedBranch(t *testing.T) {
	now := time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC)
	quiet := 4 * time.Minute
	done := WatchState{Complete: true, LastActivity: now.Add(-10 * time.Minute)}
	cases := []struct {
		name     string
		st       WatchState
		gated    bool
		active   bool
		wantStop bool
	}{
		{"complete and every branch gated", WatchState{Complete: true, LastActivity: now}, true, false, true},
		{"complete, unexplained branch, but quiet for long", done, false, false, true},
		{"complete, unexplained branch, recent activity", WatchState{Complete: true, LastActivity: now.Add(-time.Minute)}, false, false, false},
		{"complete but workers still active", done, true, true, false},
		{"not complete", WatchState{LastActivity: now.Add(-time.Hour)}, true, false, false},
	}
	for _, tc := range cases {
		if got := ShouldFinish(&tc.st, now, quiet, tc.gated, tc.active); got != tc.wantStop {
			t.Errorf("%s: got %v want %v", tc.name, got, tc.wantStop)
		}
	}
}

func TestRulesTellTheMayorWhichPathsAreProtected(t *testing.T) {
	s := newSwarm(t, &swarmFake{}, "codex:m1:low")
	s.Cfg.Protect = []string{"main.go", "cmd/"}
	rules := s.rules()
	for _, want := range []string{"main.go, cmd/", "gt escalate -s HIGH", "gt sling <bead> toy --merge=local", "Never start tmux"} {
		if !strings.Contains(rules, want) {
			t.Errorf("rules missing %q", want)
		}
	}
}

func TestClaudePresetUsesOnlyTheSubscriptionTokenAndIsConfined(t *testing.T) {
	t.Setenv("ANTHROPIC_API_KEY", "sk-leak")
	c := testConfig()
	c.Claude, c.NativeHome = "/nix/claude", "/home/u"
	name, preset, err := AgentPreset(c, "/nix/gastown-run", "/state/town", "claude:sonnet", []string{"EXTRA_KEY"})
	if err != nil || name != "claude-sonnet" {
		t.Fatalf("name=%q err=%v", name, err)
	}
	args := strings.Join(preset["args"].([]string), "\x00")
	for _, want := range []string{"confine", "--prepare-claude", "--env\x00CLAUDE_CODE_OAUTH_TOKEN", "--\x00/nix/claude\x00--dangerously-skip-permissions\x00--model\x00sonnet"} {
		if !strings.Contains(args, want) {
			t.Errorf("args missing %q", strings.ReplaceAll(want, "\x00", " "))
		}
	}
	if strings.Contains(args, "--home-bind") {
		t.Error("claude must not bind any part of the real home: a refresh inside the sandbox could rotate the user's login away")
	}
	for _, leak := range []string{"ANTHROPIC_API_KEY", "sk-leak", "ANTHROPIC_AUTH_TOKEN"} {
		if strings.Contains(args, leak) || strings.Contains(fmt.Sprint(preset["env"]), leak) {
			t.Errorf("%s must never reach the claude agent", leak)
		}
	}
	if preset["prompt_mode"] != "arg" || preset["ready_prompt_prefix"] != "❯ " {
		t.Errorf("prompt mode/prefix wrong: %v %v", preset["prompt_mode"], preset["ready_prompt_prefix"])
	}
	names, _ := preset["process_names"].([]string)
	if !strings.Contains(strings.Join(names, ","), "claude") {
		t.Errorf("process_names must include claude: %v", names)
	}
}

func TestClaudePresetNeedsTheBinaryAndAModel(t *testing.T) {
	c := testConfig()
	c.NativeHome = "/home/u"
	if _, _, err := AgentPreset(c, "/x", "/state/town", "claude:sonnet", nil); err == nil {
		t.Fatal("claude without GASTOWN_CLAUDE must be refused")
	}
	c.Claude = "/nix/claude"
	if _, _, err := AgentPreset(c, "/x", "/state/town", "claude:", nil); err == nil {
		t.Fatal("claude without a model must be refused")
	}
}

func TestSwarmEnvironmentNeverForwardsAnthropicKeys(t *testing.T) {
	t.Setenv("ANTHROPIC_API_KEY", "sk-leak")
	f := &swarmFake{}
	s := newSwarm(t, f, "claude:sonnet")
	if strings.Contains(strings.Join(s.env(), "\n"), "ANTHROPIC") {
		t.Fatal("anthropic keys must not be forwarded to the swarm environment")
	}
}

func TestClaudePresetIsNotProbed(t *testing.T) {
	c := testConfig()
	c.Claude, c.NativeHome = "/nix/claude", "/home/u"
	_, preset, _ := AgentPreset(c, "/nix/gastown-run", "/state/town", "claude:opus", nil)
	if _, _, ok := ProbeCommand(preset); ok {
		t.Fatal("claude agents use subscription quota and are not probed")
	}
}

func TestSwarmEnvironmentForwardsTheClaudeSubscriptionToken(t *testing.T) {
	t.Setenv("CLAUDE_CODE_OAUTH_TOKEN", "tok-sub")
	t.Setenv("ANTHROPIC_API_KEY", "sk-leak")
	s := newSwarm(t, &swarmFake{}, "claude:sonnet")
	text := strings.Join(s.env(), "\n")
	if !strings.Contains(text, "CLAUDE_CODE_OAUTH_TOKEN=tok-sub") || strings.Contains(text, "ANTHROPIC") {
		t.Fatalf("only the subscription token may be forwarded: %q", text)
	}
}
