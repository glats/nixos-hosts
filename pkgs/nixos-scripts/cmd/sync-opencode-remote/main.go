// Command sync-opencode-remote transfers the NixOS-generated opencode
// config to a remote host (rsync over ssh), backs up the remote config,
// runs npm install remotely, installs github-mcp-server (ARM64) and
// disables MCPs that cannot work on non-NixOS hosts.
//
// Port of bin/sync-opencode-remote: usage text, messages, flags, env
// overrides and exit codes preserved byte-for-byte.
//
//	0 success · 1 config/args · 2 ssh/backup · 3 rsync · 4 npm
//
// rsync, ssh and tar are exec'd exactly where the bash original did.
// The remote-side python snippets (MCP disabling, provider rename) are
// shipped verbatim through ssh with the same '\” shell-quote escaping
// the bash original applied to its heredoc payload; curl also still
// runs on the REMOTE side (inside the install command string) to fetch
// the github-mcp-server tarball.
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// --- Configuration (override via environment) ---
var (
	remoteHost = envOr("REMOTE_HOST", "172.16.0.12")
	remoteUser = envOr("REMOTE_USER", "glats")
	remoteDir  = envOr("REMOTE_DIR", os.Getenv("HOME")+"/.config/opencode")
	localDir   = envOr("LOCAL_DIR", os.Getenv("HOME")+"/.config/opencode")
	// MCP servers to disable on remote (not available on non-NixOS hosts)
	disabledMcps = envOr("DISABLED_MCPS", "nixos")
	// GitHub MCP server version to install on remote
	githubMCPVersion = envOr("GITHUB_MCP_VERSION", "latest")
)

// --- Flags ---
var (
	dryRun     bool
	backupPath string
)

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func usage(w *os.File) {
	// The bash heredoc is static except for $(basename "$0"): the
	// defaults shown are literal text, not the resolved env values.
	fmt.Fprintf(w, `Usage: %s [OPTIONS]

Transfer opencode configuration from this host to a remote host via rsync.

Options:
  --dry-run    Show what would be synced without making changes
  -h, --help   Show this help message

Environment variables (override defaults):
  REMOTE_HOST   Remote hostname or IP   (default: 172.16.0.12)
  REMOTE_USER   Remote SSH user          (default: glats)
  REMOTE_DIR    Remote config directory  (default: ~/.config/opencode)
  LOCAL_DIR     Local config directory   (default: ~/.config/opencode)

Prerequisites:
  - SSH key-based auth to remote host
  - rsync installed locally
  - npm installed on remote
  - API keys configured on remote separately (not transferred)

Notes:
  - github-mcp-server is auto-installed on remote (ARM64 binary)
  - nixos MCP is disabled on remote (NixOS-specific)
`, filepath.Base(os.Args[0]))
}

// buildMcpList ports the bash mcp_list accumulator:
//
//	mcp_list="${mcp_list:+$mcp_list,}\"$mcp\""
//
// → `"nixos","github"` for a two-entry DISABLED_MCPS.
func buildMcpList(mcps []string) string {
	out := ""
	for _, m := range mcps {
		if out != "" {
			out += ","
		}
		out += `"` + m + `"`
	}
	return out
}

// shellQuoteEscape ports the bash ${script//\'/\'\\\'\'} replacement used
// to embed single quotes inside the remote `python3 -c '...'` argument.
func shellQuoteEscape(s string) string {
	return strings.ReplaceAll(s, "'", "'\\''")
}

// remotePythonCmd builds the ssh command string for
//
//	ssh HOST "python3 -c '<script>'"
//
// exactly as the bash original assembled it.
func remotePythonCmd(script string) string {
	return "python3 -c '" + shellQuoteEscape(script) + "'"
}

// mcpDisableScript is the bash heredoc payload verbatim (with the two
// expansion points filled in): disable the listed MCPs in the remote
// opencode.json. Failures are non-fatal (python exits 0).
func mcpDisableScript(remoteDir, mcpList string) string {
	return fmt.Sprintf(`import json, sys
path = "%s/opencode.json"
try:
    with open(path) as f:
        cfg = json.load(f)
    mcps = cfg.get('mcp', {})
    disabled = [%s]
    for name in disabled:
        if name in mcps:
            mcps[name]['enabled'] = False
            print(f'  Disabled MCP: {name}')
    with open(path, 'w') as f:
        json.dump(cfg, f, indent=2)
except Exception as e:
    print(f'WARNING: Failed to patch MCPs: {e}', file=sys.stderr)
    sys.exit(0)  # non-fatal
`, remoteDir, mcpList)
}

// providerRenameScript is the PYFIX heredoc payload verbatim: rename the
// "opencode" provider to "opencode-go" so agent references resolve.
func providerRenameScript(remoteDir string) string {
	return fmt.Sprintf(`import json, sys
path = "%s/opencode.json"
try:
    with open(path) as f:
        cfg = json.load(f)
    prov = cfg.get('provider', {})
    if 'opencode' in prov and 'opencode-go' not in prov:
        prov['opencode-go'] = prov.pop('opencode')
        print('  Renamed provider: opencode -> opencode-go')
        with open(path, 'w') as f:
            json.dump(cfg, f, indent=2)
except Exception as e:
    print(f'WARNING: Failed to fix provider name: {e}', file=sys.stderr)
`, remoteDir)
}

// sshRC runs a remote command with inherited stdio and returns its exit
// code (127 if ssh itself could not be started, like bash).
func sshRC(userhost, remoteCmd string) int {
	cmd := exec.Command("ssh", userhost, remoteCmd)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	err := cmd.Run()
	if err == nil {
		return 0
	}
	if exitErr, ok := err.(*exec.ExitError); ok {
		return exitErr.ExitCode()
	}
	return 127
}

// sshCapture ports `var=$(ssh HOST CMD)`: stdout captured (trailing
// newlines stripped), stderr inherited; a failure is fatal under set -e.
func sshCapture(userhost, remoteCmd string) string {
	out, err := exec.Command("ssh", userhost, remoteCmd).Output()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(127)
	}
	return strings.TrimRight(string(out), "\n")
}

const compatibilityTempName = ".opencode.json.compat.tmp"

var compatibilityPluginPaths = []string{
	"plugins/rtk.ts",
	"plugins/skill-registry.ts",
}

// adaptOpencodeJSON disables BrowserMCP without inspecting or changing agents.
func adaptOpencodeJSON(input []byte) ([]byte, []string, error) {
	var config map[string]json.RawMessage
	if err := json.Unmarshal(input, &config); err != nil {
		return nil, nil, fmt.Errorf("parse opencode.json: %w", err)
	}

	actions := []string{}
	if raw, ok := config["mcp"]; ok {
		var mcps map[string]json.RawMessage
		if err := json.Unmarshal(raw, &mcps); err != nil || mcps == nil {
			return nil, nil, fmt.Errorf("parse opencode.json: mcp must be an object")
		}
		if browser, ok := mcps["browsermcp"]; ok {
			var browserConfig map[string]json.RawMessage
			if err := json.Unmarshal(browser, &browserConfig); err != nil || browserConfig == nil {
				return nil, nil, fmt.Errorf("parse opencode.json: mcp.browsermcp must be an object")
			}
			browserConfig["enabled"] = json.RawMessage("false")
			mcps["browsermcp"], _ = json.Marshal(browserConfig)
			actions = append(actions, "Disable MCP: browsermcp")
			config["mcp"], _ = json.Marshal(mcps)
		}
	}
	if len(actions) == 0 {
		return input, actions, nil
	}

	output, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return nil, nil, fmt.Errorf("encode opencode.json: %w", err)
	}
	output = append(output, '\n')
	return output, actions, nil
}

func compatibilityPlugins() ([]string, []string) {
	paths := append([]string(nil), compatibilityPluginPaths...)
	actions := []string{
		"Remove remote asset: plugins/rtk.ts",
		"Remove remote asset: plugins/skill-registry.ts",
	}
	return paths, actions
}

type compatibilitySSHReader func(userhost, remoteCmd string) ([]byte, error)
type compatibilitySSHWriter func(userhost, remoteCmd string, input []byte) error

func writeRemoteCompatibility(userhost, remoteDir string, content []byte, write compatibilitySSHWriter) error {
	temp := filepath.Join(remoteDir, compatibilityTempName)
	target := filepath.Join(remoteDir, "opencode.json")
	command := "cat > " + shellQuote(temp) + " && mv -f " + shellQuote(temp) + " " + shellQuote(target)
	return write(userhost, command, content)
}

func applyCompatibility(dry bool, localRoot, remoteRoot, userhost string, read compatibilitySSHReader, write compatibilitySSHWriter, remove func(string, string) error) ([]string, error) {
	var input []byte
	var err error
	if dry {
		input, err = os.ReadFile(filepath.Join(localRoot, "opencode.json"))
	} else {
		input, err = read(userhost, "cat "+shellQuote(filepath.Join(remoteRoot, "opencode.json")))
	}
	if err != nil {
		return nil, fmt.Errorf("read target opencode.json: %w", err)
	}
	adapted, actions, err := adaptOpencodeJSON(input)
	if err != nil {
		return nil, err
	}
	pluginPaths, pluginActions := compatibilityPlugins()
	configActions := len(actions)
	actions = append(actions, pluginActions...)
	for _, action := range actions {
		if dry {
			fmt.Println("[DRY RUN] Would " + strings.ToLower(action[:1]) + action[1:])
		} else {
			fmt.Println("      " + action)
		}
	}
	if dry {
		return actions, nil
	}
	if configActions > 0 {
		if err := writeRemoteCompatibility(userhost, remoteRoot, adapted, write); err != nil {
			return actions, fmt.Errorf("write compatible remote opencode.json: %w", err)
		}
	}
	if len(pluginPaths) > 0 {
		quoted := make([]string, len(pluginPaths))
		for i, relative := range pluginPaths {
			quoted[i] = shellQuote(filepath.Join(remoteRoot, relative))
		}
		if err := remove(userhost, "rm -f "+strings.Join(quoted, " ")); err != nil {
			return actions, fmt.Errorf("remove incompatible remote assets: %w", err)
		}
	}
	return actions, nil
}

func shellQuote(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'"
}

func sshStream(userhost, remoteCmd string, input []byte) error {
	cmd := exec.Command("ssh", userhost, remoteCmd)
	cmd.Stdin = bytes.NewReader(input)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func applyRemoteCompatibility() {
	_, err := applyCompatibility(
		dryRun,
		localDir,
		remoteDir,
		remoteUser+"@"+remoteHost,
		func(userhost, command string) ([]byte, error) {
			return exec.Command("ssh", userhost, command).Output()
		},
		sshStream,
		func(userhost, command string) error {
			if sshRC(userhost, command) != 0 {
				return fmt.Errorf("remote command failed")
			}
			return nil
		},
	)
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR: PostmarketOS compatibility failed:", err)
		backup := backupPath
		if backup == "" {
			backup = "none (backup not reached)"
		}
		fmt.Fprintf(os.Stderr, "       Backup is at: %s\n", backup)
		os.Exit(3)
	}
}

// preflight: rsync present, local dir exists (→ exit 1), then SSH
// reachability with a 5s connect timeout (→ exit 2).
func preflight() {
	failed := false

	if _, err := exec.LookPath("rsync"); err != nil {
		fmt.Fprintln(os.Stderr, "ERROR: rsync not found locally. Install rsync and try again.")
		failed = true
	}

	if fi, err := os.Stat(localDir); err != nil || !fi.IsDir() {
		fmt.Fprintf(os.Stderr, "ERROR: Local config directory does not exist: %s\n", localDir)
		failed = true
	}

	if failed {
		os.Exit(1)
	}

	// SSH reachability (the only call with an explicit connect timeout).
	cmd := exec.Command("ssh", "-o", "ConnectTimeout=5", "-q", remoteUser+"@"+remoteHost, "exit")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: Cannot reach %s@%s via SSH (timeout 5s).\n", remoteUser, remoteHost)
		os.Exit(2)
	}
}

// backupRemote: rsync target gets a cp -a backup first, so a failed
// transfer can be rolled back manually.
func backupRemote() {
	if dryRun {
		fmt.Println("[1/3] Backing up remote config (skipped in dry-run)...")
		return
	}

	if sshRC(remoteUser+"@"+remoteHost, "test -d '"+remoteDir+"'") != 0 {
		fmt.Println("[1/3] Remote config directory not found, skipping backup.")
		return
	}

	timestamp := time.Now().Format("20060102-150405")
	bakPath := remoteDir + ".bak." + timestamp

	fmt.Printf("[1/3] Backing up remote config to %s...\n", filepath.Base(bakPath))
	if sshRC(remoteUser+"@"+remoteHost, "cp -a '"+remoteDir+"' '"+bakPath+"'") != 0 {
		fmt.Fprintln(os.Stderr, "ERROR: Remote backup failed. Aborting to prevent data loss.")
		os.Exit(2)
	}

	backupPath = bakPath
	fmt.Println("      Backup saved: " + bakPath)
}

// doRsync: whitelist-first include/exclude transfer.
func doRsync() error {
	label := "[2/4]"
	if dryRun {
		label = "[DRY RUN]"
	}

	fmt.Printf("%s Syncing files to %s@%s...\n", label, remoteUser, remoteHost)

	args := []string{"-avz"}
	if dryRun {
		args = append(args, "--dry-run")
	}
	args = append(args,
		"--delete",
		"--rsh=ssh",
		"--include=opencode.json",
		"--include=IDENTITY.md",
		"--include=AGENTS.md",
		"--include=sdd-orchestrator.md",
		"--include=tui.json",
		"--include=package.json",
		"--include=.gitignore",
		"--exclude=*.backup",
		"--include=instructions/",
		"--include=instructions/**",
		"--include=skills/",
		"--include=skills/**",
		"--include=commands/",
		"--include=commands/**",
		"--include=plugins/",
		"--include=plugins/**",
		"--include=themes/",
		"--include=themes/**",
		"--exclude=node_modules/",
		"--exclude=node_modules/**",
		"--exclude=skills.backup/",
		"--exclude=skills.backup/**",
		"--exclude=.opencode/",
		"--exclude=.opencode/**",
		"--exclude=/*",
		localDir+"/",
		remoteUser+"@"+remoteHost+":"+remoteDir+"/",
	)

	cmd := exec.Command("rsync", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		rc := 127
		if exitErr, ok := err.(*exec.ExitError); ok {
			rc = exitErr.ExitCode()
		}
		fmt.Fprintf(os.Stderr, "ERROR: rsync transfer failed (exit %d).\n", rc)
		backup := backupPath
		if backup == "" {
			backup = "none (backup not reached)"
		}
		fmt.Fprintf(os.Stderr, "       Backup is at: %s\n", backup)
		return err
	}
	return nil
}

func runTransferAndCompatibility(transfer func() error, compatibility func()) error {
	if err := transfer(); err != nil {
		return err
	}
	compatibility()
	return nil
}

// doNpmInstall: node_modules/ is excluded from the transfer; deps are
// installed on the remote. Failure is non-fatal for the config files
// (exit 4 is still returned).
func doNpmInstall() {
	if dryRun {
		fmt.Println("[DRY RUN] Would run: npm install on remote")
		return
	}

	fmt.Println("[3/4] Installing dependencies on remote...")
	if sshRC(remoteUser+"@"+remoteHost, "cd '"+remoteDir+"' && npm install --only=prod") == 0 {
		fmt.Println("      Dependencies installed.")
	} else {
		fmt.Fprintln(os.Stderr, "WARNING: npm install failed. Platform config files are synced, but you may")
		fmt.Fprintln(os.Stderr, "         need to run 'npm install --only=prod' manually on the remote host.")
		os.Exit(4)
	}
}

// installGithubMcpRemote: fetch+install github-mcp-server (ARM64) on the
// remote via curl|tar, then create personal/work symlinks.
func installGithubMcpRemote() {
	if dryRun {
		fmt.Println("[*] Would install/update github-mcp-server on remote")
		return
	}

	// Check if already installed and recent
	needsInstall := false
	host := remoteUser + "@" + remoteHost
	if sshRC(host, "command -v github-mcp-server &>/dev/null") == 0 {
		fmt.Println("[*] github-mcp-server already installed, checking version...")
		if sshRC(host, "github-mcp-server --version 2>&1 | grep -qi 'Version: 1\\.'") != 0 {
			needsInstall = true
		} else {
			fmt.Println("      github-mcp-server is up to date.")
		}
	} else {
		needsInstall = true
	}

	if needsInstall {
		fmt.Println("[*] Installing github-mcp-server (ARM64) on remote...")

		var dlCmd string
		if githubMCPVersion == "latest" {
			dlCmd = "curl -sL https://api.github.com/repos/github/github-mcp-server/releases/latest |\n" +
				"        grep -o 'https://.*Linux_arm64.tar.gz' | head -1 | xargs curl -sL"
		} else {
			dlCmd = "curl -sL https://github.com/github/github-mcp-server/releases/download/v" +
				githubMCPVersion + "/github-mcp-server_Linux_arm64.tar.gz"
		}

		installCmd := "mkdir -p ~/bin &&       (" + dlCmd + ") | tar -xzf - -C /tmp/ github-mcp-server &&" +
			"       cp /tmp/github-mcp-server ~/bin/ &&" +
			"       rm -f /tmp/github-mcp-server &&" +
			"       chmod +x ~/bin/github-mcp-server &&" +
			"       echo 'Installed: $(~/bin/github-mcp-server --version 2>&1)'"

		if sshRC(host, installCmd) != 0 {
			fmt.Fprintln(os.Stderr, "WARNING: Failed to install github-mcp-server. GitHub MCP will be disabled.")
		}
	}

	// Create symlinks for separate personal/work binaries used by the config
	if sshRC(host, "command -v github-mcp-server &>/dev/null") == 0 {
		binDir := sshCapture(host, "dirname $(command -v github-mcp-server)")
		for _, variant := range []string{"github-mcp-server-personal", "github-mcp-server-work"} {
			if sshRC(host, "test -x '"+binDir+"/"+variant+"' 2>/dev/null") != 0 {
				if sshRC(host, "ln -sf '"+binDir+"/github-mcp-server' '"+binDir+"/"+variant+"'") == 0 {
					fmt.Printf("      Symlink created: %s -> github-mcp-server\n", variant)
				}
			}
		}
	}
}

// disableMcpsRemote: patch opencode.json on the remote through python3
// (MCP disabling + provider rename). Both steps are non-fatal.
func disableMcpsRemote() {
	if dryRun {
		fmt.Printf("[*] Would disable MCPs on remote: %s\n", disabledMcps)
		return
	}

	if disabledMcps == "" {
		return
	}

	mcpList := buildMcpList(strings.Fields(disabledMcps))

	fmt.Printf("[*] Disabling incompatible MCPs on remote: %s\n", disabledMcps)

	if sshRC(remoteUser+"@"+remoteHost, remotePythonCmd(mcpDisableScript(remoteDir, mcpList))) != 0 {
		fmt.Fprintln(os.Stderr, "WARNING: Could not disable MCPs on remote (python3 required).")
	}

	// Also fix provider naming: agents reference "opencode-go/..." but the
	// generated provider is named "opencode". Rename to match agent expectations.
	if sshRC(remoteUser+"@"+remoteHost, remotePythonCmd(providerRenameScript(remoteDir))) != 0 {
		fmt.Fprintln(os.Stderr, "WARNING: Could not fix provider name on remote.")
	}
}

// printSummary
func printSummary() {
	if dryRun {
		fmt.Println()
		fmt.Println("DRY RUN COMPLETE -- no changes were made.")
		fmt.Printf("  Local:  %s\n", localDir)
		fmt.Printf("  Remote: %s@%s:%s\n", remoteUser, remoteHost, remoteDir)
		return
	}

	fmt.Println()
	fmt.Printf("Sync complete. Files transferred to %s@%s.\n", remoteUser, remoteHost)
	if backupPath != "" {
		fmt.Println("  Backup: " + backupPath)
	}
	fmt.Println()
	fmt.Println("REMINDER: API keys (OPENAI_API_KEY, ANTHROPIC_API_KEY, etc.) are NOT")
	fmt.Println("          transferred. Configure them on the remote host separately.")
}

func main() {
	args := os.Args[1:]
	for len(args) > 0 {
		switch args[0] {
		case "--dry-run":
			dryRun = true
			args = args[1:]
		case "-h", "--help":
			usage(os.Stdout)
			os.Exit(0)
		default:
			fmt.Fprintf(os.Stderr, "ERROR: Unknown argument: %s\n", args[0])
			usage(os.Stderr)
			os.Exit(1)
		}
	}

	// --- Main ---
	fmt.Printf("sync-opencode-remote: %s -> %s@%s:%s\n", localDir, remoteUser, remoteHost, remoteDir)
	if dryRun {
		fmt.Println(">>> DRY RUN MODE -- no changes will be made <<<")
		fmt.Println()
	}

	preflight()
	backupRemote()
	if err := runTransferAndCompatibility(doRsync, applyRemoteCompatibility); err != nil {
		os.Exit(3)
	}
	doNpmInstall()
	installGithubMcpRemote()
	disableMcpsRemote()
	printSummary()
}
