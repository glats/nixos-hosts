package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestNativeConfigValidation(t *testing.T) {
	home := t.TempDir()
	root := filepath.Join(home, ".config", "opencode")
	if err := os.MkdirAll(root, 0755); err != nil {
		t.Fatal(err)
	}
	config := filepath.Join(root, "opencode.json")
	if err := os.WriteFile(config, []byte(`{"default_agent":"default","agents":{"default":{}}}`), 0600); err != nil {
		t.Fatal(err)
	}
	if err := validateNativeConfig(root); err != nil {
		t.Fatal(err)
	}
	if err := validateNativeConfig(filepath.Join(home, ".config", "elsewhere")); err == nil {
		t.Fatal("accepted non-native root")
	}
}

func TestTransferSensitiveExclusionsWinBeforeRecursiveIncludes(t *testing.T) {
	args := transferArgs("/local", "/home/user/.config/opencode", "user@host", false)
	for _, path := range []string{"plugins/auth.json", "plugins/cache.db", "plugins/session.sqlite", "plugins/session.db-wal", "plugins/credentials.json", "plugins/nested/token.json", "plugins/.env", "plugins/provider.key"} {
		if !firstMatchExcluded(args, path) {
			t.Errorf("%s was not excluded", path)
		}
	}
	for _, path := range []string{"plugins/managed.ts", "skills/tool/SKILL.md", "commands/run.md"} {
		if firstMatchExcluded(args, path) {
			t.Errorf("%s was excluded", path)
		}
	}
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

func TestRemotePreflightUsesNativeRootAndQuotesPaths(t *testing.T) {
	root := "/home/user with spaces/.config/opencode"
	script := remotePreflightScript(root)
	if !strings.Contains(script, "$home/.config/opencode") || !strings.Contains(script, "command -v opencode") || !strings.Contains(script, "opencode v2.") {
		t.Fatalf("missing native preflight contract: %s", script)
	}
	command := remotePreflightCommand("/home/u/$(touch pwn)'x")
	unsafe := remotePreflightScript("/home/u/$(touch pwn)'x")
	if !strings.Contains(unsafe, "root="+shellQuote("/home/u/$(touch pwn)'x")) || command == "" {
		t.Fatalf("unsafe root not quoted: %s", unsafe)
	}
	if got := resolveRemoteRoot(root); got != root {
		t.Fatalf("root = %q", got)
	}
}

func TestPreflightFailurePreventsBackupAndTransfer(t *testing.T) {
	backupCalls, transferCalls := 0, 0
	err := runAfterPreflight(func() error { return os.ErrNotExist }, func() error { backupCalls++; return nil }, func() error { transferCalls++; return nil })
	if err == nil || backupCalls != 0 || transferCalls != 0 {
		t.Fatalf("err=%v backup=%d transfer=%d", err, backupCalls, transferCalls)
	}
}
