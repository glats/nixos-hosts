// Command sync-opencode-remote copies managed assets to an existing isolated
// OpenCode V2 runtime. It never provisions OpenCode or transfers user state.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

var (
	remoteHost = envOr("REMOTE_HOST", "172.16.0.12")
	remoteUser = envOr("REMOTE_USER", "glats")
	remoteDir  = envOr("REMOTE_DIR", os.Getenv("HOME")+"/.config/opencode-v2")
	localDir   = envOr("LOCAL_DIR", os.Getenv("HOME")+"/.config/opencode-v2")
	dryRun     bool
	backupPath string
)

func envOr(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}

func usage() {
	fmt.Fprintf(os.Stderr, "Usage: %s [--dry-run]\n\nSync managed assets to an existing isolated OpenCode V2 runtime.\nREMOTE_DIR and LOCAL_DIR must refer to V2 roots. Credentials and databases are never transferred.\n", filepath.Base(os.Args[0]))
}

func shellQuote(value string) string       { return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'" }
func resolveRemoteRoot(path string) string { return filepath.Clean(path) }
func remotePreflightCommand(root string) string {
	return "bash -c " + shellQuote(remotePreflightScript(root))
}

func remotePreflightScript(root string) string {
	return `set -eu
root=` + shellQuote(resolveRemoteRoot(root)) + `
home=$(cd "$HOME" && pwd -P)
[ "$root" = "$home/.config/opencode-v2" ]
config="$root/opencode.json"
environment="$home/.local/share/opencode-v2/environment"
[ -d "$root" ] && [ -f "$config" ] && [ -r "$config" ]
[ -f "$environment" ] && [ -r "$environment" ]
jq -e '. as $c | ($c.default_agent | type == "string") and ($c.agents | type == "object" and has($c.default_agent) and length > 0)' "$config" >/dev/null
target=$(command -v opencode2 || true)
case "$target" in /*) [ -f "$target" ] && [ -x "$target" ] ;; *) exit 1 ;; esac
env_value() {
  key=$1
  raw=$(awk -v prefix="export $key=" 'index($0, prefix) == 1 { count++; value=substr($0, length(prefix)+1) } END { if (count != 1) exit 1; print value }' "$environment") || return 1
  if [[ "$raw" =~ ^[-A-Za-z0-9_./:]+$ ]]; then printf '%s' "$raw"; return 0; fi
  case "$raw" in \'*\') raw=${raw:1:${#raw}-2} ;; *) return 1 ;; esac
  unescaped=$(printf '%s\n' "$raw" | sed "s/'\\\\''//g")
  case "$unescaped" in *\'*) return 1 ;; esac
  raw=$(printf '%s\n' "$raw" | sed "s/'\\\\''/'/g")
  printf '%s' "$raw"
}
config_home=$(env_value XDG_CONFIG_HOME)
config_dir=$(env_value OPENCODE_CONFIG_DIR)
data=$(env_value XDG_DATA_HOME)
cache=$(env_value XDG_CACHE_HOME)
state=$(env_value XDG_STATE_HOME)
database=$(env_value OPENCODE_DB)
temp=$(env_value TMPDIR)
project_config=$(env_value OPENCODE_DISABLE_PROJECT_CONFIG)
[ "$config_home" = "$root" ] && [ "$config_dir" = "$root" ] && [ "$project_config" = 1 ]
case "$data" in /*/data) runtime_root=${data%/data} ;; *) exit 1 ;; esac
[ "$cache" = "$runtime_root/cache" ] && [ "$state" = "$runtime_root/state" ]
[ "$database" = "$runtime_root/data/opencode.db" ] && [ "$temp" = "$runtime_root/tmp" ]
[ "$runtime_root" != "$home/.local/share/opencode" ]
case "$runtime_root" in "$home/.local/share/opencode"/*) exit 1 ;; esac
export XDG_CONFIG_HOME="$config_home" XDG_DATA_HOME="$data" XDG_CACHE_HOME="$cache" XDG_STATE_HOME="$state"
export OPENCODE_CONFIG_DIR="$config_dir" OPENCODE_DB="$database" TMPDIR="$temp" OPENCODE_DISABLE_PROJECT_CONFIG="$project_config"
version=$("$target" --version)
case "$version" in "opencode v2."*) ;; *) exit 1 ;; esac
`
}

func validateV2Runtime(root string) error {
	if filepath.Base(root) != "opencode-v2" {
		return fmt.Errorf("runtime path is not isolated under an opencode-v2 namespace")
	}
	config, err := os.ReadFile(filepath.Join(root, "opencode.json"))
	if err != nil {
		return fmt.Errorf("read V2 opencode.json: %w", err)
	}
	var value map[string]json.RawMessage
	if err := json.Unmarshal(config, &value); err != nil {
		return fmt.Errorf("parse V2 opencode.json: %w", err)
	}
	var defaultAgent string
	if err := json.Unmarshal(value["default_agent"], &defaultAgent); err != nil || defaultAgent == "" {
		return fmt.Errorf("opencode.json lacks a usable default_agent")
	}
	var agents map[string]json.RawMessage
	if err := json.Unmarshal(value["agents"], &agents); err != nil || len(agents) == 0 {
		return fmt.Errorf("opencode.json lacks usable V2 agents")
	}
	if _, ok := agents[defaultAgent]; !ok {
		return fmt.Errorf("default_agent is not declared in V2 agents")
	}
	home := filepath.Dir(filepath.Dir(root))
	environment, err := os.ReadFile(filepath.Join(home, ".local", "share", "opencode-v2", "environment"))
	if err != nil {
		return fmt.Errorf("read isolated V2 environment: %w", err)
	}
	if err := validateEnvironmentFile(string(environment), root, home); err != nil {
		return fmt.Errorf("invalid isolated V2 environment: %w", err)
	}
	return nil
}

func transferArgs(local, root, destination string, dry bool) []string {
	args := []string{"-avz", "--rsh=ssh"}
	if dry {
		args = append(args, "--dry-run")
	}
	args = append(args,
		"--exclude=auth.json", "--exclude=**/auth.json", "--exclude=auth/", "--exclude=auth/**",
		"--exclude=credentials/", "--exclude=credentials/**", "--exclude=credentials.json", "--exclude=**/credentials.json",
		"--exclude=token.json", "--exclude=**/token.json", "--exclude=*.token",
		"--exclude=*.db", "--exclude=*.db-*", "--exclude=*.sqlite*",
		"--exclude=*.key", "--exclude=*.pem", "--exclude=*.p12", "--exclude=.env", "--exclude=.env.*", "--exclude=**/.env", "--exclude=**/.env.*",
		"--exclude=node_modules/", "--exclude=node_modules/**",
		"--include=opencode.json", "--include=cli.json", "--include=AGENTS.md",
		"--include=IDENTITY.md", "--include=instructions/", "--include=instructions/**",
		"--include=skills/", "--include=skills/**", "--include=commands/", "--include=commands/**",
		"--include=plugins/", "--include=plugins/**", "--include=themes/", "--include=themes/**",
		"--exclude=/*", local+"/", destination+":"+shellQuote(root)+"/")
	return args
}

func validateEnvironmentFile(contents, configRoot, home string) error {
	values := make(map[string]string, 8)
	required := []string{"XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "OPENCODE_CONFIG_DIR", "OPENCODE_DB", "TMPDIR", "OPENCODE_DISABLE_PROJECT_CONFIG"}
	for _, line := range strings.Split(contents, "\n") {
		if !strings.HasPrefix(line, "export ") {
			continue
		}
		assignment := strings.TrimPrefix(line, "export ")
		key, raw, ok := strings.Cut(assignment, "=")
		if !ok {
			continue
		}
		for _, expected := range required {
			if key != expected {
				continue
			}
			if _, exists := values[key]; exists {
				return fmt.Errorf("duplicate %s", key)
			}
			decoded, err := parseShellLiteral(raw)
			if err != nil {
				return fmt.Errorf("%s: %w", key, err)
			}
			values[key] = decoded
		}
	}
	for _, key := range required {
		if values[key] == "" {
			return fmt.Errorf("missing %s", key)
		}
	}
	for _, key := range required[:7] {
		if !filepath.IsAbs(values[key]) {
			return fmt.Errorf("%s is not absolute", key)
		}
	}
	configRoot, home = filepath.Clean(configRoot), filepath.Clean(home)
	if values["XDG_CONFIG_HOME"] != configRoot || values["OPENCODE_CONFIG_DIR"] != configRoot || configRoot != filepath.Join(home, ".config", "opencode-v2") {
		return fmt.Errorf("config exports do not match the destination V2 config root")
	}
	if filepath.Base(values["XDG_DATA_HOME"]) != "data" {
		return fmt.Errorf("XDG_DATA_HOME does not end in data")
	}
	runtimeRoot := filepath.Dir(values["XDG_DATA_HOME"])
	if values["XDG_CACHE_HOME"] != filepath.Join(runtimeRoot, "cache") || values["XDG_STATE_HOME"] != filepath.Join(runtimeRoot, "state") ||
		values["OPENCODE_DB"] != filepath.Join(runtimeRoot, "data", "opencode.db") || values["TMPDIR"] != filepath.Join(runtimeRoot, "tmp") {
		return fmt.Errorf("runtime exports do not share one root")
	}
	legacyRoot := filepath.Join(home, ".local", "share", "opencode")
	if runtimeRoot == legacyRoot || strings.HasPrefix(runtimeRoot, legacyRoot+string(filepath.Separator)) {
		return fmt.Errorf("runtime exports collide with legacy data")
	}
	if values["OPENCODE_DISABLE_PROJECT_CONFIG"] != "1" {
		return fmt.Errorf("project config isolation is missing")
	}
	return nil
}

func parseShellLiteral(raw string) (string, error) {
	if raw == "" {
		return "", fmt.Errorf("empty shell literal")
	}
	if raw[0] != '\'' {
		for _, r := range raw {
			if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || strings.ContainsRune("_./:-", r)) {
				return "", fmt.Errorf("unquoted shell metacharacter")
			}
		}
		return raw, nil
	}
	if len(raw) < 2 || raw[len(raw)-1] != '\'' {
		return "", fmt.Errorf("unterminated single-quoted export")
	}
	const escapedQuote = "'\\''"
	inner := raw[1 : len(raw)-1]
	var value strings.Builder
	for i := 0; i < len(inner); {
		if inner[i] == '\'' {
			if !strings.HasPrefix(inner[i:], escapedQuote) {
				return "", fmt.Errorf("malformed single-quote escape")
			}
			value.WriteByte('\'')
			i += len(escapedQuote)
			continue
		}
		if inner[i] == '\n' || inner[i] == '\r' {
			return "", fmt.Errorf("newline in shell literal")
		}
		value.WriteByte(inner[i])
		i++
	}
	return value.String(), nil
}

func preflight() error {
	if _, err := exec.LookPath("rsync"); err != nil {
		return fmt.Errorf("rsync not found locally")
	}
	if filepath.Base(remoteDir) != "opencode-v2" {
		return fmt.Errorf("remote path is not an isolated opencode-v2 namespace")
	}
	if err := validateV2Runtime(localDir); err != nil {
		return fmt.Errorf("local isolated V2 runtime unavailable: %w", err)
	}
	cmd := exec.Command("ssh", "-o", "ConnectTimeout=5", "-q", remoteUser+"@"+remoteHost, remotePreflightCommand(remoteDir))
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("remote isolated V2 runtime preflight failed; no files were changed: %w", err)
	}
	return nil
}

func backupRemote() error {
	if dryRun {
		return nil
	}
	timestamp := time.Now().Format("20060102-150405")
	backupPath = remoteDir + ".bak." + timestamp
	cmd := exec.Command("ssh", remoteUser+"@"+remoteHost, "cp -a "+shellQuote(remoteDir)+" "+shellQuote(backupPath))
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	return cmd.Run()
}

func syncAssets() error {
	destination := remoteUser + "@" + remoteHost
	cmd := exec.Command("rsync", transferArgs(localDir, resolveRemoteRoot(remoteDir), destination, dryRun)...)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	return cmd.Run()
}

func runAfterPreflight(preflightFn, backupFn, transferFn func() error) error {
	if err := preflightFn(); err != nil {
		return fmt.Errorf("preflight: %w", err)
	}
	if err := backupFn(); err != nil {
		return fmt.Errorf("backup: %w", err)
	}
	if err := transferFn(); err != nil {
		return fmt.Errorf("transfer: %w", err)
	}
	return nil
}

func main() {
	for _, arg := range os.Args[1:] {
		switch arg {
		case "--dry-run":
			dryRun = true
		case "-h", "--help":
			usage()
			return
		default:
			usage()
			os.Exit(1)
		}
	}
	if err := runAfterPreflight(preflight, backupRemote, syncAssets); err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(2)
	}
	fmt.Printf("Managed V2 assets synced to %s@%s:%s\n", remoteUser, remoteHost, remoteDir)
	if backupPath != "" {
		fmt.Println("Backup:", backupPath)
	}
}
