// Command sops-rotate-keys rotates or regenerates sops-nix age keys:
// admin key regeneration, host key conversion, add-host re-encryption and
// the recovery guide.
//
// Port of bin/sops-rotate-keys: help text, recovery guide, messages and
// exit codes preserved. All crypto work stays in the external tools
// (age-keygen, ssh-to-age, sops) exactly as in the bash original — this
// command never decrypts anything itself; it only execs the same binaries
// with the same arguments and inherits their output.
//
// Deviations from the bash original:
//   - REPO_DIR resolution uses the repo-wide reporoot chain (env → git
//     toplevel → ~/.nixos) instead of the script's parent directory; a
//     compiled binary has no script directory and the store-installed bash
//     original had the same limitation.
//   - The dead HOST=$(hostname) assignment was dropped (its value was
//     never referenced).
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/glats/nixos-scripts/internal/reporoot"
)

const hostKeyPath = "/etc/ssh/ssh_host_ed25519_key.pub"

// exitFromErr maps a subprocess failure to the shell's exit-code semantics:
// propagate the child's exit code, or 127 when the command could not run at
// all (bash prints a shell-level "command not found" line; the closest
// portable equivalent is the exec error itself).
func exitFromErr(err error) {
	if exitErr, ok := err.(*exec.ExitError); ok {
		os.Exit(exitErr.ExitCode())
	}
	fmt.Fprintln(os.Stderr, "ERROR:", err)
	os.Exit(127)
}

// run executes a command with fully inherited stdio (interactive prompts —
// sops updatekeys, git pull — keep working) and returns the error.
func run(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

// runInherit is run() with set -e semantics: a failed subprocess terminates
// the script with the child's exit code.
func runInherit(name string, args ...string) {
	if err := run(name, args...); err != nil {
		exitFromErr(err)
	}
}

// runCapture runs a command inheriting stderr, capturing stdout (bash:
// command substitution), stripping trailing newlines like $(...).
func runCapture(name string, args ...string) string {
	cmd := exec.Command(name, args...)
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	if err != nil {
		exitFromErr(err)
	}
	return strings.TrimRight(string(out), "\n")
}

func showHelp() {
	fmt.Printf(`Usage: %s [command]

Commands:
  admin              Regenerate admin age key (for editing secrets)
  host               Update host key (if SSH host key changed)
  all                Rotate both admin and host keys
  add-host HOST      Re-encrypt secrets for a new host and commit
  recover            Show recovery instructions if you lost your keys

Examples:
  %s admin          # If you deleted ~/.config/sops/age/keys.txt
  %s host           # If SSH host key was regenerated
  %s all            # Complete rotation (you'll need to re-encrypt all secrets)
  %s add-host t14   # Add t14 key to user secrets and commit
`, os.Args[0], os.Args[0], os.Args[0], os.Args[0], os.Args[0])
}

func regenerateAdminKey(repoDir string) {
	home, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}
	sopsDir := filepath.Join(home, ".config", "sops", "age")
	keysTxt := filepath.Join(sopsDir, "keys.txt")

	fmt.Println("> Regenerating admin age key...")

	if fi, err := os.Stat(keysTxt); err == nil && fi.Mode().IsRegular() {
		backup := keysTxt + ".bak." + time.Now().Format("20060102")
		fmt.Printf("> Backing up old key to %s\n", backup)
		data, err := os.ReadFile(keysTxt)
		if err != nil {
			fmt.Fprintln(os.Stderr, "Error:", err)
			os.Exit(1)
		}
		// cp without -p: a new destination gets the source's permission
		// bits (masked by umask in bash; none of the common bits differ).
		if err := os.WriteFile(backup, data, fi.Mode().Perm()); err != nil {
			fmt.Fprintln(os.Stderr, "Error:", err)
			os.Exit(1)
		}
	}

	if err := os.MkdirAll(sopsDir, 0o755); err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}

	fmt.Println("> Generating new age key...")
	runInherit("age-keygen", "-o", keysTxt)

	fmt.Println("> New admin public key:")
	runInherit("age-keygen", "-y", keysTxt)
	fmt.Println()
	fmt.Println("> IMPORTANT: Update .sops.yaml with the new admin key above")
	fmt.Printf("> Then run: cd %s && sops updatekeys secrets/secrets.yaml\n", repoDir)
}

func updateHostKey(repoDir string) {
	fmt.Println("> Getting current host SSH key...")

	if fi, err := os.Stat(hostKeyPath); err != nil || !fi.Mode().IsRegular() {
		// bash prints this ERROR to stdout (no >&2 redirect).
		fmt.Printf("ERROR: Host SSH key not found at %s\n", hostKeyPath)
		os.Exit(1)
	}

	fmt.Println("> Current host SSH key:")
	data, err := os.ReadFile(hostKeyPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, err) // cat failure under set -e
		os.Exit(1)
	}
	os.Stdout.Write(data)
	fmt.Println()

	fmt.Println("> Converting to age public key...")
	hostAgeKey := runCapture("ssh-to-age", "-i", hostKeyPath)
	fmt.Printf("age public key: %s\n", hostAgeKey)
	fmt.Println()
	fmt.Println("> IMPORTANT: Update .sops.yaml with the new host key above")
	fmt.Printf("> Then run: cd %s && sops updatekeys secrets/secrets.yaml\n", repoDir)
}

func addHost(repoDir string, args []string) {
	hostname := ""
	if len(args) > 0 {
		hostname = args[0]
	}
	if hostname == "" {
		fmt.Fprintf(os.Stderr, "ERROR: Usage: %s add-host <hostname> [secrets-file]\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  Example: %s add-host t14\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  Example: %s add-host mact2 secrets/user/opencode.yaml\n", os.Args[0])
		os.Exit(1)
	}
	secretsFile := "secrets/user/opencode.yaml"
	if len(args) > 1 {
		secretsFile = args[1]
	}

	if err := os.Chdir(repoDir); err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}

	fmt.Printf("> Adding host '%s' to secrets...\n", hostname)
	fmt.Printf("> Target: %s\n", secretsFile)
	fmt.Println()

	fmt.Println("> Pulling latest from remote...")
	runInherit("git", "pull")

	fmt.Println()
	fmt.Printf("> Re-encrypting %s for new host...\n", secretsFile)
	if err := run("sops", "updatekeys", secretsFile); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: sops updatekeys failed for %s\n", secretsFile)
		fmt.Fprintln(os.Stderr, "Make sure the new host key is added to .sops.yaml first.")
		os.Exit(1)
	}

	fmt.Println()
	fmt.Println("> Committing changes...")
	runInherit("git", "add", secretsFile)
	runInherit("git", "commit", "-m", "Add host_"+hostname+" to "+filepath.Base(secretsFile))
	runInherit("git", "push")

	fmt.Println()
	fmt.Printf("> Host '%s' added to %s and pushed.\n", hostname, secretsFile)
}

// recoveryGuide is the bash heredoc verbatim (quoted heredoc → fully
// literal, including the ${HOST} placeholders).
const recoveryGuide = `================================================================================
SOPS-NIX KEY RECOVERY GUIDE
================================================================================

SCENARIO 1: Lost admin key (~/.config/sops/age/keys.txt deleted)
-----------------------------------------------------------------
1. If you have the host key working (system can still boot/decrypt):
   - Copy /var/lib/sops-nix/key.txt to your admin location:
     sudo cp /var/lib/sops-nix/key.txt ~/.config/sops/age/keys.txt
     sudo chown $USER:$USER ~/.config/sops/age/keys.txt
     chmod 600 ~/.config/sops/age/keys.txt
   
2. If both keys are lost, you must recreate all secrets from scratch:
   - Generate new admin key: ./bin/sops-rotate-keys admin
   - Get new host key: ./bin/sops-rotate-keys host  
   - Update .sops.yaml with both new keys
   - Recreate secrets/secrets.yaml with new values
   - Rebuild: sudo nixos-rebuild switch --flake '/home/glats/.nixos#${HOST}'

SCENARIO 2: SSH host key regenerated
-------------------------------------
1. Get the new host age key: ./bin/sops-rotate-keys host
2. Update .sops.yaml
3. Re-encrypt secrets: sops updatekeys secrets/secrets.yaml
4. Commit changes: git add .sops.yaml secrets/secrets.yaml && git commit
5. Rebuild system: sudo nixos-rebuild switch --flake '/home/glats/.nixos#${HOST}'

SCENARIO 3: Adding a new host to the configuration
--------------------------------------------------
1. On the new host, get its SSH host key:
   ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub

2. Add the new key to .sops.yaml under keys:
   - &host_newname age1xxxxxxxxxx...

3. Add it to the creation_rules key_groups

4. Re-encrypt for new host and commit:
   ./bin/sops-rotate-keys add-host newname [secrets/file/path]
   
   Or manually:
   sops updatekeys secrets/secrets.yaml
   git add secrets/secrets.yaml
   git commit -m "Add host_newname to secrets"
   git push

IMPORTANT NOTES
---------------
- The admin key is for YOU to edit secrets (kept in ~/.config/sops/age/)
- The host key is for the SYSTEM to decrypt at boot (derived from SSH host key)
- Never commit the admin private key! It's in ~/.config/sops/age/ (outside repo)
- The encrypted secrets/secrets.yaml is safe to commit
- Always backup your ~/.config/sops/age/keys.txt to your password manager!

================================================================================
`

func showRecovery() {
	fmt.Print(recoveryGuide)
}

func main() {
	repoDir, err := reporoot.Resolve()
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}

	fmt.Println("> sops-nix key rotation tool")
	fmt.Printf("> Repository: %s\n", repoDir)
	fmt.Println()

	args := os.Args[1:]
	cmd := "help"
	if len(args) > 0 {
		cmd = args[0]
	}
	switch cmd {
	case "admin":
		regenerateAdminKey(repoDir)
	case "host":
		updateHostKey(repoDir)
	case "all":
		regenerateAdminKey(repoDir)
		fmt.Println()
		updateHostKey(repoDir)
		fmt.Println()
		fmt.Println("> Now update .sops.yaml with both new keys, then run:")
		fmt.Println("> sops updatekeys secrets/secrets.yaml")
	case "add-host":
		addHost(repoDir, args[1:])
	case "recover":
		showRecovery()
	case "help", "--help", "-h":
		showHelp()
	default:
		fmt.Println("Unknown command: " + args[0])
		showHelp()
		os.Exit(1)
	}
}
