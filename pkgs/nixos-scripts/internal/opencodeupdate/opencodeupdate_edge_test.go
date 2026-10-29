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

func serve(meta map[string]map[string]any) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, ok := meta[r.URL.Path]
		if !ok {
			http.NotFound(w, r)
			return
		}
		_ = json.NewEncoder(w).Encode(b)
	}))
}

func snapshot(t *testing.T, root string) string {
	t.Helper()
	return read(t, root, "pkgs/opencode-npm-packages-v2/package.json") + "\x00" + read(t, root, "pkgs/opencode/default.nix")
}

func TestRangeDependencyIsRejectedWithoutChanges(t *testing.T) {
	srv := serve(map[string]map[string]any{
		"/@opencode/plugin/latest":          {"version": "2.2.1", "dependencies": map[string]string{"effect": "^4.0.1"}},
		"/@opencode/schema/2.2.1":           {"version": "2.2.1"},
		"/@opencode/ai/2.2.1":               {"version": "2.2.1"},
		"/@opencode/plugin/2.2.1":           {"version": "2.2.1"},
		"/@opencode/cli-linux-x64/2.2.1":    {"dist": map[string]string{"integrity": "sha512-n"}},
		"/@opencode/cli-darwin-arm64/2.2.1": {"dist": map[string]string{"integrity": "sha512-n"}},
	})
	defer srv.Close()
	root := fixtureRoot(t)
	before := snapshot(t, root)
	if err := Update(root, srv.URL, srv.Client()); err == nil || !strings.Contains(err.Error(), "non-exact") {
		t.Fatalf("err = %v", err)
	}
	if snapshot(t, root) != before {
		t.Fatal("files changed")
	}
}

func TestManifestWithoutSchemaKeyStillUpdates(t *testing.T) {
	srv := serve(map[string]map[string]any{
		"/@opencode/plugin/latest":          {"version": "2.2.1", "dependencies": map[string]string{"effect": "4.0.1"}},
		"/@opencode/plugin/2.2.1":           {"version": "2.2.1"},
		"/@opencode/cli-linux-x64/2.2.1":    {"dist": map[string]string{"integrity": "sha512-n"}},
		"/@opencode/cli-darwin-arm64/2.2.1": {"dist": map[string]string{"integrity": "sha512-n"}},
	})
	defer srv.Close()
	root := t.TempDir()
	manifest := `{"dependencies": {"@opencode/plugin": "2.0.14", "effect": "4.0.0", "zod": "4.1.8"}}` + "\n"
	for p, d := range map[string]string{"pkgs/opencode-npm-packages-v2/package.json": manifest, "pkgs/opencode/default.nix": executableFixture} {
		if err := os.MkdirAll(filepath.Dir(filepath.Join(root, p)), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(root, p), []byte(d), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := Update(root, srv.URL, srv.Client()); err != nil {
		t.Fatal(err)
	}
	want := `{"dependencies": {"@opencode/plugin": "2.2.1", "effect": "4.0.1", "zod": "4.1.8"}}` + "\n"
	if got := read(t, root, "pkgs/opencode-npm-packages-v2/package.json"); got != want {
		t.Fatalf("got %q", got)
	}
}

func TestIncompleteOrMalformedRegistryLeavesFilesUntouched(t *testing.T) {
	for name, missing := range map[string]string{
		"missing linux tarball": "/@opencode/cli-linux-x64/2.2.1",
		"missing ai package":    "/@opencode/ai/2.2.1",
	} {
		t.Run(name, func(t *testing.T) {
			srv := registry(t, missing)
			defer srv.Close()
			root := fixtureRoot(t)
			before := snapshot(t, root)
			if err := Update(root, srv.URL, srv.Client()); err == nil {
				t.Fatal("want error")
			}
			if snapshot(t, root) != before {
				t.Fatal("files changed")
			}
		})
	}
	t.Run("non-json body", func(t *testing.T) {
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte("<html>")) }))
		defer srv.Close()
		root := fixtureRoot(t)
		before := snapshot(t, root)
		if err := Update(root, srv.URL, srv.Client()); err == nil {
			t.Fatal("want error")
		}
		if snapshot(t, root) != before {
			t.Fatal("files changed")
		}
	})
}

func TestLegacySha256ExecutableIsRejectedWithoutChanges(t *testing.T) {
	srv := registry(t, "")
	defer srv.Close()
	root := fixtureRoot(t)
	path := filepath.Join(root, "pkgs/opencode/default.nix")
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(strings.ReplaceAll(string(data), "hash =", "sha256 =")), 0o644); err != nil {
		t.Fatal(err)
	}
	before := snapshot(t, root)
	if err := Update(root, srv.URL, srv.Client()); err == nil {
		t.Fatal("want error")
	}
	if snapshot(t, root) != before {
		t.Fatal("files changed")
	}
}
