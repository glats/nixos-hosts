package gastown

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type Command struct {
	Name    string
	Args    []string
	Dir     string
	Env     []string
	Stdin   []byte
	Timeout time.Duration
}

type Result struct {
	Stdout, Stderr []byte
	Exit           int
}

type Executor interface {
	Run(Command) (Result, error)
}

type Project struct{ Rig, Crew string }

type Task struct {
	Title, Prompt string
	Checks        []string
}

type CheckResult struct {
	Command string `json:"command"`
	Exit    int    `json:"exit"`
}

type Report struct {
	Status      string        `json:"status"`
	BeadID      string        `json:"bead_id,omitempty"`
	BeadState   string        `json:"bead_state"`
	Failure     string        `json:"failure,omitempty"`
	Commands    int           `json:"command_items"`
	NativeExit  int           `json:"native_exit"`
	Checks      []CheckResult `json:"checks"`
	Commit      string        `json:"commit,omitempty"`
	Diffstat    string        `json:"diffstat,omitempty"`
	AssignedNS  int64         `json:"assignment_verified_ns,omitempty"`
	DispatchNS  int64         `json:"dispatch_started_ns,omitempty"`
	Model       string        `json:"configured_model"`
	Effort      string        `json:"reasoning_effort"`
	Cancelled   bool          `json:"cancelled,omitempty"`
	ServicesOff bool          `json:"services_stopped"`
}

type taskRecord struct {
	ID   string `json:"id"`
	Crew string `json:"crew"`
}

type Plan struct {
	Config    Config `json:"config"`
	Rig       string `json:"rig"`
	Crew      string `json:"crew"`
	Workspace string `json:"workspace"`
	Town      string `json:"town"`
	BeadID    string `json:"bead_id"`
	Prompt    string `json:"prompt"`
}

type Runner struct {
	Config        Config
	Exec          Executor
	Self          string
	Poll          time.Duration
	AgentDeadline time.Duration
	MaxCommands   int
	Cancel        <-chan struct{}
	PortFree      func(int) bool
	TmuxBase      string
}

func (r *Runner) cancelled() bool {
	select {
	case <-r.Cancel:
		return true
	default:
		return false
	}
}

func (r *Runner) Town() string { return filepath.Join(r.Config.State, "town") }

func (r *Runner) Workspace(p Project) string {
	return filepath.Join(r.Town(), p.Rig, "crew", p.Crew)
}

func Isolated(c Config, workspace string, env []string, args ...string) Command {
	command := []string{"--unshare-all", "--die-with-parent", "--new-session", "--clearenv",
		"--ro-bind", "/nix/store", "/nix/store", "--ro-bind", "/run/current-system/sw/bin", "/run/current-system/sw/bin",
		"--symlink", "/run/current-system/sw/bin", "/bin", "--dir", "/usr", "--symlink", "/run/current-system/sw/bin", "/usr/bin",
		"--dev", "/dev", "--proc", "/proc", "--tmpfs", "/tmp", "--bind", workspace, workspace}
	for _, name := range []string{".git", ".beads", ".runtime"} {
		path := filepath.Join(workspace, name)
		if _, err := os.Stat(path); err == nil {
			command = append(command, "--ro-bind", path, path)
		}
	}
	for _, entry := range env {
		if key, value, ok := strings.Cut(entry, "="); ok {
			command = append(command, "--setenv", key, value)
		}
	}
	command = append(command, "--chdir", workspace, "--")
	return Command{Name: c.Bwrap, Args: append(command, args...)}
}

func (r *Runner) RunTask(p Project, t Task, job string) (report Report, err error) {
	c := r.Config
	workspace := r.Workspace(p)
	report = Report{Status: "partial", BeadState: "unavailable", Model: c.Model, Effort: c.Effort, Checks: []CheckResult{}}
	env := CoordinatorEnv(c, r.Town(), p.Rig, p.Crew)
	socket := "gastown-" + p.Rig
	tmuxDir := filepath.Join(job, "tmux")
	if r.TmuxBase != "" {
		short, mkErr := os.MkdirTemp(r.TmuxBase, "gt-")
		if mkErr != nil {
			report.Failure = mkErr.Error()
			return report, mkErr
		}
		tmuxDir = short
		defer os.RemoveAll(short)
	}
	env = append(env, "GT_TMUX_SOCKET="+socket, "TMUX_TMPDIR="+tmuxDir, "PATH="+filepath.Dir(c.Tmux)+":"+envValue(env, "PATH"))
	doltStarted := false

	run := func(name, program string, args []string, timeout time.Duration) (Result, error) {
		res, runErr := r.Exec.Run(Command{Name: program, Args: args, Dir: workspace, Env: env, Timeout: timeout})
		_ = os.WriteFile(filepath.Join(job, name+".stdout"), res.Stdout, 0o600)
		_ = os.WriteFile(filepath.Join(job, name+".stderr"), res.Stderr, 0o600)
		event, _ := json.Marshal(map[string]any{"step": name, "exit": res.Exit, "finished_ns": time.Now().UnixNano()})
		if f, openErr := os.OpenFile(filepath.Join(job, "lifecycle.jsonl"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600); openErr == nil {
			_, _ = f.Write(append(event, '\n'))
			_ = f.Close()
		}
		return res, runErr
	}
	must := func(name, program string, args ...string) ([]byte, error) {
		if !report.Cancelled && r.cancelled() {
			report.Cancelled = true
		}
		if report.Cancelled && name != "final-bead" {
			return nil, errors.New("cancelled")
		}
		res, runErr := run(name, program, args, 60*time.Second)
		if runErr != nil {
			return nil, runErr
		}
		if res.Exit != 0 {
			return nil, errors.New(name + "_failed")
		}
		return res.Stdout, nil
	}
	readBead := func(name string) (state, assignee string, readErr error) {
		out, readErr := must(name, c.BD, "show", report.BeadID, "--json")
		if readErr != nil {
			return "", "", readErr
		}
		var list []struct{ ID, Status, Assignee string }
		if json.Unmarshal(out, &list) != nil || len(list) != 1 {
			var one struct{ ID, Status, Assignee string }
			if json.Unmarshal(out, &one) != nil {
				return "", "", errors.New("bead_unreadable")
			}
			list = append(list[:0], one)
		}
		if list[0].ID != report.BeadID {
			return "", "", errors.New("bead_identity_mismatch")
		}
		return list[0].Status, list[0].Assignee, nil
	}
	save := func() {
		data, _ := json.MarshalIndent(report, "", "  ")
		pending := filepath.Join(job, "report.pending.json")
		if os.WriteFile(pending, append(data, '\n'), 0o600) == nil {
			_ = os.Rename(pending, filepath.Join(job, "report.json"))
		}
	}
	head := func() (string, error) {
		out, headErr := must("git-head", "git", "rev-parse", "HEAD")
		return strings.TrimSpace(string(out)), headErr
	}
	hookEmpty := func(name string) error {
		out, hookErr := must(name, c.GT, "hook", "show", p.Rig+"/crew/"+p.Crew, "--json")
		if hookErr != nil {
			return hookErr
		}
		var hook struct{ Status string }
		if json.Unmarshal(out, &hook) != nil || hook.Status != "empty" {
			return errors.New("existing_hook_preserved")
		}
		return nil
	}

	defer func() {
		if report.BeadID != "" && doltStarted {
			if state, _, readErr := readBead("final-bead"); readErr == nil {
				report.BeadState = state
			}
		}
		report.ServicesOff = true
		if _, stopErr := run("tmux-stop", c.Tmux, []string{"-L", socket, "kill-server"}, 15*time.Second); stopErr != nil {
			report.ServicesOff = false
		}
		if doltStarted {
			if res, stopErr := run("dolt-stop", c.GT, []string{"dolt", "stop"}, 30*time.Second); stopErr != nil || res.Exit != 0 {
				gone := report.Cancelled && r.PortFree != nil && r.PortFree(c.DoltPort)
				report.ServicesOff = gone
				report.Status = "partial"
			}
		}
		save()
	}()

	fail := func(e error) (Report, error) {
		report.Status, report.Failure = "partial", e.Error()
		return report, e
	}

	if _, e := os.Stat(workspace); e != nil {
		return fail(errors.New("workspace_missing"))
	}
	if len(filepath.Join(tmuxDir, "tmux-"+strconv.Itoa(os.Getuid()), socket)) > 100 {
		return fail(errors.New("tmux_socket_path_too_long"))
	}
	if e := CleanGasTownIgnore(workspace); e != nil {
		return fail(fmt.Errorf("gitignore_cleanup: %w", e))
	}
	status, e := must("git-status", "git", "status", "--porcelain")
	if e != nil {
		return fail(e)
	}
	if strings.TrimSpace(string(status)) != "" {
		return fail(errors.New("workspace_not_clean"))
	}
	baseline, e := head()
	if e != nil {
		return fail(e)
	}
	if e := os.MkdirAll(filepath.Join(job, "tmp"), 0o700); e != nil {
		return fail(e)
	}
	if e := os.MkdirAll(tmuxDir, 0o700); e != nil {
		return fail(e)
	}

	if _, e := must("dolt-start", c.GT, "dolt", "start"); e != nil {
		return fail(e)
	}
	doltStarted = true
	if e := hookEmpty("initial-hook"); e != nil {
		return fail(e)
	}
	out, e := must("bead-create", c.BD, "create", t.Title, "-t", "task", "-p", "2", "-d", t.Prompt, "--silent")
	if e != nil {
		return fail(e)
	}
	report.BeadID = strings.TrimSpace(string(out))
	if !ValidBeadID(report.BeadID) {
		return fail(errors.New("unexpected_bead_id"))
	}
	record, _ := json.Marshal(taskRecord{ID: report.BeadID, Crew: p.Crew})
	if e := os.WriteFile(filepath.Join(job, "bead.json"), append(record, '\n'), 0o600); e != nil {
		return fail(e)
	}
	if _, e := must("bead-hook", c.GT, "hook", report.BeadID); e != nil {
		return fail(e)
	}
	state, assignee, e := readBead("assigned-bead")
	if e != nil {
		return fail(e)
	}
	if state != "hooked" || assignee != p.Rig+"/crew/"+p.Crew {
		return fail(errors.New("assignment_mismatch"))
	}
	report.BeadState, report.AssignedNS = state, time.Now().UnixNano()

	plan, _ := json.Marshal(Plan{Config: c, Rig: p.Rig, Crew: p.Crew, Workspace: workspace, Town: r.Town(), BeadID: report.BeadID, Prompt: t.Prompt})
	if e := os.WriteFile(filepath.Join(job, "plan.json"), plan, 0o600); e != nil {
		return fail(e)
	}
	if strings.ContainsAny(job+r.Self, " \t\n\r'\"\\$`;&|<>()*?[]{}~#!") {
		return fail(errors.New("unsafe_agent_command_path"))
	}
	if _, e := must("agent-register", c.GT, "config", "agent", "set", "gastown-guarded", r.Self+" guard --job "+job); e != nil {
		return fail(e)
	}
	report.DispatchNS = time.Now().UnixNano()
	if _, e := must("crew-start", c.GT, "crew", "start", p.Rig, p.Crew, "--agent", "gastown-guarded"); e != nil {
		return fail(e)
	}

	exitFile, streamFile := filepath.Join(job, "exit-code.txt"), filepath.Join(job, "stream.jsonl")
	deadline := time.Now().Add(r.AgentDeadline)
	inspect := func() error {
		data, _ := os.ReadFile(streamFile)
		seen := InspectStream(data)
		report.Commands = seen.Commands
		if seen.Forbidden {
			return errors.New("unexpected_tool")
		}
		if seen.Commands > r.MaxCommands {
			return errors.New("command_budget_exceeded")
		}
		return nil
	}
	for {
		if r.cancelled() {
			report.Cancelled = true
			return fail(errors.New("cancelled"))
		}
		if e := inspect(); e != nil {
			return fail(e)
		}
		if _, statErr := os.Stat(exitFile); statErr == nil {
			break
		}
		if time.Now().After(deadline) {
			return fail(errors.New("native_deadline_exceeded"))
		}
		time.Sleep(r.Poll)
	}
	raw, _ := os.ReadFile(exitFile)
	code, parseErr := strconv.Atoi(strings.TrimSpace(string(raw)))
	if parseErr != nil {
		return fail(errors.New("native_run_incomplete"))
	}
	report.NativeExit = code
	data, _ := os.ReadFile(streamFile)
	if report.NativeExit != 0 || !InspectStream(data).TurnCompleted {
		return fail(errors.New("native_run_incomplete"))
	}
	if current, e := head(); e != nil || current != baseline {
		return fail(errors.New("executor_moved_head"))
	}

	checkEnv := CheckEnv(c, workspace)
	if e := prepareCheckLogs(workspace); e != nil {
		return fail(e)
	}
	passed := true
	for i, check := range t.Checks {
		command := Isolated(c, workspace, checkEnv, "/bin/sh", "-c", check)
		command.Dir, command.Timeout = workspace, 10*time.Minute
		res, runErr := r.Exec.Run(command)
		_ = os.WriteFile(filepath.Join(job, fmt.Sprintf("check-%d.stdout", i+1)), res.Stdout, 0o600)
		_ = os.WriteFile(filepath.Join(job, fmt.Sprintf("check-%d.stderr", i+1)), res.Stderr, 0o600)
		if runErr != nil {
			res.Exit = -1
		}
		report.Checks = append(report.Checks, CheckResult{Command: check, Exit: res.Exit})
		passed = passed && res.Exit == 0
	}
	if !passed {
		return fail(errors.New("checks_failed"))
	}
	if current, e := head(); e != nil || current != baseline {
		return fail(errors.New("checks_moved_head"))
	}

	if e := CleanGasTownIgnore(workspace); e != nil {
		return fail(fmt.Errorf("gitignore_cleanup: %w", e))
	}
	changes, e := must("git-changes", "git", "status", "--porcelain")
	if e != nil {
		return fail(e)
	}
	if strings.TrimSpace(string(changes)) != "" {
		identity := []string{"-c", "core.hooksPath=/dev/null", "-c", "user.name=gastown", "-c", "user.email=gastown@localhost"}
		if _, e := must("git-add", "git", append(identity, "add", "-A")...); e != nil {
			return fail(e)
		}
		message := t.Title + "\n\nBead: " + report.BeadID
		if _, e := must("git-commit", "git", append(identity, "commit", "--no-verify", "-m", message)...); e != nil {
			return fail(e)
		}
		stat, _ := must("git-diffstat", "git", "diff", "--stat", baseline, "HEAD")
		report.Diffstat = strings.TrimSpace(string(stat))
		if commit, e := head(); e == nil {
			report.Commit = commit
		}
	}

	owned, who, e := readBead("before-close")
	if e != nil {
		return fail(e)
	}
	if owned != "hooked" || who != p.Rig+"/crew/"+p.Crew {
		return fail(errors.New("assignment_changed"))
	}
	if _, e := must("bead-close", c.BD, "close", report.BeadID, "--reason", "Native execution finished and every trusted check passed."); e != nil {
		return fail(e)
	}
	closed, _, e := readBead("closed-bead")
	if e != nil || closed != "closed" {
		return fail(errors.New("completion_not_persisted"))
	}
	if e := hookEmpty("completed-hook"); e != nil {
		return fail(errors.New("hook_not_cleared"))
	}
	report.Status, report.BeadState = "pass", closed
	return report, nil
}

// prepareCheckLogs replaces .logs with real directories. The executor controls
// the clone, so any existing .logs (possibly a symlink) is removed, not followed.
func prepareCheckLogs(workspace string) error {
	logs := filepath.Join(workspace, ".logs")
	if err := os.RemoveAll(logs); err != nil {
		return err
	}
	if err := os.Mkdir(logs, 0o700); err != nil {
		return err
	}
	paths := []string{logs}
	for _, name := range []string{"tool-home", "gotmp", "gocache", "gopath"} {
		path := filepath.Join(logs, name)
		if err := os.Mkdir(path, 0o700); err != nil {
			return err
		}
		paths = append(paths, path)
	}
	for _, path := range paths {
		if info, err := os.Lstat(path); err != nil || !info.IsDir() {
			return errors.New("unsafe_logs_path")
		}
	}
	return nil
}

func envValue(env []string, key string) string {
	for i := len(env) - 1; i >= 0; i-- {
		if value, ok := strings.CutPrefix(env[i], key+"="); ok {
			return value
		}
	}
	return ""
}

func CheckEnv(c Config, workspace string) []string {
	return []string{"PATH=" + c.ToolPath, "HOME=" + filepath.Join(workspace, ".logs/tool-home"),
		"TMPDIR=" + filepath.Join(workspace, ".logs/gotmp"), "GOCACHE=" + filepath.Join(workspace, ".logs/gocache"),
		"GOPATH=" + filepath.Join(workspace, ".logs/gopath"), "GOTOOLCHAIN=local", "GOPROXY=off", "GOSUMDB=off",
		"GOENV=off", "GOFLAGS=-buildvcs=false", "CGO_ENABLED=0", "LANG=C.UTF-8"}
}

// RunChecks runs trusted checks in isolation inside dir and records their output under logDir.
func (r *Runner) RunChecks(dir string, checks []string, logDir string) []CheckResult {
	results := []CheckResult{}
	if err := prepareCheckLogs(dir); err != nil {
		return append(results, CheckResult{Command: "prepare", Exit: -1})
	}
	_ = os.MkdirAll(logDir, 0o700)
	for i, check := range checks {
		command := Isolated(r.Config, dir, CheckEnv(r.Config, dir), "/bin/sh", "-c", check)
		command.Dir, command.Timeout = dir, 10*time.Minute
		res, err := r.Exec.Run(command)
		_ = os.WriteFile(filepath.Join(logDir, fmt.Sprintf("check-%d.stdout", i+1)), res.Stdout, 0o600)
		_ = os.WriteFile(filepath.Join(logDir, fmt.Sprintf("check-%d.stderr", i+1)), res.Stderr, 0o600)
		if err != nil {
			res.Exit = -1
		}
		results = append(results, CheckResult{Command: check, Exit: res.Exit})
	}
	return results
}
