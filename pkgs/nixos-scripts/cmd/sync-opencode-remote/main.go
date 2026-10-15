// Command sync-opencode-remote copies managed assets to an existing isolated
// OpenCode configuration. It never provisions OpenCode or transfers user state.
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
	remoteDir  = envOr("REMOTE_DIR", os.Getenv("HOME")+"/.config/opencode")
	localDir   = envOr("LOCAL_DIR", os.Getenv("HOME")+"/.config/opencode")
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
	fmt.Fprintf(os.Stderr, "Usage: %s [--dry-run]\n\nSync managed assets to the native OpenCode config root.\nREMOTE_DIR and LOCAL_DIR must refer to ~/.config/opencode. Credentials and databases are never transferred.\n", filepath.Base(os.Args[0]))
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
[ "$root" = "$home/.config/opencode" ]
config="$root/opencode.json"
[ -d "$root" ] && [ -f "$config" ] && [ -r "$config" ]
jq -e '. as $c | ($c.default_agent | type == "string") and ($c.agents | type == "object" and has($c.default_agent) and length > 0)' "$config" >/dev/null
target=$(command -v opencode || true)
case "$target" in /*) [ -f "$target" ] && [ -x "$target" ] ;; *) exit 1 ;; esac
version=$("$target" --version)
case "$version" in "opencode v2."*) ;; *) exit 1 ;; esac
`
}

func validateNativeConfig(root string) error {
	home := filepath.Dir(filepath.Dir(root))
	if filepath.Clean(root) != filepath.Join(home, ".config", "opencode") {
		return fmt.Errorf("config path is not the native ~/.config/opencode root")
	}
	config, err := os.ReadFile(filepath.Join(root, "opencode.json"))
	if err != nil {
		return fmt.Errorf("read opencode.json: %w", err)
	}
	var value map[string]json.RawMessage
	if err := json.Unmarshal(config, &value); err != nil {
		return fmt.Errorf("parse opencode.json: %w", err)
	}
	var defaultAgent string
	if err := json.Unmarshal(value["default_agent"], &defaultAgent); err != nil || defaultAgent == "" {
		return fmt.Errorf("opencode.json lacks a usable default_agent")
	}
	var agents map[string]json.RawMessage
	if err := json.Unmarshal(value["agents"], &agents); err != nil || len(agents) == 0 {
		return fmt.Errorf("opencode.json lacks usable agents")
	}
	if _, ok := agents[defaultAgent]; !ok {
		return fmt.Errorf("default_agent is not declared in V2 agents")
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

func preflight() error {
	if _, err := exec.LookPath("rsync"); err != nil {
		return fmt.Errorf("rsync not found locally")
	}
	if filepath.Base(remoteDir) != "opencode" {
		return fmt.Errorf("remote path is not the native opencode config root")
	}
	if err := validateNativeConfig(localDir); err != nil {
		return fmt.Errorf("local native config unavailable: %w", err)
	}
	cmd := exec.Command("ssh", "-o", "ConnectTimeout=5", "-q", remoteUser+"@"+remoteHost, remotePreflightCommand(remoteDir))
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("remote native OpenCode preflight failed; no files were changed: %w", err)
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
	fmt.Printf("Managed OpenCode assets synced to %s@%s:%s\n", remoteUser, remoteHost, remoteDir)
	if backupPath != "" {
		fmt.Println("Backup:", backupPath)
	}
}
