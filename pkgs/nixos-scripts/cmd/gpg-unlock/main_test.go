package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

const (
	helperEnv     = "NIXOS_SCRIPTS_GPG_UNLOCK_HELPER"
	helperArgsEnv = "NIXOS_SCRIPTS_GPG_UNLOCK_HELPER_ARGS"

	personalKey = "0123456789ABCDEF0123456789ABCDEF01234567"
	workKey     = "89ABCDEF0123456789ABCDEF0123456789ABCDEF"
)

type commandResult struct {
	stdout string
	stderr string
	code   int
}

func TestGPGUnlockHelperProcess(t *testing.T) {
	if os.Getenv(helperEnv) != "1" {
		return
	}
	os.Args = append([]string{"gpg-unlock"}, splitHelperArgs(os.Getenv(helperArgsEnv))...)
	main()
	os.Exit(0)
}

func splitHelperArgs(raw string) []string {
	if raw == "" {
		return nil
	}
	return strings.Split(raw, "\x00")
}

func runGPGUnlock(t *testing.T, env map[string]string, args ...string) commandResult {
	t.Helper()
	cmd := exec.Command(os.Args[0], "-test.run=TestGPGUnlockHelperProcess")
	cmd.Env = append(os.Environ(), helperEnv+"=1", helperArgsEnv+"="+strings.Join(args, "\x00"))
	for key, value := range env {
		cmd.Env = append(cmd.Env, key+"="+value)
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	code := 0
	if exitErr, ok := err.(*exec.ExitError); ok {
		code = exitErr.ExitCode()
	} else if err != nil {
		t.Fatalf("running gpg-unlock: %v", err)
	}
	return commandResult{stdout: stdout.String(), stderr: stderr.String(), code: code}
}

func setupFakeTools(t *testing.T, gitSigningKey string) string {
	t.Helper()
	bin := t.TempDir()
	gitScript := `#!/bin/sh
if [ "$1" = "config" ] && [ "$2" = "--get" ] && [ "$3" = "user.signingkey" ]; then
  if [ -n "$FAKE_GIT_SIGNING_KEY" ]; then printf "%s\n" "$FAKE_GIT_SIGNING_KEY"; fi
  exit 0
fi
exit 1
`
	gpgScript := `#!/bin/sh
if [ -n "$GPG_TEST_LOG" ]; then
  printf '%s\n' "$@" >> "$GPG_TEST_LOG"
fi
if [ "$1" = "--with-colons" ]; then
  if [ "$FAKE_GPG_PUBLIC_ONLY" = "1" ]; then
    printf 'pub:-:4096:1:89ABCDEF01234567:1783349514:1941029514::-:::scESC:::+:::23:\n'
  else
    printf 'sec:-:4096:1:89ABCDEF01234567:1783349514:1941029514::-:::scESC:::+:::23::0:\n'
  fi
  exit 0
fi
if [ "$1" = "--yes" ]; then
  out=""
  prev=""
  for arg in "$@"; do
    if [ "$prev" = "--output" ]; then out="$arg"; fi
    prev="$arg"
  done
  if [ -n "$out" ]; then printf 'synthetic-signature\n' > "$out"; fi
  exit 0
fi
exit 1
`
	for name, script := range map[string]string{"git": gitScript, "gpg": gpgScript} {
		path := filepath.Join(bin, name)
		if err := os.WriteFile(path, []byte(script), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("TMPDIR", t.TempDir())
	t.Setenv("FAKE_GIT_SIGNING_KEY", gitSigningKey)
	return bin
}

func writeKeysFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
}

func fileHash(t *testing.T, path string) string {
	t.Helper()
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(content)
	return hex.EncodeToString(sum[:])
}

func TestGPGUnlockUsesExplicitKeysFile(t *testing.T) {
	setupFakeTools(t, personalKey)
	keysFile := filepath.Join(t.TempDir(), "keys")
	writeKeysFile(t, keysFile, workKey+"\n")

	result := runGPGUnlock(t, map[string]string{keysFileEnv: keysFile})

	if result.code != 0 {
		t.Fatalf("exit code = %d, want 0 (stderr: %s)", result.code, result.stderr)
	}
	want := "Unlocked: " + personalKey + "\nUnlocked: " + workKey + "\n"
	if result.stdout != want {
		t.Fatalf("stdout = %q, want %q", result.stdout, want)
	}
	if result.stderr != "" {
		t.Fatalf("stderr = %q, want empty", result.stderr)
	}
}

func TestGPGUnlockExplicitKeysFileErrorIsPreserved(t *testing.T) {
	setupFakeTools(t, personalKey)
	missing := filepath.Join(t.TempDir(), "absent-keys")

	result := runGPGUnlock(t, map[string]string{keysFileEnv: missing})

	if result.code != 1 {
		t.Fatalf("exit code = %d, want 1", result.code)
	}
	if !strings.HasPrefix(result.stderr, "gpg-unlock: reading key list: ") {
		t.Fatalf("stderr = %q, want the key list read error", result.stderr)
	}
	if result.stdout != "" {
		t.Fatalf("stdout = %q, want empty", result.stdout)
	}
}

func TestGPGUnlockUsesDefaultRuntimeKeysFile(t *testing.T) {
	setupFakeTools(t, personalKey)
	configHome := t.TempDir()
	rendered := filepath.Join(configHome, "sops-nix", "secrets", "rendered")
	if err := os.MkdirAll(rendered, 0o700); err != nil {
		t.Fatal(err)
	}
	writeKeysFile(t, filepath.Join(rendered, "gpg-unlock-keys"), workKey+"\n")

	result := runGPGUnlock(t, map[string]string{"XDG_CONFIG_HOME": configHome})

	if result.code != 0 {
		t.Fatalf("exit code = %d, want 0 (stderr: %s)", result.code, result.stderr)
	}
	want := "Unlocked: " + personalKey + "\nUnlocked: " + workKey + "\n"
	if result.stdout != want {
		t.Fatalf("stdout = %q, want %q", result.stdout, want)
	}
}

func TestGPGUnlockExplicitKeysFileWinsOverDefaultFile(t *testing.T) {
	setupFakeTools(t, personalKey)
	configHome := t.TempDir()
	rendered := filepath.Join(configHome, "sops-nix", "secrets", "rendered")
	if err := os.MkdirAll(rendered, 0o700); err != nil {
		t.Fatal(err)
	}
	writeKeysFile(t, filepath.Join(rendered, "gpg-unlock-keys"), "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n")
	keysFile := filepath.Join(t.TempDir(), "keys")
	writeKeysFile(t, keysFile, workKey+"\n")

	result := runGPGUnlock(t, map[string]string{
		keysFileEnv:       keysFile,
		"XDG_CONFIG_HOME": configHome,
	})

	if result.code != 0 {
		t.Fatalf("exit code = %d, want 0 (stderr: %s)", result.code, result.stderr)
	}
	want := "Unlocked: " + personalKey + "\nUnlocked: " + workKey + "\n"
	if result.stdout != want {
		t.Fatalf("stdout = %q, want %q", result.stdout, want)
	}
}

func TestGPGUnlockMissingDefaultFileIsNotAnError(t *testing.T) {
	setupFakeTools(t, personalKey)
	configHome := t.TempDir()

	result := runGPGUnlock(t, map[string]string{"XDG_CONFIG_HOME": configHome})

	if result.code != 0 {
		t.Fatalf("exit code = %d, want 0 (stderr: %s)", result.code, result.stderr)
	}
	want := "Unlocked: " + personalKey + "\n"
	if result.stdout != want {
		t.Fatalf("stdout = %q, want %q", result.stdout, want)
	}
}

func TestGPGUnlockWithoutAnyKeyFails(t *testing.T) {
	setupFakeTools(t, "")
	configHome := t.TempDir()

	result := runGPGUnlock(t, map[string]string{"XDG_CONFIG_HOME": configHome})

	if result.code != 1 {
		t.Fatalf("exit code = %d, want 1", result.code)
	}
	want := "gpg-unlock: no signing keys found in git config or key list\n"
	if result.stderr != want {
		t.Fatalf("stderr = %q, want %q", result.stderr, want)
	}
}

func TestGPGUnlockRejectsAnyArgument(t *testing.T) {
	setupFakeTools(t, personalKey)

	result := runGPGUnlock(t, nil, "--help")

	if result.code != 1 {
		t.Fatalf("exit code = %d, want 1", result.code)
	}
	if !strings.HasPrefix(result.stderr, "Usage: gpg-unlock") {
		t.Fatalf("stderr = %q, want the usage text", result.stderr)
	}
	if result.stdout != "" {
		t.Fatalf("stdout = %q, want empty", result.stdout)
	}
}

func TestGPGUnlockRejectionLeavesKeyListUnchanged(t *testing.T) {
	setupFakeTools(t, personalKey)
	t.Setenv("FAKE_GPG_PUBLIC_ONLY", "1")
	keysFile := filepath.Join(t.TempDir(), "keys")
	writeKeysFile(t, keysFile, workKey+"\n")
	before := fileHash(t, keysFile)

	result := runGPGUnlock(t, map[string]string{keysFileEnv: keysFile})

	if result.code != 1 {
		t.Fatalf("exit code = %d, want 1", result.code)
	}
	if !strings.Contains(result.stderr, workKey+" is not a signing-capable secret key") {
		t.Fatalf("stderr = %q, want the rejected key", result.stderr)
	}
	if after := fileHash(t, keysFile); after != before {
		t.Fatalf("key list hash = %s, want %s", after, before)
	}
}

func TestGPGUnlockDefaultKeysFileStatErrorIsReported(t *testing.T) {
	setupFakeTools(t, personalKey)
	log := filepath.Join(t.TempDir(), "gpg-calls")
	configHome := t.TempDir()
	rendered := filepath.Join(configHome, "sops-nix", "secrets", "rendered")
	if err := os.MkdirAll(rendered, 0o700); err != nil {
		t.Fatal(err)
	}
	loop := filepath.Join(rendered, "gpg-unlock-keys")
	if err := os.Symlink(loop, loop); err != nil {
		t.Fatal(err)
	}
	fixture := filepath.Join(t.TempDir(), "keys")
	writeKeysFile(t, fixture, workKey+"\n")
	before := fileHash(t, fixture)

	result := runGPGUnlock(t, map[string]string{
		"XDG_CONFIG_HOME": configHome,
		"GPG_TEST_LOG":    log,
	})

	if result.code != 1 {
		t.Fatalf("exit code = %d, want 1 (stderr: %s)", result.code, result.stderr)
	}
	if !strings.HasPrefix(result.stderr, "gpg-unlock: reading key list: ") {
		t.Fatalf("stderr = %q, want the key list error", result.stderr)
	}
	if result.stdout != "" {
		t.Fatalf("stdout = %q, want empty", result.stdout)
	}
	if _, err := os.Stat(log); !os.IsNotExist(err) {
		t.Fatalf("gpg was called for an unreadable key list, log: %v", err)
	}
	if after := fileHash(t, fixture); after != before {
		t.Fatalf("fixture hash = %s, want %s", after, before)
	}
	info, err := os.Lstat(loop)
	if err != nil || info.Mode()&os.ModeSymlink == 0 {
		t.Fatalf("default key list symlink changed: %v", err)
	}
}
