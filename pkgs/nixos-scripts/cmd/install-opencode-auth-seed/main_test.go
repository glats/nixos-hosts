package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestLegacySeedRefusesBeforeExternalIO(t *testing.T) {
	home := t.TempDir()
	bin := t.TempDir()
	marker := filepath.Join(home, "external-command-ran")
	for _, name := range []string{"curl", "age", "jq", "cp"} {
		path := filepath.Join(bin, name)
		if err := os.WriteFile(path, []byte("#!/bin/sh\ntouch '"+marker+"'\n"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	for _, args := range [][]string{nil, {"--v2"}, {"--seed-url", "invalid"}, {"--seed-url", "https://example.invalid", "--v2"}, {"--auth-file", "/must-not-read", "--key-file", "/must-not-read"}} {
		auth := filepath.Join(home, "auth.json")
		backup := auth + ".bak.existing"
		for path, content := range map[string][]byte{auth: []byte("fixture-auth"), backup: []byte("fixture-backup")} {
			if err := os.WriteFile(path, content, 0o600); err != nil {
				t.Fatal(err)
			}
		}
		cmd := exec.Command("go", append([]string{"run", "."}, args...)...)
		cmd.Dir = "."
		cmd.Env = []string{"HOME=" + home, "AUTH_FILE=" + auth, "KEY_FILE=" + filepath.Join(home, "age-key"), "PATH=" + bin + ":/usr/bin:/bin", "GOCACHE=" + filepath.Join(home, "cache")}
		output, err := cmd.CombinedOutput()
		if err == nil {
			t.Fatalf("args %q were accepted", args)
		}
		if !strings.Contains(string(output), "opencode2-home auth login openai") {
			t.Fatalf("args %q: missing native-login guidance: %s", args, output)
		}
		for path, want := range map[string]string{auth: "fixture-auth", backup: "fixture-backup"} {
			got, err := os.ReadFile(path)
			if err != nil || string(got) != want {
				t.Fatalf("fixture %s changed: %q (%v)", path, got, err)
			}
		}
	}
	if _, err := os.Stat(marker); !os.IsNotExist(err) {
		t.Fatalf("external command ran: %v", err)
	}
	if _, err := os.Stat(filepath.Join(home, ".local")); !os.IsNotExist(err) {
		t.Fatalf("auth destination touched: %v", err)
	}
}
