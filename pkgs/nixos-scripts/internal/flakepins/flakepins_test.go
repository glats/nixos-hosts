package flakepins

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const (
	gaOldCommit = "898d3976e8049a7238eaa7de60bff325c30d2b3d"
	gaNewCommit = "2dba7784114fff57864519c4c0d067e952a8c98b"
	gaTagObj    = "ee20d2dded25c8e1f1071f92ff73f1e357f36071"
	enNewCommit = "98912f811c90428e83a6aac99fa439bedb4b268f"
)

const flakeFixture = `{
  inputs = {
    gentle-ai-src = {
      url = "github:Gentleman-Programming/gentle-ai/` + gaOldCommit + `";
      flake = false;
    };

    engram-src = {
      url = "github:Gentleman-Programming/engram/main";
      flake = false;
    };
  };
}
`

const lockFixture = `{
  "nodes": {
    "gentle-ai-src": {
      "locked": {
        "rev": "` + gaOldCommit + `"
      }
    },
    "engram-src": {
      "locked": {
        "rev": "old-engram-rev"
      }
    }
  }
}
`

const gentleAIFixture = `{
  lib,
  buildGoModule,
  gentle-ai-src,
  go,
}:

assert lib.versionAtLeast go.version "1.25.10";
(buildGoModule.override { inherit go; }) {
  pname = "gentle-ai";
  version = "4.1.1";

  src = gentle-ai-src;

  subPackages = [ "cmd/gentle-ai" ];

  vendorHash = "sha256-YL4Slz/UuY+HEcJTW+pMphcdB6xtpam+E4uTDWifEcY=";
  ldflags = [
    "-s"
    "-w"
    "-X main.version=4.1.1"
  ];
}
`

const renderFixture = `{
  lib,
  buildGoModule,
  opencode,
  gentle-ai-src,
  vendorHash ? "sha256-YL4Slz/UuY+HEcJTW+pMphcdB6xtpam+E4uTDWifEcY=",
}:

buildGoModule {
  pname = "gentle-ai-rendered-prompts";
  version = "4.1.1";
  src = gentle-ai-src;
  inherit vendorHash;
}
`

const assetsFixture = `{
  lib,
  stdenvNoCC,
  gentle-ai-src,
  gentle-ai,
}:

stdenvNoCC.mkDerivation {
  pname = "gentle-ai-assets";
  version = "4.1.1";
  src = gentle-ai-src;
}
`

const engramFixture = `{
  lib,
  buildGoModule,
  engram-src,
}:

buildGoModule {
  pname = "engram";
  version = engram-src.rev or "unstable";

  src = engram-src;

  vendorHash = "sha256-LH8sSmer918+KL5hnOju7b5NsZo+W9sd3HhkQgjS2Ho=";
}
`

func fixtureRoot(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	for path, data := range map[string]string{
		"flake.nix":                         flakeFixture,
		"flake.lock":                        lockFixture,
		"pkgs/gentle-ai/default.nix":        gentleAIFixture,
		"pkgs/gentle-ai-assets/render.nix":  renderFixture,
		"pkgs/gentle-ai-assets/default.nix": assetsFixture,
		"pkgs/engram/default.nix":           engramFixture,
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

func fullRoutes() map[string]any {
	return map[string]any{
		"/repos/Gentleman-Programming/gentle-ai/releases": []map[string]any{
			{"tag_name": "v4.3.1"},
		},
		"/repos/Gentleman-Programming/gentle-ai/git/ref/tags/v4.3.1": map[string]any{
			"object": map[string]any{"type": "tag", "sha": gaTagObj},
		},
		"/repos/Gentleman-Programming/gentle-ai/git/tags/" + gaTagObj: map[string]any{
			"object": map[string]any{"type": "commit", "sha": gaNewCommit},
		},
		"/repos/Gentleman-Programming/engram/releases": []map[string]any{
			{"tag_name": "v3.6.0"},
		},
		"/repos/Gentleman-Programming/engram/git/ref/tags/v3.6.0": map[string]any{
			"object": map[string]any{"type": "commit", "sha": enNewCommit},
		},
	}
}

func githubServer(t *testing.T, override map[string]any) *httptest.Server {
	t.Helper()
	routes := fullRoutes()
	for k, v := range override {
		routes[k] = v
	}
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, ok := routes[r.URL.Path]
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(body); err != nil {
			t.Errorf("encode %s: %v", r.URL.Path, err)
		}
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

func snapshot(t *testing.T, root string) map[string]string {
	t.Helper()
	files := []string{
		"flake.nix",
		"flake.lock",
		"pkgs/gentle-ai/default.nix",
		"pkgs/gentle-ai-assets/render.nix",
		"pkgs/gentle-ai-assets/default.nix",
		"pkgs/engram/default.nix",
	}
	snap := map[string]string{}
	for _, rel := range files {
		snap[rel] = read(t, root, rel)
	}
	return snap
}

func TestLatestStableReleaseIgnoresPrereleaseAndDraft(t *testing.T) {
	srv := githubServer(t, map[string]any{
		"/repos/Gentleman-Programming/gentle-ai/releases": []map[string]any{
			{"tag_name": "v4.4.0-rc.1", "prerelease": true},
			{"tag_name": "v4.5.0", "draft": true},
			{"tag_name": "v4.3.1"},
		},
	})
	defer srv.Close()
	root := fixtureRoot(t)

	if err := Update(root, srv.URL, srv.Client()); err != nil {
		t.Fatal(err)
	}

	got := read(t, root, "pkgs/gentle-ai/default.nix")
	if !strings.Contains(got, `version = "4.3.1";`) {
		t.Fatalf("version not advanced to latest stable:\n%s", got)
	}
	if strings.Contains(got, "4.4.0-rc.1") || strings.Contains(got, "4.5.0") {
		t.Fatalf("prerelease or draft version leaked into output:\n%s", got)
	}
}

func TestAnnotatedTagDereferencedToCommit(t *testing.T) {
	srv := githubServer(t, nil)
	defer srv.Close()
	root := fixtureRoot(t)

	if err := Update(root, srv.URL, srv.Client()); err != nil {
		t.Fatal(err)
	}

	flake := read(t, root, "flake.nix")
	if !strings.Contains(flake, "github:Gentleman-Programming/gentle-ai/"+gaNewCommit) {
		t.Fatalf("flake url does not carry dereferenced commit:\n%s", flake)
	}
	if strings.Contains(flake, gaTagObj) {
		t.Fatalf("annotated tag object sha leaked instead of commit:\n%s", flake)
	}
}

func TestRevStyleInputRewritten(t *testing.T) {
	srv := githubServer(t, nil)
	defer srv.Close()
	root := fixtureRoot(t)

	if err := Update(root, srv.URL, srv.Client()); err != nil {
		t.Fatal(err)
	}

	flake := read(t, root, "flake.nix")
	if !strings.Contains(flake, `github:Gentleman-Programming/gentle-ai/`+gaNewCommit+`"`) {
		t.Fatalf("rev-style input not advanced to new commit:\n%s", flake)
	}
	if strings.Contains(flake, gaOldCommit) {
		t.Fatalf("old commit still present:\n%s", flake)
	}
}

func TestMovingBranchInputPinnedToCommit(t *testing.T) {
	srv := githubServer(t, nil)
	defer srv.Close()
	root := fixtureRoot(t)

	if err := Update(root, srv.URL, srv.Client()); err != nil {
		t.Fatal(err)
	}

	flake := read(t, root, "flake.nix")
	if !strings.Contains(flake, `github:Gentleman-Programming/engram/`+enNewCommit+`"`) {
		t.Fatalf("moving branch not pinned to immutable commit:\n%s", flake)
	}
	if strings.Contains(flake, "engram/main") {
		t.Fatalf("moving branch reference survived:\n%s", flake)
	}
}

func TestLiteralsRewrittenInAllCoupledFiles(t *testing.T) {
	srv := githubServer(t, nil)
	defer srv.Close()
	root := fixtureRoot(t)

	if err := Update(root, srv.URL, srv.Client()); err != nil {
		t.Fatal(err)
	}

	cases := []struct {
		path string
		want string
	}{
		{"pkgs/gentle-ai/default.nix", `-X main.version=4.3.1`},
		{"pkgs/gentle-ai/default.nix", `version = "4.3.1";`},
		{"pkgs/gentle-ai-assets/render.nix", `version = "4.3.1";`},
		{"pkgs/gentle-ai-assets/default.nix", `version = "4.3.1";`},
	}
	for _, c := range cases {
		if got := read(t, root, c.path); !strings.Contains(got, c.want) {
			t.Fatalf("%s missing %q:\n%s", c.path, c.want, got)
		}
	}
}

func TestLockAndHashesUntouched(t *testing.T) {
	srv := githubServer(t, nil)
	defer srv.Close()
	root := fixtureRoot(t)

	if err := Update(root, srv.URL, srv.Client()); err != nil {
		t.Fatal(err)
	}

	if got := read(t, root, "flake.lock"); got != lockFixture {
		t.Fatalf("flake.lock was modified:\n%s", got)
	}
	gentle := read(t, root, "pkgs/gentle-ai/default.nix")
	if !strings.Contains(gentle, `vendorHash = "sha256-YL4Slz/UuY+HEcJTW+pMphcdB6xtpam+E4uTDWifEcY=";`) {
		t.Fatalf("gentle-ai vendorHash changed:\n%s", gentle)
	}
	if got := read(t, root, "pkgs/gentle-ai-assets/render.nix"); !strings.Contains(got, "sha256-YL4Slz/UuY+HEcJTW+pMphcdB6xtpam+E4uTDWifEcY=") {
		t.Fatalf("render vendorHash changed:\n%s", got)
	}
	if got := read(t, root, "pkgs/engram/default.nix"); !strings.Contains(got, `vendorHash = "sha256-LH8sSmer918+KL5hnOju7b5NsZo+W9sd3HhkQgjS2Ho=";`) {
		t.Fatalf("engram vendorHash changed:\n%s", got)
	}
}

func TestUpdateIsIdempotent(t *testing.T) {
	srv := githubServer(t, nil)
	defer srv.Close()
	root := fixtureRoot(t)

	if err := Update(root, srv.URL, srv.Client()); err != nil {
		t.Fatal(err)
	}
	first := snapshot(t, root)

	if err := Update(root, srv.URL, srv.Client()); err != nil {
		t.Fatal(err)
	}
	for rel, before := range first {
		if got := read(t, root, rel); got != before {
			t.Fatalf("%s changed on second run:\nbefore:\n%s\nafter:\n%s", rel, before, got)
		}
	}
}

func TestFailureLeavesAllFilesByteIdentical(t *testing.T) {
	srv := githubServer(t, map[string]any{
		"/repos/Gentleman-Programming/engram/releases": []map[string]any{
			{"tag_name": "v3.7.0-rc.1", "prerelease": true},
		},
	})
	defer srv.Close()
	root := fixtureRoot(t)
	before := snapshot(t, root)

	err := Update(root, srv.URL, srv.Client())
	if err == nil {
		t.Fatal("expected error for prerelease-only release list")
	}
	for rel, want := range before {
		if got := read(t, root, rel); got != want {
			t.Fatalf("%s changed after failed update:\nwant:\n%s\ngot:\n%s", rel, want, got)
		}
	}
}

func TestPrereleaseOnlyErrorsClearly(t *testing.T) {
	srv := githubServer(t, map[string]any{
		"/repos/Gentleman-Programming/gentle-ai/releases": []map[string]any{
			{"tag_name": "v4.4.0-rc.1", "prerelease": true},
		},
	})
	defer srv.Close()
	root := fixtureRoot(t)

	err := Update(root, srv.URL, srv.Client())
	if err == nil || !strings.Contains(err.Error(), "gentle-ai-src") || !strings.Contains(err.Error(), "stable") {
		t.Fatalf("err = %v, want named prerelease-only failure", err)
	}
}

func TestTagWithoutCommitErrorsClearly(t *testing.T) {
	srv := githubServer(t, map[string]any{
		"/repos/Gentleman-Programming/gentle-ai/git/ref/tags/v4.3.1": map[string]any{
			"object": map[string]any{"type": "blob", "sha": "deadbeef"},
		},
	})
	defer srv.Close()
	root := fixtureRoot(t)

	err := Update(root, srv.URL, srv.Client())
	if err == nil || !strings.Contains(err.Error(), "gentle-ai-src") || !strings.Contains(err.Error(), "no commit") {
		t.Fatalf("err = %v, want named no-commit failure", err)
	}
}

func TestNonSemverNewestStableTagIsSkipped(t *testing.T) {
	srv := githubServer(t, map[string]any{
		"/repos/Gentleman-Programming/engram/releases": []map[string]any{
			{"tag_name": "pi-v0.6.0"},
			{"tag_name": "v3.6.0"},
		},
	})
	defer srv.Close()
	root := fixtureRoot(t)

	if err := Update(root, srv.URL, srv.Client()); err != nil {
		t.Fatalf("non-semver tag must be skipped: %v", err)
	}
	if got := read(t, root, "flake.nix"); !strings.Contains(got, enNewCommit) {
		t.Fatalf("engram not pinned to the v3.6.0 commit:\n%s", got)
	}
}
