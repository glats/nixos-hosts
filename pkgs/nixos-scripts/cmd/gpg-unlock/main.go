package main

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/glats/nixos-scripts/internal/gpgunlock"
)

const (
	keysFileEnv         = "NIXOS_SCRIPTS_GPG_KEYS_FILE"
	defaultKeysFileName = "gpg-unlock-keys"
)

func usage() {
	fmt.Fprintln(os.Stderr, "Usage: gpg-unlock")
	fmt.Fprintln(os.Stderr, "Caches the passphrase of each git signing key by signing a scratch")
	fmt.Fprintln(os.Stderr, "file, so later signed commits stop prompting until the agent cache")
	fmt.Fprintln(os.Stderr, "expires. Keys come from `git config user.signingkey` plus the key list")
	fmt.Fprintln(os.Stderr, "given by "+keysFileEnv+", or by the sops-nix rendered "+defaultKeysFileName)
	fmt.Fprintln(os.Stderr, "list. The passphrase prompt appears in your")
	fmt.Fprintln(os.Stderr, "current terminal, or as a pinentry dialog when a display exists; from")
	fmt.Fprintln(os.Stderr, "OpenCode it never opens, because the OpenCode pinentry refuses curses and")
	fmt.Fprintln(os.Stderr, "fails immediately there.")
	fmt.Fprintln(os.Stderr, "Run this once after each gpg-agent restart; never in OpenCode itself.")
	os.Exit(1)
}

func defaultKeysFile() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return ""
		}
		base = filepath.Join(home, ".config")
	}
	return filepath.Join(base, "sops-nix", "secrets", "rendered", defaultKeysFileName)
}

func keysFile() (string, error) {
	if file := os.Getenv(keysFileEnv); file != "" {
		return file, nil
	}
	file := defaultKeysFile()
	if file == "" {
		return "", nil
	}
	if _, err := os.Stat(file); err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return "", nil
		}
		return "", err
	}
	return file, nil
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
	cmd.Stdin = os.Stdin
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
	cmd := exec.Command("tty")
	cmd.Stdin = os.Stdin
	out, err := cmd.Output()
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
	file, err := keysFile()
	if err != nil {
		fmt.Fprintf(os.Stderr, "gpg-unlock: reading key list: %v\n", err)
		os.Exit(1)
	}
	if file != "" {
		content, err := os.ReadFile(file)
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
