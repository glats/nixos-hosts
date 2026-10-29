package releasepins

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const leafFixture = `{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "1.27.0";
  system = stdenvNoCC.hostPlatform.system;
  platformSrc = {
    x86_64-linux = {
      url = "https://github.com/RivoLink/leaf/releases/download/${version}/leaf-linux-x86_64";
      sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    x86_64-darwin = {
      url = "https://github.com/RivoLink/leaf/releases/download/${version}/leaf-macos-x86_64";
      sha256 = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
    };
    aarch64-darwin = {
      url = "https://github.com/RivoLink/leaf/releases/download/${version}/leaf-macos-arm64";
      sha256 = "sha256-CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=";
    };
  }.${system} or (throw "Unsupported system: ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "leaf";
  inherit version;
  src = fetchurl { inherit (platformSrc) url sha256; };
}
`

const wstunnelFixture = `{
  fetchurl,
  lib,
  stdenvNoCC,
}:

let
  assets = {
    "x86_64-linux" = {
      name = "wstunnel_11.0.0_linux_amd64.tar.gz";
      hash = "sha256-lwiplxe1qVFFPC/3wUwl00GNAsp/y5b9s4Ko8gg7q14=";
    };
    "aarch64-darwin" = {
      name = "wstunnel_11.0.0_darwin_arm64.tar.gz";
      hash = "sha256-FQ5DnIuUhZFUkD1xMTtMCzE6ycz5lDevQlcxNOUFHcQ=";
    };
  };
  system = stdenvNoCC.hostPlatform.system;
in
stdenvNoCC.mkDerivation {
  pname = "wstunnel-relay";
  version = "11.0.0";
  src = fetchurl {
    url = "https://github.com/erebe/wstunnel/releases/download/v11.0.0/${asset.name}";
    hash = asset.hash;
  };
}
`

const findersearchFixture = `{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation rec {
  pname = "findersearch";
  version = "0.4.9";

  src = fetchurl {
    url = "https://github.com/zeusinsight/FinderSearch/releases/download/v${version}/FinderSearch-${version}-AppleSilicon.dmg";
    sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
  };
}
`

const tinkertoolFixture = `{
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "tinkertool";
  version = "11.71";

  src = stdenvNoCC.mkDerivation {
    outputHash = "5e3d30d2daabc5462f4015d9921a2b6e93bec393e8803a15f19f69b6c989656c";
  };
}
`

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func fakeClient(routes map[string]http.HandlerFunc) *http.Client {
	return &http.Client{
		Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
			rec := httptest.NewRecorder()
			if h, ok := routes[req.URL.Path]; ok {
				h(rec, req)
			} else {
				http.NotFound(rec, req)
			}
			return rec.Result(), nil
		}),
	}
}

func releaseHandler(tag string, prerelease, draft bool, assets ...map[string]string) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		list := make([]map[string]string, len(assets))
		copy(list, assets)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"tag_name":   tag,
			"prerelease": prerelease,
			"draft":      draft,
			"assets":     list,
		})
	}
}

func sriOf(data string) string {
	sum := sha256.Sum256([]byte(data))
	return "sha256-" + base64.StdEncoding.EncodeToString(sum[:])
}

func hexOf(data string) string {
	sum := sha256.Sum256([]byte(data))
	return hex.EncodeToString(sum[:])
}

func writeFixture(t *testing.T, rel, content string) string {
	t.Helper()
	root := t.TempDir()
	full := filepath.Join(root, rel)
	if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(full, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	return root
}

func readFixture(t *testing.T, root, rel string) string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(root, rel))
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func leafRoutes(t *testing.T, tag string) map[string]http.HandlerFunc {
	pathBase := "/RivoLink/leaf/releases/download/" + tag
	urlBase := "https://github.com" + pathBase
	return map[string]http.HandlerFunc{
		"/repos/RivoLink/leaf/releases/latest": releaseHandler(tag, false, false,
			map[string]string{"name": "leaf-linux-x86_64", "browser_download_url": urlBase + "/leaf-linux-x86_64"},
			map[string]string{"name": "leaf-macos-x86_64", "browser_download_url": urlBase + "/leaf-macos-x86_64"},
			map[string]string{"name": "leaf-macos-arm64", "browser_download_url": urlBase + "/leaf-macos-arm64"},
		),
		pathBase + "/leaf-linux-x86_64": func(w http.ResponseWriter, _ *http.Request) {
			_, _ = w.Write([]byte("linux-binary"))
		},
		pathBase + "/leaf-macos-x86_64": func(w http.ResponseWriter, _ *http.Request) {
			_, _ = w.Write([]byte("macos-x86-binary"))
		},
		pathBase + "/leaf-macos-arm64": func(w http.ResponseWriter, _ *http.Request) {
			_, _ = w.Write([]byte("macos-arm-binary"))
		},
	}
}

func TestResolvesLatestStableRelease(t *testing.T) {
	client := fakeClient(leafRoutes(t, "1.28.0"))
	root := writeFixture(t, "pkgs/leaf/default.nix", leafFixture)

	if err := Update(root, client, "pkgs/leaf/default.nix"); err != nil {
		t.Fatal(err)
	}
	got := readFixture(t, root, "pkgs/leaf/default.nix")
	if !strings.Contains(got, `version = "1.28.0";`) {
		t.Fatalf("version not advanced:\n%s", got)
	}
	for _, want := range []string{
		sriOf("linux-binary"),
		sriOf("macos-x86-binary"),
		sriOf("macos-arm-binary"),
	} {
		if !strings.Contains(got, want) {
			t.Fatalf("missing hash %s:\n%s", want, got)
		}
	}
}

func TestRejectsPrereleaseAndDraft(t *testing.T) {
	for _, tc := range []struct {
		name       string
		prerelease bool
		draft      bool
	}{
		{"prerelease", true, false},
		{"draft", false, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			routes := leafRoutes(t, "1.28.0")
			routes["/repos/RivoLink/leaf/releases/latest"] = releaseHandler("1.28.0", tc.prerelease, tc.draft)
			client := fakeClient(routes)
			root := writeFixture(t, "pkgs/leaf/default.nix", leafFixture)

			err := Update(root, client, "pkgs/leaf/default.nix")
			if err == nil || !strings.Contains(err.Error(), "prerelease or draft") {
				t.Fatalf("err = %v, want prerelease/draft rejection", err)
			}
			if got := readFixture(t, root, "pkgs/leaf/default.nix"); got != leafFixture {
				t.Fatal("file changed after rejected release")
			}
		})
	}
}

func TestUpdatesAllPlatformHashesInEachRepresentation(t *testing.T) {
	t.Run("sri", func(t *testing.T) {
		client := fakeClient(leafRoutes(t, "1.28.0"))
		root := writeFixture(t, "pkgs/leaf/default.nix", leafFixture)
		if err := Update(root, client, "pkgs/leaf/default.nix"); err != nil {
			t.Fatal(err)
		}
		got := readFixture(t, root, "pkgs/leaf/default.nix")
		if strings.Contains(got, "sha256-AAAAAAAA") || strings.Contains(got, "sha256-BBBBBBBB") || strings.Contains(got, "sha256-CCCCCCCC") {
			t.Fatalf("stale hashes remain:\n%s", got)
		}
		for _, want := range []string{sriOf("linux-binary"), sriOf("macos-x86-binary"), sriOf("macos-arm-binary")} {
			if !strings.Contains(got, want) {
				t.Fatalf("missing %s:\n%s", want, got)
			}
		}
	})
	t.Run("raw hex", func(t *testing.T) {
		tag := "v0.5.0"
		pathBase := "/zeusinsight/FinderSearch/releases/download/" + tag
		urlBase := "https://github.com" + pathBase
		routes := map[string]http.HandlerFunc{
			"/repos/zeusinsight/FinderSearch/releases/latest": releaseHandler(tag, false, false,
				map[string]string{"name": "FinderSearch-0.5.0-AppleSilicon.dmg", "browser_download_url": urlBase + "/FinderSearch-0.5.0-AppleSilicon.dmg"},
			),
			pathBase + "/FinderSearch-0.5.0-AppleSilicon.dmg": func(w http.ResponseWriter, _ *http.Request) {
				_, _ = w.Write([]byte("dmg-bytes"))
			},
		}
		root := writeFixture(t, "pkgs/findersearch/default.nix", findersearchFixture)
		if err := Update(root, fakeClient(routes), "pkgs/findersearch/default.nix"); err != nil {
			t.Fatal(err)
		}
		got := readFixture(t, root, "pkgs/findersearch/default.nix")
		if !strings.Contains(got, `version = "0.5.0";`) {
			t.Fatalf("version not advanced:\n%s", got)
		}
		if !strings.Contains(got, hexOf("dmg-bytes")) {
			t.Fatalf("raw hex hash not updated:\n%s", got)
		}
	})
	t.Run("versioned asset names", func(t *testing.T) {
		tag := "v12.0.0"
		pathBase := "/erebe/wstunnel/releases/download/" + tag
		urlBase := "https://github.com" + pathBase
		routes := map[string]http.HandlerFunc{
			"/repos/erebe/wstunnel/releases/latest": releaseHandler(tag, false, false,
				map[string]string{"name": "wstunnel_12.0.0_linux_amd64.tar.gz", "browser_download_url": urlBase + "/wstunnel_12.0.0_linux_amd64.tar.gz"},
				map[string]string{"name": "wstunnel_12.0.0_darwin_arm64.tar.gz", "browser_download_url": urlBase + "/wstunnel_12.0.0_darwin_arm64.tar.gz"},
			),
			pathBase + "/wstunnel_12.0.0_linux_amd64.tar.gz": func(w http.ResponseWriter, _ *http.Request) {
				_, _ = w.Write([]byte("linux-tar"))
			},
			pathBase + "/wstunnel_12.0.0_darwin_arm64.tar.gz": func(w http.ResponseWriter, _ *http.Request) {
				_, _ = w.Write([]byte("darwin-tar"))
			},
		}
		root := writeFixture(t, "pkgs/wstunnel-relay/default.nix", wstunnelFixture)
		if err := Update(root, fakeClient(routes), "pkgs/wstunnel-relay/default.nix"); err != nil {
			t.Fatal(err)
		}
		got := readFixture(t, root, "pkgs/wstunnel-relay/default.nix")
		for _, want := range []string{
			`version = "12.0.0";`,
			`wstunnel_12.0.0_linux_amd64.tar.gz`,
			`wstunnel_12.0.0_darwin_arm64.tar.gz`,
			`download/v12.0.0/${asset.name}`,
			sriOf("linux-tar"),
			sriOf("darwin-tar"),
		} {
			if !strings.Contains(got, want) {
				t.Fatalf("missing %q:\n%s", want, got)
			}
		}
	})
}

func TestUpdatesVersionLiteralWithoutLeadingV(t *testing.T) {
	tag := "v12.0.0"
	pathBase := "/erebe/wstunnel/releases/download/" + tag
	urlBase := "https://github.com" + pathBase
	routes := map[string]http.HandlerFunc{
		"/repos/erebe/wstunnel/releases/latest": releaseHandler(tag, false, false,
			map[string]string{"name": "wstunnel_12.0.0_linux_amd64.tar.gz", "browser_download_url": urlBase + "/wstunnel_12.0.0_linux_amd64.tar.gz"},
			map[string]string{"name": "wstunnel_12.0.0_darwin_arm64.tar.gz", "browser_download_url": urlBase + "/wstunnel_12.0.0_darwin_arm64.tar.gz"},
		),
		pathBase + "/wstunnel_12.0.0_linux_amd64.tar.gz": func(w http.ResponseWriter, _ *http.Request) {
			_, _ = w.Write([]byte("linux-tar"))
		},
		pathBase + "/wstunnel_12.0.0_darwin_arm64.tar.gz": func(w http.ResponseWriter, _ *http.Request) {
			_, _ = w.Write([]byte("darwin-tar"))
		},
	}
	root := writeFixture(t, "pkgs/wstunnel-relay/default.nix", wstunnelFixture)
	if err := Update(root, fakeClient(routes), "pkgs/wstunnel-relay/default.nix"); err != nil {
		t.Fatal(err)
	}
	got := readFixture(t, root, "pkgs/wstunnel-relay/default.nix")
	if !strings.Contains(got, `version = "12.0.0";`) {
		t.Fatalf("version literal missing or wrong:\n%s", got)
	}
	if strings.Contains(got, `version = "v12.0.0";`) {
		t.Fatalf("version literal must not carry the v prefix:\n%s", got)
	}
}

func TestUpdateIsIdempotent(t *testing.T) {
	client := fakeClient(leafRoutes(t, "1.28.0"))
	root := writeFixture(t, "pkgs/leaf/default.nix", leafFixture)
	if err := Update(root, client, "pkgs/leaf/default.nix"); err != nil {
		t.Fatal(err)
	}
	first := readFixture(t, root, "pkgs/leaf/default.nix")
	if err := Update(root, client, "pkgs/leaf/default.nix"); err != nil {
		t.Fatal(err)
	}
	if got := readFixture(t, root, "pkgs/leaf/default.nix"); got != first {
		t.Fatal("re-run changed the file")
	}
}

func TestAssetNotFoundLeavesFileUntouched(t *testing.T) {
	routes := leafRoutes(t, "1.28.0")
	delete(routes, "/RivoLink/leaf/releases/download/1.28.0/leaf-macos-arm64")
	client := fakeClient(routes)
	root := writeFixture(t, "pkgs/leaf/default.nix", leafFixture)

	err := Update(root, client, "pkgs/leaf/default.nix")
	if err == nil || !strings.Contains(err.Error(), "leaf-macos-arm64") {
		t.Fatalf("err = %v, want missing asset leaf-macos-arm64", err)
	}
	if got := readFixture(t, root, "pkgs/leaf/default.nix"); got != leafFixture {
		t.Fatal("file changed after missing asset")
	}
}

func TestMalformedFileLeavesUntouched(t *testing.T) {
	for _, tc := range []struct {
		name    string
		fixture string
	}{
		{"missing version", `{
  stdenvNoCC, fetchurl,
}:
stdenvNoCC.mkDerivation {
  pname = "leaf";
  src = fetchurl { url = "https://github.com/RivoLink/leaf/releases/download/1.27.0/leaf"; sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; };
}
`},
		{"hash name mismatch", `{
  stdenvNoCC, fetchurl,
}:
stdenvNoCC.mkDerivation {
  version = "1.27.0";
  src = fetchurl { url = "https://github.com/RivoLink/leaf/releases/download/${version}/leaf-linux-x86_64"; sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; };
  other = fetchurl { url = "https://example.com/x"; sha256 = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="; };
}
`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			client := fakeClient(leafRoutes(t, "1.28.0"))
			root := writeFixture(t, "pkgs/leaf/default.nix", tc.fixture)
			if err := Update(root, client, "pkgs/leaf/default.nix"); err == nil {
				t.Fatal("expected error for malformed file")
			}
			if got := readFixture(t, root, "pkgs/leaf/default.nix"); got != tc.fixture {
				t.Fatal("malformed file changed")
			}
		})
	}
}

func TestNonGitHubURLReportedUnsupported(t *testing.T) {
	root := writeFixture(t, "pkgs/tinkertool/default.nix", tinkertoolFixture)
	err := Update(root, fakeClient(nil), "pkgs/tinkertool/default.nix")
	if err == nil || !strings.Contains(err.Error(), "unsupported") {
		t.Fatalf("err = %v, want unsupported", err)
	}
	if !strings.Contains(err.Error(), "tinkertool") {
		t.Fatalf("err = %v, want package name", err)
	}
	if got := readFixture(t, root, "pkgs/tinkertool/default.nix"); got != tinkertoolFixture {
		t.Fatal("unsupported file changed")
	}
}

func TestStopsAtFirstErrorAndReportsUpdatedPackages(t *testing.T) {
	client := fakeClient(leafRoutes(t, "1.28.0"))
	root := writeFixture(t, "pkgs/leaf/default.nix", leafFixture)

	full := filepath.Join(root, "pkgs/tinkertool")
	if err := os.MkdirAll(full, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(full, "default.nix"), []byte(tinkertoolFixture), 0o644); err != nil {
		t.Fatal(err)
	}

	err := Update(root, client, "pkgs/leaf/default.nix", "pkgs/tinkertool/default.nix")
	if err == nil || !strings.Contains(err.Error(), "unsupported") {
		t.Fatalf("err = %v, want unsupported", err)
	}
	if !strings.Contains(err.Error(), "already updated: leaf") {
		t.Fatalf("err = %v, want already-updated note", err)
	}
	if got := readFixture(t, root, "pkgs/leaf/default.nix"); got == leafFixture {
		t.Fatal("leaf should have been updated before the error")
	}
}
