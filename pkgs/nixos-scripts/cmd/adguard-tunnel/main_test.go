package main

import (
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestCLI(t *testing.T) {
	dir := t.TempDir()
	binary := filepath.Join(dir, "adguard-tunnel")
	build := exec.Command("go", "build", "-o", binary, ".")
	if output, err := build.CombinedOutput(); err != nil {
		t.Fatalf("build: %v\n%s", err, output)
	}
	ssh := "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$SSH_ARGS\"\n"
	if err := os.WriteFile(filepath.Join(dir, "ssh"), []byte(ssh), 0700); err != nil {
		t.Fatal(err)
	}
	key := filepath.Join(dir, "test-key")
	if err := os.WriteFile(key, nil, 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("HOME", dir)
	argsPath := filepath.Join(dir, "args")
	t.Setenv("SSH_ARGS", argsPath)
	for _, tt := range []struct {
		name string
		args []string
		want string
	}{
		{"defaults", nil, "-N\n-L\n127.0.0.1:3000:127.0.0.1:3000\nglats@samsung.lan\n"},
		{"overrides", []string{"-host", "other.lan", "-user", "operator", "-key", key, "-local", "13001", "-port", "8443"}, "-i\n" + key + "\n-N\n-L\n127.0.0.1:13001:127.0.0.1:8443\noperator@other.lan\n"},
	} {
		t.Run(tt.name, func(t *testing.T) {
			output, err := exec.Command(binary, tt.args...).CombinedOutput()
			if err != nil {
				t.Fatalf("CLI: %v\n%s", err, output)
			}
			got, err := os.ReadFile(argsPath)
			if err != nil {
				t.Fatal(err)
			}
			if string(got) != tt.want {
				t.Fatalf("SSH args = %q, want %q", got, tt.want)
			}
			if !strings.Contains(string(output), "tunnel up: http://127.0.0.1:") || !strings.Contains(string(output), "tunnel stopped.") {
				t.Fatalf("unexpected output: %s", output)
			}
		})
	}
	t.Run("missing explicit key", func(t *testing.T) {
		output, err := exec.Command(binary, "-key", filepath.Join(dir, "missing")).CombinedOutput()
		if err == nil || !strings.Contains(string(output), "SSH key") {
			t.Fatalf("missing key: err=%v output=%s", err, output)
		}
	})
	t.Run("busy local port", func(t *testing.T) {
		listener, err := net.Listen("tcp4", "127.0.0.1:3000")
		if err != nil {
			t.Skipf("port 3000 unavailable: %v", err)
		}
		defer listener.Close()
		output, err := exec.Command(binary, "-key", key).CombinedOutput()
		if err != nil || !strings.Contains(string(output), "using fallback port 13000") {
			t.Fatalf("fallback: err=%v output=%s", err, output)
		}
	})
}
