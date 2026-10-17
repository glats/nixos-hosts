package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/glats/nixos-scripts/internal/gpgunlock"
)

const keysFileEnv = "NIXOS_SCRIPTS_GPG_KEYS_FILE"

func usage() {
	fmt.Fprintln(os.Stderr, "Usage: gpg-unlock")
	fmt.Fprintln(os.Stderr, "Caches the passphrase of each git signing key by signing a scratch")
	fmt.Fprintln(os.Stderr, "file, so later signed commits stop prompting until the agent cache")
	fmt.Fprintln(os.Stderr, "expires. Keys come from `git config user.signingkey` plus the key list")
	fmt.Fprintln(os.Stderr, "installed by Nix ("+keysFileEnv+"). The passphrase prompt appears in your")
	fmt.Fprintln(os.Stderr, "current terminal, unless pinentry opens a graphical dialog.")
	fmt.Fprintln(os.Stderr, "Run this once after each gpg-agent restart; never in OpenCode itself.")
	os.Exit(1)
}

func gitSigningKey() string {
	out, err := exec.Command("git", "config", "--get", "user.signingkey").Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func gpg(args ...[]string) (string, int) {
	argv := []string{}
	for _, a := range args {
		argv = append(argv, a...)
	}
	env := os.Environ()
	if term := ttyForPinentry(); term != "" {
		env = append(env, "GPG_TTY="+term)
	}
	cmd := exec.Command("gpg", argv...)
	cmd.Env = env
	var out strings.Builder
	cmd.Stdout = &out
	var errOut strings.Builder
	cmd.Stderr = &errOut
	err := cmd.Run()
	code := 0
	if exitErr, ok := err.(*exec.ExitError); ok {
		code = exitErr.ExitCode()
	} else if err != nil {
		fmt.Fprintf(os.Stderr, "gpg-unlock: %v\n", err)
		os.Exit(1)
	}
	if msg := strings.TrimSpace(errOut.String()); msg != "" {
		fmt.Fprintln(os.Stderr, msg)
	}
	return out.String(), code
}

func ttyForPinentry() string {
	fi, err := os.Stdin.Stat()
	if err != nil || fi.Mode()&os.ModeCharDevice == 0 {
		return ""
	}
	out, err := exec.Command("tty").Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func main() {
	if len(os.Args) != 1 {
		usage()
	}

	dir, err := os.MkdirTemp("", "gpg-unlock-")
	if err != nil {
		fmt.Fprintf(os.Stderr, "gpg-unlock: %v\n", err)
		os.Exit(1)
	}
	defer os.RemoveAll(dir)

	msgFile := filepath.Join(dir, "msg.txt")
	if err := os.WriteFile(msgFile, []byte("gpg-unlock passphrase cache\n"), 0o600); err != nil {
		fmt.Fprintf(os.Stderr, "gpg-unlock: %v\n", err)
		os.Exit(1)
	}

	var listed []string
	if f := os.Getenv(keysFileEnv); f != "" {
		content, err := os.ReadFile(f)
		if err != nil {
			fmt.Fprintf(os.Stderr, "gpg-unlock: reading key list: %v\n", err)
			os.Exit(1)
		}
		listed = gpgunlock.ParseKeysFile(string(content))
	}

	keys := gpgunlock.UnionKeys(gitSigningKey(), listed)
	if len(keys) == 0 {
		fmt.Fprintln(os.Stderr, "gpg-unlock: no signing keys found in git config or key list")
		os.Exit(1)
	}

	failed := false
	for _, key := range keys {
		out, code := gpg([]string{"--with-colons", "--list-secret-keys", key})
		if code != 0 || !gpgunlock.SigningCapable(out) {
			fmt.Fprintf(os.Stderr, "gpg-unlock: %s is not a signing-capable secret key, skipping\n", key)
			failed = true
			continue
		}
		if _, code := gpg(gpgunlock.SignArgs(key, msgFile, filepath.Join(dir, key+".sig"))); code != 0 {
			fmt.Fprintf(os.Stderr, "gpg-unlock: %s passphrase not cached\n", key)
			failed = true
			continue
		}
		fmt.Printf("Unlocked: %s\n", key)
	}

	if failed {
		os.Exit(1)
	}
}
