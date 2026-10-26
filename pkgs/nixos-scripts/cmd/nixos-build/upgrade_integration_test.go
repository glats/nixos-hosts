package main

import (
	"crypto/sha256"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestUpgradeCLI(t *testing.T) {
	if os.Getenv("NIXOS_BUILD_TEST_CHILD") == "1" {
		os.Args = []string{"nixos-build", os.Getenv("PROBE_COMMAND")}
		main()
		return
	}
	for _, tc := range []struct {
		name, command, npmCode, nixCode string
		code                            int
		calls, stderr                   string
		changed                         bool
	}{
		{"rejected", "invalid", "0", "0", 1, "", "", false},
		{"npm failure", "upgrade", "9", "0", 9, "npm\n", "native-npm-error\n", false},
		{"flake failure", "upgrade", "0", "7", 7, "npm\nnix\n", "native-nix-error\n", true},
		{"success", "upgrade", "0", "0", 0, "npm\nnix\n", "", true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			root, bin := filepath.Join(dir, "repo with spaces"), filepath.Join(dir, "bin")
			write := func(path, data string, mode os.FileMode) {
				t.Helper()
				if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(path, []byte(data), mode); err != nil {
					t.Fatal(err)
				}
			}
			locks := []string{"flake.lock", "pkgs/opencode-npm-packages-v2/package-lock.json", "pkgs/browsermcp-v2/package-lock.json"}
			for _, path := range locks {
				write(filepath.Join(root, path), "original", 0644)
			}
			write(filepath.Join(bin, "npm"), "#!/bin/sh\necho npm >> \"$CALL_LOG\"\nif [ \"$NPM_CODE\" != 0 ]; then echo native-npm-error >&2; exit \"$NPM_CODE\"; fi\n[ \"$1\" = update ] && [ \"$2\" = --prefix ] && [ \"$3\" = \"$NIXOS_REPO/pkgs/browsermcp-v2\" ] || exit 98\nprintf updated > \"$3/package-lock.json\"\n", 0755)
			write(filepath.Join(bin, "nix"), "#!/bin/sh\necho nix >> \"$CALL_LOG\"\nif [ \"$NIX_CODE\" != 0 ]; then echo native-nix-error >&2; exit \"$NIX_CODE\"; fi\n", 0755)
			cmd := exec.Command(os.Args[0], "-test.run=^TestUpgradeCLI$")
			cmd.Dir = root
			cmd.Env = append(os.Environ(), "NIXOS_BUILD_TEST_CHILD=1", "PROBE_COMMAND="+tc.command, "NIXOS_REPO="+root, "PATH="+bin, "CALL_LOG="+filepath.Join(dir, "calls"), "NPM_CODE="+tc.npmCode, "NIX_CODE="+tc.nixCode)
			var stdout, stderr strings.Builder
			cmd.Stdout, cmd.Stderr = &stdout, &stderr
			err := cmd.Run()
			code := 0
			if exit, ok := err.(*exec.ExitError); ok {
				code = exit.ExitCode()
			} else if err != nil {
				t.Fatal(err)
			}
			if code != tc.code || stderr.String() != tc.stderr {
				t.Fatalf("code=%d stderr=%q stdout=%q", code, stderr.String(), stdout.String())
			}
			calls, err := os.ReadFile(filepath.Join(dir, "calls"))
			if err != nil && !os.IsNotExist(err) {
				t.Fatal(err)
			}
			if string(calls) != tc.calls {
				t.Fatalf("calls = %q, want %q", calls, tc.calls)
			}
			for _, path := range locks {
				data, err := os.ReadFile(filepath.Join(root, path))
				if err != nil {
					t.Fatal(err)
				}
				want := "original"
				if tc.changed && strings.Contains(path, "browsermcp") {
					want = "updated"
				}
				if sha256.Sum256(data) != sha256.Sum256([]byte(want)) {
					t.Fatalf("unexpected mutation %s: %q", path, data)
				}
			}
			if tc.command == "invalid" && stdout.String() != "Unknown command: invalid\nRun 'nixos-build help' for usage\n" {
				t.Fatal(stdout.String())
			}
		})
	}
}
