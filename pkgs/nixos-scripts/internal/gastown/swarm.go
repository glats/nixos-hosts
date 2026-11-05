package gastown

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type SwarmConfig struct {
	Project     string              `json:"project"`
	Repo        string              `json:"repo"`
	Checks      []string            `json:"checks"`
	Chains      map[string][]string `json:"chains"`
	MaxPolecats int                 `json:"max_polecats"`
	DoltPort    int                 `json:"dolt_port"`
	NotifyCmd   string              `json:"notify_cmd,omitempty"`
	AgentEnv    []string            `json:"agent_env,omitempty"`
	IdleMinutes int                 `json:"idle_minutes,omitempty"`
	Protect     []string            `json:"protect,omitempty"`
	Base        string              `json:"base,omitempty"`
}

type Swarm struct {
	R    *Runner
	Cfg  SwarmConfig
	Self string
	Out  io.Writer
}

type openCodeProvider struct{ Name, Env, Package, BaseURL string }

var openCodeProviders = map[string]openCodeProvider{
	"nvidia": {Name: "NVIDIA NIM", Env: "NVIDIA_API_KEY", Package: "@opencode/ai/providers/openai-compatible", BaseURL: "https://integrate.api.nvidia.com/v1"},
}

// AgentEnvNames lists the environment variables the agents need from the
// caller: the provider keys of every opencode spec plus any extra names.
func AgentEnvNames(specs, extra []string) []string {
	seen := map[string]bool{}
	var names []string
	add := func(n string) {
		if n != "" && !seen[n] {
			seen[n] = true
			names = append(names, n)
		}
	}
	for _, n := range extra {
		add(n)
	}
	for _, spec := range specs {
		if kind, rest, _ := strings.Cut(spec, ":"); kind == "opencode" {
			provider, _, _ := strings.Cut(rest, "/")
			add(openCodeProviders[provider].Env)
		}
	}
	return names
}

var specCleaner = regexp.MustCompile(`[^a-z0-9]+`)

func (s *Swarm) Dir() string      { return filepath.Join(s.R.Config.State, "swarm", s.Cfg.Project) }
func (s *Swarm) Town() string     { return filepath.Join(s.Dir(), "town") }
func (s *Swarm) Home() string     { return filepath.Join(s.Dir(), "home") }
func (s *Swarm) Staging() string  { return filepath.Join(s.Dir(), "staging.git") }
func (s *Swarm) RigRepo() string  { return filepath.Join(s.Town(), s.Cfg.Project, ".repo.git") }
func (s *Swarm) StopFile() string { return filepath.Join(s.Dir(), "STOP") }

func (s *Swarm) TmuxDir() string {
	base := os.Getenv("XDG_RUNTIME_DIR")
	if base == "" {
		base = os.TempDir()
	}
	return filepath.Join(base, "gts-"+s.Cfg.Project)
}

func (s *Swarm) env() []string {
	c := s.R.Config
	path := strings.Join([]string{filepath.Dir(c.GT), filepath.Dir(c.BD), filepath.Dir(c.Tmux), c.SystemPath}, ":")
	env := s.baseEnv(path)
	var specs []string
	for _, chain := range s.Cfg.Chains {
		specs = append(specs, chain...)
	}
	for _, name := range AgentEnvNames(specs, s.Cfg.AgentEnv) {
		if value, ok := os.LookupEnv(name); ok {
			env = append(env, name+"="+value)
		}
	}
	return env
}

func (s *Swarm) baseEnv(path string) []string {
	return []string{"HOME=" + s.Home(), "PATH=" + path, "LANG=C.UTF-8", "TERM=dumb", "GIT_CONFIG_NOSYSTEM=1",
		"GT_ROOT=" + s.Town(), "GT_DOLT_HOST=127.0.0.1", "GT_DOLT_PORT=" + strconv.Itoa(s.Cfg.DoltPort),
		"GT_TMUX_SOCKET=gts-" + s.Cfg.Project, "TMUX_TMPDIR=" + s.TmuxDir(),
		"BD_DOLT_AUTO_COMMIT=on", "BEADS_DOLT_AUTO_START=0", "BEADS_NO_AUTO_IMPORT=1", "BD_NO_PUSH=true", "BD_BACKUP_ENABLED=false"}
}

func (s *Swarm) run(name string, args ...string) ([]byte, error) {
	dir := s.Town()
	if _, statErr := os.Stat(dir); statErr != nil {
		dir = s.Dir()
	}
	res, err := s.R.Exec.Run(Command{Name: name, Args: args, Dir: dir, Env: s.env(), Timeout: 3 * time.Minute})
	if err != nil {
		return res.Stdout, err
	}
	if res.Exit != 0 {
		return res.Stdout, fmt.Errorf("%s %s failed (exit %d): %s", filepath.Base(name), strings.Join(args, " "), res.Exit, strings.TrimSpace(string(res.Stderr)))
	}
	return res.Stdout, nil
}

func (s *Swarm) gt(args ...string) ([]byte, error) { return s.run(s.R.Config.GT, args...) }

func (s *Swarm) savePath() string { return filepath.Join(s.Dir(), "swarm.json") }

func LoadSwarm(r *Runner, project string, out io.Writer) (*Swarm, error) {
	s := &Swarm{R: r, Cfg: SwarmConfig{Project: project}, Out: out}
	self, _ := os.Executable()
	s.Self = self
	data, err := os.ReadFile(s.savePath())
	if err != nil {
		return nil, errors.New("swarm not initialized for " + project + ": run `gastown-run swarm init` first")
	}
	if err := json.Unmarshal(data, &s.Cfg); err != nil {
		return nil, err
	}
	return s, nil
}

func (s *Swarm) save() error {
	data, _ := json.MarshalIndent(s.Cfg, "", "  ")
	return os.WriteFile(s.savePath(), append(data, '\n'), 0o600)
}

// AgentPreset builds a Gas Town agent preset that runs a coding agent confined
// to the town. Spec forms: codex:<model>:<effort> and opencode:<provider/model>.
func AgentPreset(c Config, self, town, spec string, agentEnv []string) (string, map[string]any, error) {
	kind, rest, _ := strings.Cut(spec, ":")
	confine := []string{"confine", "--root", town, "--home", filepath.Join(town, ".agent-home"), "--bwrap", c.Bwrap,
		"--path", c.ToolPath + ":" + filepath.Dir(c.GT) + ":" + filepath.Dir(c.BD), "--real-home", c.NativeHome}
	switch kind {
	case "codex":
		model, effort, ok := strings.Cut(rest, ":")
		if !ok || model == "" || effort == "" {
			return "", nil, errors.New("codex spec must be codex:<model>:<effort>: " + spec)
		}
		name := "codex-" + strings.Trim(specCleaner.ReplaceAllString(strings.ToLower(model), "-"), "-") + "-" + effort
		args := append(confine, "--trust-codex-project", "--home-bind", ".codex/auth.json", "--", c.Codex,
			"-c", "check_for_update_on_startup=false", "-m", model, "-c", `model_provider="openai"`, "-c", `forced_login_method="chatgpt"`,
			"-c", "model_reasoning_effort="+quote(effort), "--dangerously-bypass-approvals-and-sandbox")
		return name, map[string]any{"name": name, "command": self, "args": args, "process_names": []string{"codex", "bwrap", "gastown-run"},
			"resume_flag": "resume", "resume_style": "subcommand", "prompt_mode": "arg", "ready_prompt_prefix": "› ",
			"ready_delay_ms": 3000, "instructions_file": "AGENTS.md"}, nil
	case "opencode":
		provider, model, ok := strings.Cut(rest, "/")
		known, found := openCodeProviders[provider]
		if c.OpenCode == "" || !ok || model == "" || !found {
			return "", nil, errors.New("opencode spec needs GASTOWN_OPENCODE and a known provider: opencode:nvidia/<model> (" + spec + ")")
		}
		name := "opencode-" + strings.Trim(specCleaner.ReplaceAllString(strings.ToLower(rest), "-"), "-")
		inline, _ := json.Marshal(map[string]any{
			"update": "disable", "model": rest,
			"providers": map[string]any{provider: map[string]any{"name": known.Name, "env": []string{known.Env}, "package": known.Package,
				"models": map[string]any{model: map[string]string{"name": model}}, "settings": map[string]string{"baseURL": known.BaseURL, "apiKey": "{env:" + known.Env + "}"}}},
			"experimental": map[string]any{"policies": []map[string]string{
				{"effect": "deny", "action": "provider.use", "resource": "*"}, {"effect": "allow", "action": "provider.use", "resource": provider}}},
		})
		args := append(confine, "--env", known.Env, "--env", "OPENCODE_PERMISSION", "--env", "OPENCODE_CONFIG_CONTENT")
		for _, e := range agentEnv {
			args = append(args, "--env", e)
		}
		args = append(args, "--", c.OpenCode, "--standalone", "--auto")
		return name, map[string]any{"name": name, "command": self, "args": args, "process_names": []string{"opencode", "bwrap", "gastown-run", "bun", "node"},
			"env": map[string]string{"OPENCODE_PERMISSION": `{"*":"allow"}`, "OPENCODE_CONFIG_CONTENT": string(inline)}, "prompt_mode": "none",
			"ready_delay_ms": 8000, "instructions_file": "AGENTS.md"}, nil
	}
	return "", nil, errors.New("unknown agent spec (use codex:<model>:<effort> or opencode:<provider/model>): " + spec)
}

func (s *Swarm) presets() (map[string]any, map[string][]string, error) {
	agents := map[string]any{}
	chains := map[string][]string{}
	for role, specs := range s.Cfg.Chains {
		for _, spec := range specs {
			name, preset, err := AgentPreset(s.R.Config, s.Self, s.Town(), spec, s.Cfg.AgentEnv)
			if err != nil {
				return nil, nil, err
			}
			agents[name] = preset
			chains[role] = append(chains[role], name)
		}
	}
	return agents, chains, nil
}

func (s *Swarm) writeSettings(roleAgents map[string]string) error {
	agents, _, err := s.presets()
	if err != nil {
		return err
	}
	registry, _ := json.MarshalIndent(map[string]any{"version": 1, "agents": agents}, "", "  ")
	if err := os.WriteFile(filepath.Join(s.Town(), "settings", "agents.json"), registry, 0o600); err != nil {
		return err
	}
	return s.writeRoleAgents(roleAgents)
}

func (s *Swarm) writeRoleAgents(roleAgents map[string]string) error {
	path := filepath.Join(s.Town(), "settings", "config.json")
	settings := map[string]any{"type": "town-settings", "version": 1}
	if data, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(data, &settings)
	}
	settings["default_agent"] = roleAgents["polecat"]
	settings["role_agents"] = roleAgents
	cfg, _ := json.MarshalIndent(settings, "", "  ")
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, cfg, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func (s *Swarm) roleAgents(active map[string]string) map[string]string {
	_, chains, _ := s.presets()
	out := map[string]string{}
	cheapest := ""
	if c := chains["polecat"]; len(c) > 0 {
		cheapest = c[len(c)-1]
	}
	for _, role := range []string{"mayor", "polecat", "crew", "witness", "refinery", "deacon"} {
		switch {
		case active[role] != "":
			out[role] = active[role]
		case len(chains[role]) > 0:
			out[role] = chains[role][0]
		case role == "witness" || role == "refinery" || role == "deacon":
			out[role] = cheapest
		case len(chains["polecat"]) > 0:
			out[role] = chains["polecat"][0]
		}
	}
	return out
}

// Init creates the isolated town for a project: a staging copy of the
// repository, the Gas Town workspace, confined agent presets and the rig.
func (s *Swarm) Init() error {
	c := s.R.Config
	if !ValidName(s.Cfg.Project) {
		return errors.New("project name must match [a-z][a-z-]{0,30}")
	}
	if len(s.Cfg.Checks) == 0 {
		return errors.New("at least one --check is required: the gate only accepts work that passes your checks")
	}
	for _, check := range s.Cfg.Checks {
		if strings.TrimSpace(check) == "" {
			return errors.New("checks must not be blank")
		}
	}
	repo, err := filepath.Abs(s.Cfg.Repo)
	if err != nil {
		return err
	}
	s.Cfg.Repo = repo
	if _, err := os.Stat(s.savePath()); err == nil {
		return errors.New("swarm already initialized: " + s.Dir())
	}
	if out, err := runGit("", "-C", repo, "rev-parse", "--verify", "HEAD"); err != nil {
		return fmt.Errorf("repository has no commits: %s", strings.TrimSpace(out))
	}
	if err := portFree(s.Cfg.DoltPort); err != nil {
		return err
	}
	if branch, err := runGit("", "-C", repo, "rev-parse", "--abbrev-ref", "HEAD"); err == nil && strings.TrimSpace(branch) != "HEAD" {
		s.Cfg.Base = strings.TrimSpace(branch)
	}
	for _, d := range []string{s.Dir(), s.Home(), s.TmuxDir()} {
		if err := os.MkdirAll(d, 0o700); err != nil {
			return err
		}
	}
	if err := os.WriteFile(filepath.Join(s.Home(), ".gitconfig"), []byte("[user]\n\tname = gastown\n\temail = gastown@localhost\n[init]\n\tdefaultBranch = main\n[safe]\n\tdirectory = *\n"), 0o600); err != nil {
		return err
	}
	if out, err := runGit("", "clone", "-q", "--bare", repo, s.Staging()); err != nil {
		return fmt.Errorf("staging clone: %s", out)
	}
	if _, err := s.run(c.GT, "install", s.Town()); err != nil {
		return err
	}
	defer func() { _, _ = s.gt("dolt", "stop") }()
	_, chains, err := s.presets()
	if err != nil {
		return err
	}
	if err := s.writeSettings(s.roleAgents(nil)); err != nil {
		return err
	}
	escalation, _ := json.MarshalIndent(map[string]any{"type": "escalation", "version": 1, "routes": map[string][]string{
		"low": {"bead"}, "medium": {"bead", "mail:mayor"}, "high": {"bead", "mail:mayor"}, "critical": {"bead", "mail:mayor"}},
		"contacts": map[string]string{}, "stale_threshold": "4h", "max_reescalations": 2}, "", "  ")
	if err := os.WriteFile(filepath.Join(s.Town(), "settings", "escalation.json"), escalation, 0o600); err != nil {
		return err
	}
	if first := chains["polecat"]; len(first) > 0 {
		if _, err := s.gt("config", "default-agent", first[0]); err != nil {
			return err
		}
	}
	if _, err := s.gt("config", "set", "scheduler.max_polecats", strconv.Itoa(s.Cfg.MaxPolecats)); err != nil {
		return err
	}
	if _, err := s.gt("rig", "add", s.Cfg.Project, "file://"+s.Staging()); err != nil {
		return err
	}
	if err := s.save(); err != nil {
		return err
	}
	fmt.Fprintf(s.Out, "swarm %s initialized in %s\nstaging repository (accepted work is published here): %s\nuncommitted changes in %s are not included\n", s.Cfg.Project, s.Dir(), s.Staging(), repo)
	return nil
}

const rulesTemplate = `OPERATING RULES set by the human. They are not negotiable.
- Dispatch work only with: gt sling <bead> %s --merge=local. Deferred dispatch is enabled and a trusted scheduler starts the workers. Never start tmux, workers or other agents yourself.
- No remote is reachable and you must not try to push. Accepted work is published by a trusted gate as branch gastown/<bead>.
- Workers must not commit Gas Town files (.beads/, .runtime/, .logs/, CLAUDE.md overlays). The gate removes them and will not trust your summary.
- When you need a decision, a credential or are blocked: run gt escalate -s HIGH "<one-line question>" -m "<options and your recommendation>", then keep working on anything that is not blocked.
- When every bead is closed run: gt escalate -s LOW "goal complete" -m "<summary>".
- The default worker agent is the cheapest one. For a hard task add --agent <name> to gt sling. Available: %s.
- The gate runs these checks on every branch before accepting it: %s
- The gate rejects any branch that changes these protected paths, so tell every worker not to touch them: %s
- Workers must not commit build outputs or binaries, and must not move, rename or restructure existing files unless the goal says so.
`

func (s *Swarm) rules() string {
	_, chains, _ := s.presets()
	protected := "(none configured)"
	if len(s.Cfg.Protect) > 0 {
		protected = strings.Join(s.Cfg.Protect, ", ")
	}
	return fmt.Sprintf(rulesTemplate, s.Cfg.Project, strings.Join(chains["polecat"], ", "), strings.Join(s.Cfg.Checks, " ; "), protected)
}

func (s *Swarm) Up() error {
	if err := portFree(s.Cfg.DoltPort); err != nil {
		if _, e := s.gt("dolt", "status"); e != nil {
			return err
		}
	}
	for _, step := range [][]string{{"dolt", "start"}, {"daemon", "start"}, {"mayor", "start"}} {
		if _, err := s.gt(step...); err != nil {
			return fmt.Errorf("%s: %w", strings.Join(step, " "), err)
		}
	}
	fmt.Fprintln(s.Out, "swarm up: dolt, daemon and mayor started")
	return nil
}

func (s *Swarm) Down() {
	for _, step := range [][]string{{"down"}, {"daemon", "stop"}, {"dolt", "stop"}} {
		_, _ = s.gt(step...)
	}
	_, _ = s.R.Exec.Run(Command{Name: s.R.Config.Tmux, Args: []string{"-L", "gts-" + s.Cfg.Project, "kill-server"}, Env: s.env(), Timeout: 15 * time.Second})
	_ = os.RemoveAll(s.TmuxDir())
}

func (s *Swarm) mail(subject, body string) error {
	if _, err := s.gt("mail", "send", "mayor/", "-s", subject, "-m", body); err != nil {
		return err
	}
	_, err := s.gt("nudge", "mayor", "You have new mail from the human. Run gt mail inbox, read it and act on it.")
	return err
}

func (s *Swarm) Goal(text string) error {
	if strings.TrimSpace(text) == "" {
		return errors.New("empty goal")
	}
	st := s.loadState()
	st.GoalAt = time.Now()
	st.Complete = false
	s.saveState(st)
	return s.mail("Goal: "+firstLine(text), s.rules()+"\nGOAL:\n"+text+"\n")
}

func (s *Swarm) Reply(text string) error {
	if strings.TrimSpace(text) == "" {
		return errors.New("empty reply")
	}
	return s.mail("Human reply: "+firstLine(text), text)
}

// ProbeCommand turns an opencode preset into a one-shot request so a model can
// be checked before a goal is spent on it. Codex presets use subscription quota
// and are not probed.
func ProbeCommand(preset map[string]any) (Command, map[string]string, bool) {
	args, _ := preset["args"].([]string)
	env, _ := preset["env"].(map[string]string)
	n := len(args)
	if n < 3 || args[n-2] != "--standalone" || args[n-1] != "--auto" || env["OPENCODE_CONFIG_CONTENT"] == "" {
		return Command{}, nil, false
	}
	probe := append(append([]string{}, args[:n-2]...), "run", "--standalone", "--auto", "Reply with exactly the single word: ok")
	self, _ := preset["command"].(string)
	return Command{Name: self, Args: probe, Timeout: 2 * time.Minute}, env, true
}

var ansiPattern = regexp.MustCompile(`\x1b\[[0-9;]*m`)

// ProbeVerdict reads the one-shot answer: healthy only when the model replied.
func ProbeVerdict(output string) (bool, string) {
	text := strings.TrimSpace(ansiPattern.ReplaceAllString(output, ""))
	if text == "" {
		return false, "no answer"
	}
	for _, line := range strings.Split(text, "\n") {
		if strings.Contains(line, "Error") {
			return false, clip(strings.TrimSpace(line), 160)
		}
	}
	return true, ""
}

// Check probes every opencode agent of the swarm and reports each verdict.
func (s *Swarm) Check() error {
	agents, _, err := s.presets()
	if err != nil {
		return err
	}
	bad := 0
	for name, raw := range agents {
		preset := raw.(map[string]any)
		cmd, extra, ok := ProbeCommand(preset)
		if !ok {
			fmt.Fprintf(s.Out, "%s: not probed (uses subscription quota; it is checked on first use)\n", name)
			continue
		}
		cmd.Dir = s.Town()
		cmd.Env = os.Environ()
		for k, v := range extra {
			cmd.Env = append(cmd.Env, k+"="+v)
		}
		res, runErr := s.R.Exec.Run(cmd)
		healthy, why := ProbeVerdict(string(res.Stdout) + "\n" + string(res.Stderr))
		if runErr != nil && why == "" {
			healthy, why = false, runErr.Error()
		}
		if healthy {
			fmt.Fprintf(s.Out, "%s: ok\n", name)
		} else {
			bad++
			fmt.Fprintf(s.Out, "%s: UNAVAILABLE - %s\n", name, why)
		}
	}
	if bad > 0 {
		return fmt.Errorf("%d agent(s) are not usable; fix the agent specs before running a goal", bad)
	}
	return nil
}

func (s *Swarm) base() string { return firstNonEmpty(s.Cfg.Base, "main") }
