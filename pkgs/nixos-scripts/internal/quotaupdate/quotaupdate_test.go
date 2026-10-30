package quotaupdate

import (
	"bytes"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const manifestFixture = `{
  "name": "opencode-quota-patched",
  "version": "5.0.1",
  "private": true,
  "dependencies": {
    "@slkiser/opencode-quota": "5.0.1"
  }
}
`

func fixtureRoot(t *testing.T, manifest string) string {
	t.Helper()
	root := t.TempDir()
	dir := filepath.Join(root, "pkgs/opencode-quota-patched")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "package.json"), []byte(manifest), 0o644); err != nil {
		t.Fatal(err)
	}
	return root
}

func registry(t *testing.T, versions ...string) *httptest.Server {
	t.Helper()
	doc := map[string]any{"versions": map[string]any{}}
	for _, v := range versions {
		doc["versions"].(map[string]any)[v] = map[string]any{}
	}
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.EscapedPath() != "/@slkiser%2fopencode-quota" {
			http.NotFound(w, r)
			return
		}
		_ = json.NewEncoder(w).Encode(doc)
	}))
}

type call struct{ dir, name string }

func recorder(fail string) (Runner, *[]call) {
	var calls []call
	return func(dir, name string, args ...string) error {
		calls = append(calls, call{dir, name + " " + strings.Join(args, " ")})
		if fail != "" && strings.Contains(name+" "+strings.Join(args, " "), fail) {
			return errors.New("boom")
		}
		return nil
	}, &calls
}

func read(t *testing.T, root string) string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(root, "pkgs/opencode-quota-patched/package.json"))
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func TestMovesToNewestStableReleaseOfTheSameMajor(t *testing.T) {
	srv := registry(t, "5.0.1", "5.0.3", "5.1.0-beta.1", "6.0.0")
	defer srv.Close()
	root := fixtureRoot(t, manifestFixture)
	run, calls := recorder("")
	var out bytes.Buffer

	if err := Update(root, srv.URL, srv.Client(), run, &out); err != nil {
		t.Fatal(err)
	}
	want := strings.ReplaceAll(manifestFixture, "5.0.1", "5.0.3")
	if got := read(t, root); got != want {
		t.Fatalf("manifest =\n%s\nwant\n%s", got, want)
	}
	dir := filepath.Join(root, "pkgs/opencode-quota-patched")
	if len(*calls) != 2 ||
		(*calls)[0] != (call{dir, "npm install --package-lock-only --save-exact --legacy-peer-deps --no-audit --no-fund"}) ||
		(*calls)[1] != (call{root, "nix run nixpkgs#nix-update -- --flake --no-src --version=skip opencode-quota-patched"}) {
		t.Fatalf("calls = %#v", *calls)
	}
	if !strings.Contains(out.String(), "5.0.3") || !strings.Contains(out.String(), "6.0.0") {
		t.Fatalf("output = %q", out.String())
	}
}

func TestUpToDateDoesNothingButReportsANewMajor(t *testing.T) {
	srv := registry(t, "5.0.1", "6.0.0")
	defer srv.Close()
	root := fixtureRoot(t, manifestFixture)
	run, calls := recorder("")
	var out bytes.Buffer

	if err := Update(root, srv.URL, srv.Client(), run, &out); err != nil {
		t.Fatal(err)
	}
	if read(t, root) != manifestFixture || len(*calls) != 0 {
		t.Fatalf("expected no change, calls=%v", *calls)
	}
	if !strings.Contains(out.String(), "6.0.0") || !strings.Contains(out.String(), "rebase") {
		t.Fatalf("output = %q, want a new-major notice about the patches", out.String())
	}
}

func TestNoNoticeWhenTheLatestIsTheSameMajor(t *testing.T) {
	srv := registry(t, "5.0.1")
	defer srv.Close()
	var out bytes.Buffer
	run, _ := recorder("")
	if err := Update(fixtureRoot(t, manifestFixture), srv.URL, srv.Client(), run, &out); err != nil {
		t.Fatal(err)
	}
	if out.Len() != 0 {
		t.Fatalf("unexpected output %q", out.String())
	}
}

func TestRegistryFailureLeavesFilesUntouched(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "down", http.StatusBadGateway)
	}))
	defer srv.Close()
	root := fixtureRoot(t, manifestFixture)
	run, calls := recorder("")
	if err := Update(root, srv.URL, srv.Client(), run, &bytes.Buffer{}); err == nil {
		t.Fatal("want error")
	}
	if read(t, root) != manifestFixture || len(*calls) != 0 {
		t.Fatalf("state changed: calls=%v", *calls)
	}
}

func TestFailingLockRegenerationStopsBeforeTheHashStep(t *testing.T) {
	srv := registry(t, "5.0.1", "5.0.3")
	defer srv.Close()
	run, calls := recorder("npm install")
	err := Update(fixtureRoot(t, manifestFixture), srv.URL, srv.Client(), run, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "boom") {
		t.Fatalf("err = %v", err)
	}
	if len(*calls) != 1 {
		t.Fatalf("calls = %v, want only the failing npm step", *calls)
	}
}

func TestRejectsAManifestWithoutAnExactPin(t *testing.T) {
	srv := registry(t, "5.0.3")
	defer srv.Close()
	root := fixtureRoot(t, strings.ReplaceAll(manifestFixture, `"5.0.1"`, `"^5.0.1"`))
	run, calls := recorder("")
	if err := Update(root, srv.URL, srv.Client(), run, &bytes.Buffer{}); err == nil {
		t.Fatal("want error for a range pin")
	}
	if len(*calls) != 0 {
		t.Fatalf("calls = %v", *calls)
	}
}
