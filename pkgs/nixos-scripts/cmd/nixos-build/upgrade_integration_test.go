package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/glats/nixos-scripts/internal/nixbuild"
)

const (
	manifestBefore = "{\n  \"dependencies\": {\n    \"@opencode/plugin\": \"2.0.14\",\n    \"effect\": \"4.0.0-rc.112\"\n  }\n}\n"
	manifestAfter  = "{\n  \"dependencies\": {\n    \"@opencode/plugin\": \"2.2.1\",\n    \"effect\": \"4.0.1\"\n  }\n}\n"
	nixBefore      = "{\n  version = \"2.0.14\";\n  url = \"https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-${version}.tgz\";\n  hash = \"sha512-old\";\n}\n"
	nixAfter       = "{\n  version = \"2.2.1\";\n  url = \"https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-${version}.tgz\";\n  hash = \"sha512-new\";\n}\n"
)

// Count the `nix run nixpkgs#nix-update` steps of the upgrade plan for the
// platform running the test, mirroring sourceUpdates' darwin branching.
func upgradeNixRunCount() int {
	darwin := runtime.GOOS == "darwin"
	count := 0
	for _, step := range nixbuild.Steps(nixbuild.Env{Darwin: darwin}, "upgrade") {
		if step.Kind == nixbuild.KindExec && len(step.Args) >= 2 && step.Args[0] == "nix" && step.Args[1] == "run" {
			count++
		}
	}
	return count
}

func TestUpgradeCLI(t *testing.T) {
	if os.Getenv("NIXOS_BUILD_TEST_CHILD") == "1" {
		logCall := func(name string) func(string) error {
			return func(root string) error {
				f, err := os.OpenFile(os.Getenv("CALL_LOG"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
				if err != nil {
					return err
				}
				defer f.Close()
				_, err = f.WriteString(name + " " + root + "\n")
				return err
			}
		}
		nixbuild.UpdateReleasePins = logCall("releasepins")
		nixbuild.UpdateFlakePins = logCall("flakepins")
		nixbuild.UpdateQuotaPlugin = logCall("quota")
		os.Args = []string{"nixos-build", os.Getenv("PROBE_COMMAND")}
		main()
		return
	}
	registry := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/@opencode/plugin/latest":
			_, _ = w.Write([]byte(`{"version":"2.2.1","dependencies":{"effect":"4.0.1"}}`))
		case "/@opencode/plugin/2.2.1":
			_, _ = w.Write([]byte(`{"version":"2.2.1"}`))
		case "/@opencode/cli-linux-x64/2.2.1":
			_, _ = w.Write([]byte(`{"version":"2.2.1","dist":{"integrity":"sha512-new"}}`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer registry.Close()
	broken := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "down", http.StatusInternalServerError)
	}))
	defer broken.Close()

	for _, tc := range []struct {
		name, command, registry, npmCode, nixCode string
		code                                      int
		calls, stderr                             string
		sourcesUpdated, locksUpdated              bool
	}{
		{"rejected", "invalid", registry.URL, "0", "0", 1, "", "", false, false},
		{"opencode failure", "upgrade", broken.URL, "0", "0", 1, "", "ERROR: @opencode/plugin@latest: registry returned 500 Internal Server Error\n", false, false},
		{"npm failure", "upgrade", registry.URL, "9", "0", 9, "npm\n", "native-npm-error\n", true, false},
		{"flake failure", "upgrade", registry.URL, "0", "7", 7, "npm\nnpm\nquota ROOT\nreleasepins ROOT\nflakepins ROOT\nnix flake\n", "native-nix-error\n", true, true},
		{"success", "upgrade", registry.URL, "0", "0", 0, "npm\nnpm\nquota ROOT\nreleasepins ROOT\nflakepins ROOT\nnix flake\n" + strings.Repeat("nix run /repo\n", upgradeNixRunCount()), "", true, true},
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
			read := func(rel string) string {
				t.Helper()
				data, err := os.ReadFile(filepath.Join(root, rel))
				if err != nil {
					t.Fatal(err)
				}
				return string(data)
			}
			write(filepath.Join(root, "flake.lock"), "original", 0644)
			write(filepath.Join(root, "pkgs/opencode-npm-packages-v2/package.json"), manifestBefore, 0644)
			write(filepath.Join(root, "pkgs/opencode/default.nix"), nixBefore, 0644)
			for _, path := range []string{"pkgs/opencode-npm-packages-v2/package-lock.json", "pkgs/browsermcp-v2/package-lock.json"} {
				write(filepath.Join(root, path), "original", 0644)
			}
			write(filepath.Join(bin, "npm"), "#!/bin/sh\necho npm >> \"$CALL_LOG\"\nif [ \"$NPM_CODE\" != 0 ]; then echo native-npm-error >&2; exit \"$NPM_CODE\"; fi\ncase \"$1\" in\n  install) [ \"$2\" = --prefix ] && [ \"$4\" = --package-lock-only ] && [ \"$5\" = --save-exact ] || exit 97\n    case \"$3\" in\n      \"$NIXOS_REPO/pkgs/opencode-npm-packages-v2\") ;;\n      \"$NIXOS_REPO/pkgs/browsermcp-v2\") [ \"$8\" = @browsermcp/mcp@latest ] || exit 98 ;;\n      *) exit 99 ;;\n    esac ;;\n  *) exit 99 ;;\nesac\nprintf updated > \"$3/package-lock.json\"\n", 0755)
			write(filepath.Join(bin, "nix"), "#!/bin/sh\ncase \"$1\" in\n  flake) echo nix flake >> \"$CALL_LOG\" ;;\n  run) [ \"$PWD\" = \"$NIXOS_REPO\" ] || exit 96; echo nix run /repo >> \"$CALL_LOG\" ;;\n  *) exit 95 ;;\nesac\nif [ \"$NIX_CODE\" != 0 ]; then echo native-nix-error >&2; exit \"$NIX_CODE\"; fi\n", 0755)
			cmd := exec.Command(os.Args[0], "-test.run=^TestUpgradeCLI$")
			cmd.Dir = dir
			cmd.Env = append(os.Environ(), "NIXOS_BUILD_TEST_CHILD=1", "PROBE_COMMAND="+tc.command, "NIXOS_REPO="+root, "PATH="+bin, "CALL_LOG="+filepath.Join(dir, "calls"), "NPM_CODE="+tc.npmCode, "NIX_CODE="+tc.nixCode, "NPM_CONFIG_REGISTRY="+tc.registry)
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
			if want := strings.ReplaceAll(tc.calls, "ROOT", root); string(calls) != want {
				t.Fatalf("calls = %q, want %q", calls, want)
			}
			wantManifest, wantNix := manifestBefore, nixBefore
			if tc.sourcesUpdated {
				wantManifest, wantNix = manifestAfter, nixAfter
			}
			if got := read("pkgs/opencode-npm-packages-v2/package.json"); got != wantManifest {
				t.Fatalf("manifest = %q, want %q", got, wantManifest)
			}
			if got := read("pkgs/opencode/default.nix"); got != wantNix {
				t.Fatalf("executable = %q, want %q", got, wantNix)
			}
			wantLock := "original"
			if tc.locksUpdated {
				wantLock = "updated"
			}
			for _, path := range []string{"pkgs/opencode-npm-packages-v2/package-lock.json", "pkgs/browsermcp-v2/package-lock.json"} {
				if got := read(path); got != wantLock {
					t.Fatalf("%s = %q, want %q", path, got, wantLock)
				}
			}
			if got := read("flake.lock"); got != "original" {
				t.Fatalf("flake.lock = %q", got)
			}
			if tc.command == "invalid" && stdout.String() != "Unknown command: invalid\nRun 'nixos-build help' for usage\n" {
				t.Fatal(stdout.String())
			}
		})
	}
}
