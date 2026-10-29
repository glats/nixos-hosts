package opencodeupdate

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const manifestFixture = `{
  "name": "opencode-npm-packages-v2",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@ai-sdk/provider": "3.0.8",
    "@opencode/ai": "2.0.14",
    "@opencode/plugin": "2.0.14",
    "@opencode/schema": "2.0.14",
    "@standard-schema/spec": "1.0.0",
    "effect": "4.0.0-rc.112",
    "zod": "4.1.8"
  }
}
`

const executableFixture = `{
  version = "2.0.14";
  platformSrc = {
    x86_64-linux = {
      url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
      hash = "sha512-old-linux-x64";
    };
    aarch64-darwin = {
      url = "https://registry.npmjs.org/@opencode/cli-darwin-arm64/-/cli-darwin-arm64-${version}.tgz";
      hash = "sha512-old-darwin-arm64";
    };
  };
}
`

func fixtureRoot(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	for path, data := range map[string]string{
		"pkgs/opencode-npm-packages-v2/package.json": manifestFixture,
		"pkgs/opencode/default.nix":                  executableFixture,
	} {
		full := filepath.Join(root, path)
		if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(full, []byte(data), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return root
}

func registry(t *testing.T, missing string) *httptest.Server {
	t.Helper()
	meta := map[string]map[string]any{
		"/@opencode/plugin/latest":          {"version": "2.2.1", "dependencies": map[string]string{"effect": "4.0.1", "@ai-sdk/provider": "3.0.9"}},
		"/@opencode/schema/2.2.1":           {"version": "2.2.1", "dependencies": map[string]string{"@standard-schema/spec": "1.1.0"}},
		"/@opencode/ai/2.2.1":               {"version": "2.2.1"},
		"/@opencode/plugin/2.2.1":           {"version": "2.2.1"},
		"/@opencode/cli-linux-x64/2.2.1":    {"version": "2.2.1", "dist": map[string]string{"integrity": "sha512-new-linux-x64"}},
		"/@opencode/cli-darwin-arm64/2.2.1": {"version": "2.2.1", "dist": map[string]string{"integrity": "sha512-new-darwin-arm64"}},
	}
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == missing {
			http.NotFound(w, r)
			return
		}
		body, ok := meta[r.URL.Path]
		if !ok {
			http.NotFound(w, r)
			return
		}
		_ = json.NewEncoder(w).Encode(body)
	}))
}

func read(t *testing.T, root, rel string) string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(root, rel))
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func TestUpdateAdvancesExecutableAndClosureTogether(t *testing.T) {
	srv := registry(t, "")
	defer srv.Close()
	root := fixtureRoot(t)

	if err := Update(root, srv.URL, srv.Client()); err != nil {
		t.Fatal(err)
	}

	wantManifest := strings.NewReplacer(
		`"@ai-sdk/provider": "3.0.8"`, `"@ai-sdk/provider": "3.0.9"`,
		`"@opencode/ai": "2.0.14"`, `"@opencode/ai": "2.2.1"`,
		`"@opencode/plugin": "2.0.14"`, `"@opencode/plugin": "2.2.1"`,
		`"@opencode/schema": "2.0.14"`, `"@opencode/schema": "2.2.1"`,
		`"@standard-schema/spec": "1.0.0"`, `"@standard-schema/spec": "1.1.0"`,
		`"effect": "4.0.0-rc.112"`, `"effect": "4.0.1"`,
	).Replace(manifestFixture)
	if got := read(t, root, "pkgs/opencode-npm-packages-v2/package.json"); got != wantManifest {
		t.Fatalf("manifest =\n%s\nwant\n%s", got, wantManifest)
	}
	wantExecutable := strings.NewReplacer(
		`version = "2.0.14"`, `version = "2.2.1"`,
		"sha512-old-linux-x64", "sha512-new-linux-x64",
		"sha512-old-darwin-arm64", "sha512-new-darwin-arm64",
	).Replace(executableFixture)
	if got := read(t, root, "pkgs/opencode/default.nix"); got != wantExecutable {
		t.Fatalf("executable =\n%s\nwant\n%s", got, wantExecutable)
	}
}

func TestUpdateIsIdempotent(t *testing.T) {
	srv := registry(t, "")
	defer srv.Close()
	root := fixtureRoot(t)
	for range 2 {
		if err := Update(root, srv.URL, srv.Client()); err != nil {
			t.Fatal(err)
		}
	}
	first := read(t, root, "pkgs/opencode/default.nix")
	if err := Update(root, srv.URL, srv.Client()); err != nil {
		t.Fatal(err)
	}
	if read(t, root, "pkgs/opencode/default.nix") != first {
		t.Fatal("second run changed executable")
	}
}

func TestUpdateLeavesFilesUntouchedWhenRegistryIsIncomplete(t *testing.T) {
	srv := registry(t, "/@opencode/cli-darwin-arm64/2.2.1")
	defer srv.Close()
	root := fixtureRoot(t)

	err := Update(root, srv.URL, srv.Client())
	if err == nil || !strings.Contains(err.Error(), "cli-darwin-arm64") {
		t.Fatalf("err = %v, want missing cli-darwin-arm64", err)
	}
	if read(t, root, "pkgs/opencode-npm-packages-v2/package.json") != manifestFixture ||
		read(t, root, "pkgs/opencode/default.nix") != executableFixture {
		t.Fatal("files changed after failed update")
	}
}
