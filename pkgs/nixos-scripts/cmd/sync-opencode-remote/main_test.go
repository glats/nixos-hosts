package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestRemoteV2PreflightRejectsUnavailableRuntime(t *testing.T) {
	root := t.TempDir()
	for _, content := range []string{"", `{"agent":{}}`, `{"agents":{}}`} {
		config := filepath.Join(root, "opencode.json")
		if content == "" {
			_ = os.Remove(config)
		} else if err := os.WriteFile(config, []byte(content), 0o600); err != nil {
			t.Fatal(err)
		}
		if err := validateV2Runtime(root); err == nil {
			t.Fatalf("accepted incomplete V2 root with %q", content)
		}
		if _, err := os.Stat(filepath.Join(root, ".bak")); !os.IsNotExist(err) {
			t.Fatalf("preflight wrote backup: %v", err)
		}
	}
}

func TestValidateV2RuntimeRejectsNonV2NamespaceBeforeReading(t *testing.T) {
	if err := validateV2Runtime(filepath.Join(t.TempDir(), "opencode")); err == nil || !strings.Contains(err.Error(), "opencode-v2 namespace") {
		t.Fatalf("legacy namespace error = %v", err)
	}
}

func TestValidateV2RuntimeRequiresIsolatedEnvironment(t *testing.T) {
	home := t.TempDir()
	root := filepath.Join(home, ".config", "opencode-v2")
	if err := os.MkdirAll(root, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "opencode.json"), []byte(`{"default_agent":"default","agents":{"default":{"mode":"primary"}}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := validateV2Runtime(root); err == nil {
		t.Fatal("accepted missing isolated environment")
	}
	envDir := filepath.Join(home, ".local", "share", "opencode-v2")
	if err := os.MkdirAll(envDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(envDir, "environment"), []byte(validEnvironment(home, root)), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := validateV2Runtime(root); err != nil {
		t.Fatalf("rejected valid isolated runtime: %v", err)
	}
}

func TestEnvironmentRejectsCommentOnlyStaleAndLegacyContracts(t *testing.T) {
	home := t.TempDir()
	root := filepath.Join(home, ".config", "opencode-v2")
	if err := os.MkdirAll(root, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "opencode.json"), []byte(`{"agents":{"default":{"mode":"primary"}},"default_agent":"default"}`), 0o600); err != nil {
		t.Fatal(err)
	}
	envPath := filepath.Join(home, ".local", "share", "opencode-v2", "environment")
	if err := os.MkdirAll(filepath.Dir(envPath), 0o755); err != nil {
		t.Fatal(err)
	}
	for _, contents := range []string{"# OPENCODE_CONFIG_DIR=opencode-v2\n", strings.Replace(validEnvironment(home, root), "export OPENCODE_DB=", "export XDG_DATA_HOME=", 1), strings.Replace(validEnvironment(home, root), ".local/share/opencode-v2", ".local/share/opencode", 1)} {
		if err := os.WriteFile(envPath, []byte(contents), 0o600); err != nil {
			t.Fatal(err)
		}
		if err := validateV2Runtime(root); err == nil {
			t.Fatalf("accepted stale/legacy environment %q", contents)
		}
	}
}

func TestEnvironmentAcceptsCoherentCustomRuntimeRoot(t *testing.T) {
	home := filepath.Join(t.TempDir(), "home with ' quote")
	root := filepath.Join(home, ".config", "opencode-v2")
	runtimeRoot := filepath.Join(t.TempDir(), "custom runtime ' root")
	contents := validEnvironmentAt(home, root, runtimeRoot)
	if err := validateEnvironmentFile(contents, root, home); err != nil {
		t.Fatalf("custom runtime root rejected: %v", err)
	}
}

func TestEnvironmentAcceptsNixEscapeShellArgGeneratedLiteralForms(t *testing.T) {
	home := t.TempDir()
	root := filepath.Join(home, ".config", "opencode-v2")
	plain := validEnvironmentAt(home, root, filepath.Join(home, ".local", "opencode-v2"))
	if !strings.Contains(plain, "export OPENCODE_CONFIG_DIR="+root+"\n") || !strings.Contains(plain, "export OPENCODE_DISABLE_PROJECT_CONFIG=1\n") {
		t.Fatalf("fixture does not match lib.escapeShellArg safe literals:\n%s", plain)
	}
	if err := validateEnvironmentFile(plain, root, home); err != nil {
		t.Fatalf("Nix-generated safe literal rejected: %v", err)
	}
	quotedHome := filepath.Join(t.TempDir(), "home with ' apostrophe")
	quotedRoot := filepath.Join(quotedHome, ".config", "opencode-v2")
	quoted := validEnvironmentAt(quotedHome, quotedRoot, filepath.Join(t.TempDir(), "runtime with ' apostrophe"))
	if err := validateEnvironmentFile(quoted, quotedRoot, quotedHome); err != nil {
		t.Fatalf("Nix-generated quoted literal rejected: %v", err)
	}
}

func TestEnvironmentRejectsUnquotedShellInjection(t *testing.T) {
	home := t.TempDir()
	root := filepath.Join(home, ".config", "opencode-v2")
	contents := strings.Replace(validEnvironment(home, root), "export XDG_CACHE_HOME=", "export XDG_CACHE_HOME=$(touch /tmp/opencode-sync-pwn); ", 1)
	if err := validateEnvironmentFile(contents, root, home); err == nil {
		t.Fatal("accepted active shell syntax")
	}
}

func TestTransferSensitiveExclusionsWinBeforeRecursiveIncludes(t *testing.T) {
	args := transferArgs("/local", "/home/user/.config/opencode-v2", "user@host", false)
	cases := []struct {
		path         string
		wantExcluded bool
	}{
		{"plugins/auth.json", true}, {"plugins/cache.db", true}, {"plugins/session.sqlite", true},
		{"plugins/session.db-wal", true}, {"plugins/credentials.json", true}, {"plugins/nested/token.json", true},
		{"plugins/.env", true}, {"plugins/.env.production", true}, {"plugins/provider.key", true}, {"plugins/managed.ts", false},
		{"skills/tool/SKILL.md", false}, {"commands/run.md", false},
	}
	for _, tc := range cases {
		if got := firstMatchExcluded(args, tc.path); got != tc.wantExcluded {
			t.Errorf("%s excluded=%v want %v; args=%v", tc.path, got, tc.wantExcluded, args)
		}
	}
}

func validEnvironment(home, configRoot string) string {
	runtime := filepath.Join(home, ".local", "share", "opencode-v2")
	return validEnvironmentAt(home, configRoot, runtime)
}

func validEnvironmentAt(home, configRoot, runtime string) string {
	values := map[string]string{
		"XDG_CONFIG_HOME": configRoot, "XDG_DATA_HOME": filepath.Join(runtime, "data"),
		"XDG_CACHE_HOME": filepath.Join(runtime, "cache"), "XDG_STATE_HOME": filepath.Join(runtime, "state"),
		"OPENCODE_CONFIG_DIR": configRoot, "OPENCODE_DB": filepath.Join(runtime, "data", "opencode.db"),
		"TMPDIR": filepath.Join(runtime, "tmp"), "OPENCODE_DISABLE_PROJECT_CONFIG": "1",
	}
	var lines []string
	for _, key := range []string{"XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "OPENCODE_CONFIG_DIR", "OPENCODE_DB", "TMPDIR", "OPENCODE_DISABLE_PROJECT_CONFIG"} {
		lines = append(lines, "export "+key+"="+nixEscapeShellArgFixture(values[key]))
	}
	lines = append(lines, "export PATH='/nix/profile/bin:/run/current-system/sw/bin'")
	return strings.Join(lines, "\n") + "\n"
}

func nixEscapeShellArgFixture(value string) string {
	for _, r := range value {
		if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || strings.ContainsRune("_./:-", r)) {
			return shellQuote(value)
		}
	}
	return value
}

func firstMatchExcluded(args []string, path string) bool {
	for _, arg := range args {
		var pattern string
		switch {
		case strings.HasPrefix(arg, "--exclude="):
			pattern = strings.TrimPrefix(arg, "--exclude=")
		case strings.HasPrefix(arg, "--include="):
			pattern = strings.TrimPrefix(arg, "--include=")
		default:
			continue
		}
		matched, _ := filepath.Match(pattern, path)
		if strings.HasPrefix(pattern, "**/") {
			matched, _ = filepath.Match(strings.TrimPrefix(pattern, "**/"), filepath.Base(path))
		} else if !strings.Contains(pattern, "/") {
			matched, _ = filepath.Match(pattern, filepath.Base(path))
		}
		if matched {
			return strings.HasPrefix(arg, "--exclude=")
		}
	}
	return false
}

func TestPreflightFailurePreventsBackupAndTransfer(t *testing.T) {
	backupCalls, transferCalls := 0, 0
	err := runAfterPreflight(func() error { return os.ErrNotExist }, func() error { backupCalls++; return nil }, func() error { transferCalls++; return nil })
	if err == nil || backupCalls != 0 || transferCalls != 0 {
		t.Fatalf("err=%v backup=%d transfer=%d", err, backupCalls, transferCalls)
	}
}

func TestRemotePreflightRequiresUsableTargetAndDestinationEnvironment(t *testing.T) {
	home := filepath.Join(t.TempDir(), "remote home ' quote")
	if err := os.MkdirAll(home, 0o755); err != nil {
		t.Fatal(err)
	}
	root := filepath.Join(home, ".config", "opencode-v2")
	if err := os.MkdirAll(root, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "opencode.json"), []byte(`{"default_agent":"default","agents":{"default":{}}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	envDir := filepath.Join(home, ".local", "share", "opencode-v2")
	if err := os.MkdirAll(envDir, 0o755); err != nil {
		t.Fatal(err)
	}
	envFile := filepath.Join(envDir, "environment")
	if err := os.WriteFile(envFile, []byte(validEnvironment(home, root)), 0o600); err != nil {
		t.Fatal(err)
	}
	bin := filepath.Join(home, "bin")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		t.Fatal(err)
	}
	jq, err := exec.LookPath("jq")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(jq, filepath.Join(bin, "jq")); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"awk", "sed", "bash"} {
		target, err := exec.LookPath(name)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(target, filepath.Join(bin, name)); err != nil {
			t.Fatal(err)
		}
	}
	command := remotePreflightCommand(root)
	run := func() error {
		cmd := exec.Command("bash", "-c", command)
		cmd.Env = append(os.Environ(), "HOME="+home, "PATH="+bin)
		cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
		return cmd.Run()
	}
	if err := run(); err == nil {
		t.Fatal("preflight accepted missing opencode2")
	}
	if err := os.WriteFile(filepath.Join(bin, "opencode2"), []byte("#!/bin/sh\necho 'opencode v2.0.14'\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := run(); err != nil {
		t.Fatalf("valid destination runtime rejected: %v", err)
	}
	if err := os.WriteFile(filepath.Join(bin, "opencode2"), []byte("#!/bin/sh\necho 'opencode v1.18.18'\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := run(); err == nil {
		t.Fatal("preflight accepted stale V1 executable")
	}
	if err := os.WriteFile(filepath.Join(bin, "opencode2"), []byte("#!/bin/sh\necho 'opencode v2.0.14'\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(envFile, []byte(strings.Replace(validEnvironment(home, root), "XDG_CACHE_HOME", "XDG_DATA_HOME", 1)), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := run(); err == nil {
		t.Fatal("preflight accepted mismatched destination environment")
	}
	if err := os.WriteFile(envFile, []byte("# OPENCODE_CONFIG_DIR=opencode-v2\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := run(); err == nil {
		t.Fatal("preflight accepted comment-only environment")
	}
}

func TestRemotePathsAreQuotedAndTransferIsAssetsOnly(t *testing.T) {
	root := resolveRemoteRoot("/home/user with spaces/.config/opencode-v2")
	if root != "/home/user with spaces/.config/opencode-v2" {
		t.Fatalf("root = %q", root)
	}
	command := remotePreflightScript("/home/u/$(touch pwn)'x")
	if !strings.Contains(command, "root="+shellQuote("/home/u/$(touch pwn)'x")) {
		t.Fatalf("unsafe remote preflight root: %s", command)
	}
	args := strings.Join(transferArgs("/local", root, "user@host", false), "\n")
	for _, want := range []string{"skills/**", "commands/**", "plugins/**", "--exclude=auth.json", "--exclude=*.db", "--exclude=*.sqlite*"} {
		if !strings.Contains(args, want) {
			t.Fatalf("transfer args omit %q: %s", want, args)
		}
	}
	for _, forbidden := range []string{"--delete", "npm install", "providerRename", "--include=package.json"} {
		if strings.Contains(args, forbidden) {
			t.Fatalf("transfer includes forbidden operation %q", forbidden)
		}
	}
}
