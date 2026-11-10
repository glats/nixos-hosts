// Package gastown drives the pinned Gas Town toolchain with a sandboxed native
// Codex executor: assign a task, run the executor, verify with trusted checks,
// and close the task only when every check passes.
package gastown

import (
	"bytes"
	"encoding/json"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

type Config struct {
	GT, BD, Tmux, Codex, Bwrap string
	Bash                       string
	OpenCode, Claude           string
	ToolPath, SystemPath       string
	NativeHome, State          string
	DoltPort                   int
	Model, Effort              string
}

var (
	beadPattern = regexp.MustCompile(`^[a-z][a-z0-9]*-[a-z0-9]+$`)
	namePattern = regexp.MustCompile(`^[a-z][a-z-]{0,30}$`)
)

var disabledFeatures = []string{
	"plugins", "apps", "hooks", "codex_hooks", "plugin_hooks", "browser_use", "computer_use",
	"in_app_browser", "remote_control", "multi_agent", "js_repl", "memories", "memory_tool",
	"image_generation", "shell_snapshot", "external_agent_memory_import", "workspace_dependencies",
	"standalone_web_search", "search_tool", "skill_search", "enable_fanout", "collab", "connectors",
	"remote_plugin", "skill_mcp_dependency_install",
}

func ValidBeadID(id string) bool { return beadPattern.MatchString(id) }

func ValidName(name string) bool { return namePattern.MatchString(name) }

func ValidBeacon(argv []string, cwd, workspace, rig, crew string) bool {
	if len(argv) != 1 || filepath.Clean(cwd) != filepath.Clean(workspace) {
		return false
	}
	pattern := `^\[GAS TOWN\] crew ` + regexp.QuoteMeta(crew) + ` \(rig: ` + regexp.QuoteMeta(rig) + `\) <- human • \S+ • start$`
	return regexp.MustCompile(pattern).MatchString(argv[0])
}

func quote(value string) string {
	var out bytes.Buffer
	encoder := json.NewEncoder(&out)
	encoder.SetEscapeHTML(false)
	_ = encoder.Encode(value)
	return strings.TrimSuffix(out.String(), "\n")
}

type entry struct{ key, value string }

func table(entries []entry) string {
	parts := make([]string, len(entries))
	for i, e := range entries {
		parts[i] = quote(e.key) + "=" + quote(e.value)
	}
	return "{" + strings.Join(parts, ",") + "}"
}

// PolicyArgs confines the executor: it may write only its workspace, cannot
// touch repository, task or runtime metadata, and has no network.
func PolicyArgs(c Config, workspace, job string) []string {
	filesystem := []entry{{":root", "read"}, {":workspace_roots", "write"}, {workspace, "write"}}
	for _, path := range []string{"/home", "/root", "/tmp", "/run", "/mnt", "/media", "/var", "/proc"} {
		filesystem = append(filesystem, entry{path, "deny"})
	}
	filesystem = append(filesystem, entry{"/run/current-system", "read"})
	for _, name := range []string{".git", ".beads", ".runtime", ".codex"} {
		filesystem = append(filesystem, entry{filepath.Join(workspace, name), "read"})
	}
	permissions := "{pilot={filesystem=" + table(filesystem) + ",network={enabled=false}}}"
	logs := filepath.Join(workspace, ".logs")
	shell := table([]entry{
		{"PATH", c.ToolPath}, {"__NIXOS_SET_ENVIRONMENT_DONE", "1"},
		{"HOME", filepath.Join(logs, "tool-home")}, {"TMPDIR", filepath.Join(logs, "gotmp")},
		{"GOCACHE", filepath.Join(logs, "gocache")}, {"GOPATH", filepath.Join(logs, "gopath")},
		{"GOTMPDIR", filepath.Join(logs, "gotmp")}, {"GOTOOLCHAIN", "local"}, {"GOPROXY", "off"},
		{"GOSUMDB", "off"}, {"GOENV", "off"}, {"GOFLAGS", "-buildvcs=false"}, {"CGO_ENABLED", "0"},
	})
	values := []string{
		`default_permissions="pilot"`, "permissions=" + permissions, `approval_policy="never"`,
		`web_search="disabled"`, "mcp_servers={}",
		"shell_environment_policy={inherit=\"none\",set=" + shell + "}",
		"sqlite_home=" + quote(filepath.Join(job, "state")), "log_dir=" + quote(filepath.Join(job, "logs")),
		`history={persistence="none"}`, "features.use_linux_sandbox_bwrap=true",
	}
	for _, name := range disabledFeatures {
		values = append(values, "features."+name+"=false")
	}
	args := make([]string, 0, 2*len(values))
	for _, value := range values {
		args = append(args, "-c", value)
	}
	return args
}

func CodexArgs(c Config, workspace, job, prompt string) []string {
	args := []string{"exec", "--ignore-user-config", "--ignore-rules", "--strict-config", "--ephemeral", "--json",
		"--skip-git-repo-check", "--model", c.Model, "-C", workspace,
		"-c", `model_provider="openai"`, "-c", `forced_login_method="chatgpt"`}
	args = append(args, PolicyArgs(c, workspace, job)...)
	args = append(args, "-c", "model_reasoning_effort="+quote(c.Effort), "-c", "features.fast_mode=false")
	return append(args, prompt)
}

func NativeEnv(c Config, job string) []string {
	return []string{"HOME=" + c.NativeHome, "PATH=" + c.SystemPath, "LANG=C.UTF-8", "TERM=dumb",
		"TMPDIR=" + filepath.Join(job, "tmp"), "GIT_CONFIG_NOSYSTEM=1"}
}

func CoordinatorEnv(c Config, town, rig, crew string) []string {
	return []string{
		"HOME=" + filepath.Join(c.State, "home"), "PATH=" + filepath.Dir(c.GT) + ":" + filepath.Dir(c.BD) + ":" + c.SystemPath,
		"LANG=C.UTF-8", "TERM=dumb", "GIT_CONFIG_NOSYSTEM=1",
		"GT_ROOT=" + town, "GT_ROLE=crew", "GT_RIG=" + rig, "GT_CREW=" + crew,
		"BD_ACTOR=" + rig + "/crew/" + crew, "GT_DOLT_HOST=127.0.0.1", "GT_DOLT_PORT=" + strconv.Itoa(c.DoltPort),
		"BD_DOLT_AUTO_COMMIT=on", "BEADS_DOLT_AUTO_START=0", "BEADS_NO_AUTO_IMPORT=1",
		"BD_EXPORT_AUTO=false", "BD_NO_PUSH=true", "BD_NO_GIT_OPS=true", "BD_BACKUP_ENABLED=false",
	}
}

type Inspection struct {
	Commands      int
	Forbidden     bool
	TurnCompleted bool
}

func InspectStream(stream []byte) Inspection {
	var result Inspection
	seen := map[string]bool{}
	for _, line := range bytes.Split(stream, []byte("\n")) {
		var event struct {
			Type string `json:"type"`
			Item struct {
				ID   string `json:"id"`
				Type string `json:"type"`
			} `json:"item"`
		}
		if json.Unmarshal(line, &event) != nil {
			continue
		}
		switch event.Item.Type {
		case "command_execution":
			if !seen[event.Item.ID] {
				seen[event.Item.ID] = true
				result.Commands++
			}
		case "mcp_tool_call", "collab_tool_call", "web_search":
			result.Forbidden = true
		}
		if event.Type == "turn.completed" {
			result.TurnCompleted = true
		}
	}
	return result
}
