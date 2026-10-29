package releasepins

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/glats/nixos-scripts/internal/githubclient"
)

const defaultAPIBase = "https://api.github.com"

var releaseFiles = []string{
	"pkgs/leaf/default.nix",
	"pkgs/wstunnel-relay/default.nix",
	"pkgs/findersearch/default.nix",
}

var (
	versionRx = regexp.MustCompile(`(?m)^[ \t]*version = "([^"]*)";?`)
	repoRx    = regexp.MustCompile(`github\.com/([^/]+)/([^/]+)/releases/download/`)
	tagRx     = regexp.MustCompile(`releases/download/([^/]+)/`)
	urlRx     = regexp.MustCompile(`(?m)^[ \t]*url = "([^"]*)";?`)
	nameRx    = regexp.MustCompile(`(?m)^[ \t]*name = "([^"]*)";?`)
	hashRx    = regexp.MustCompile(`(?m)^([ \t]*(?:sha256|hash) = ")([^"]*)(";)`)
)

type release struct {
	TagName    string         `json:"tag_name"`
	Prerelease bool           `json:"prerelease"`
	Draft      bool           `json:"draft"`
	Assets     []releaseAsset `json:"assets"`
}

type releaseAsset struct {
	Name               string `json:"name"`
	BrowserDownloadURL string `json:"browser_download_url"`
}

type asset struct {
	name string
	hash string
	sri  bool
}

type parsed struct {
	version string
	repo    string
	hasV    bool
	assets  []asset
}

func apiBaseURL() string {
	if base := os.Getenv("GITHUB_API_URL"); base != "" {
		return base
	}
	return defaultAPIBase
}

func Run(root string) error {
	return Update(root, githubclient.New(apiBaseURL()), releaseFiles...)
}

func Update(root string, client *http.Client, files ...string) error {
	apiBase := apiBaseURL()
	var updated []string
	for _, rel := range files {
		if err := updateFile(root, rel, apiBase, client); err != nil {
			if len(updated) > 0 {
				return fmt.Errorf("%w (already updated: %s)", err, strings.Join(updated, ", "))
			}
			return err
		}
		updated = append(updated, packageName(rel))
	}
	return nil
}

func packageName(rel string) string {
	return filepath.Base(filepath.Dir(rel))
}

func updateFile(root, rel, apiBase string, client *http.Client) error {
	name := packageName(rel)
	pkgPath := filepath.Join(root, rel)
	orig, err := os.ReadFile(pkgPath)
	if err != nil {
		return err
	}

	p, err := parsePackage(string(orig))
	if err != nil {
		return fmt.Errorf("%s: %w", name, err)
	}

	latest, err := fetchRelease(apiBase, p.repo, client)
	if err != nil {
		return fmt.Errorf("%s: %w", name, err)
	}

	newVersion := strings.TrimPrefix(latest.TagName, "v")
	if newVersion == "" {
		return fmt.Errorf("%s: release tag %q yields an empty version", name, latest.TagName)
	}
	newTag := newVersion
	if p.hasV {
		newTag = "v" + newVersion
	}
	if newTag != latest.TagName {
		return fmt.Errorf("%s: release tag %q does not match tag %q derived from the url", name, latest.TagName, newTag)
	}

	newHashes := make([]string, len(p.assets))
	for i, a := range p.assets {
		newName := strings.ReplaceAll(a.name, p.version, newVersion)
		downloadURL, ok := findAsset(latest, newName)
		if !ok {
			return fmt.Errorf("%s: asset %q not found in release %s", name, newName, latest.TagName)
		}
		sum, err := downloadHash(client, downloadURL)
		if err != nil {
			return fmt.Errorf("%s: asset %q: %w", name, newName, err)
		}
		newHashes[i] = encodeHash(sum, a.sri)
	}

	out := strings.ReplaceAll(string(orig), p.version, newVersion)
	i := 0
	out = hashRx.ReplaceAllStringFunc(out, func(m string) string {
		sub := hashRx.FindStringSubmatch(m)
		h := newHashes[i]
		i++
		return sub[1] + h + sub[3]
	})
	if i != len(newHashes) {
		return fmt.Errorf("%s: expected %d hash lines but rewrote %d", name, len(newHashes), i)
	}

	return os.WriteFile(pkgPath, []byte(out), 0o644)
}

func parsePackage(src string) (parsed, error) {
	var p parsed
	m := versionRx.FindStringSubmatch(src)
	if m == nil || m[1] == "" {
		return p, fmt.Errorf("no literal version found")
	}
	p.version = m[1]

	rm := repoRx.FindStringSubmatch(src)
	if rm == nil {
		return p, fmt.Errorf("unsupported upstream (not a GitHub releases source)")
	}
	p.repo = rm[1] + "/" + rm[2]

	tm := tagRx.FindStringSubmatch(src)
	if tm == nil {
		return p, fmt.Errorf("cannot determine release tag from url")
	}
	effective := strings.ReplaceAll(tm[1], "${version}", p.version)
	switch effective {
	case p.version:
		p.hasV = false
	case "v" + p.version:
		p.hasV = true
	default:
		return p, fmt.Errorf("cannot determine tag format from url segment %q", tm[1])
	}

	hashes := hashRx.FindAllStringSubmatch(src, -1)
	if len(hashes) == 0 {
		return p, fmt.Errorf("no fixed-output hash found")
	}

	var names []string
	for _, n := range nameRx.FindAllStringSubmatch(src, -1) {
		names = append(names, n[1])
	}
	if len(names) == 0 {
		for _, u := range urlRx.FindAllStringSubmatch(src, -1) {
			base := path.Base(u[1])
			if strings.HasPrefix(base, "${") && strings.HasSuffix(base, "}") {
				continue
			}
			names = append(names, strings.ReplaceAll(base, "${version}", p.version))
		}
	}
	if len(names) != len(hashes) {
		return p, fmt.Errorf("found %d hashes but %d asset names", len(hashes), len(names))
	}
	for i, h := range hashes {
		p.assets = append(p.assets, asset{
			name: names[i],
			hash: h[2],
			sri:  strings.HasPrefix(h[2], "sha256-"),
		})
	}
	return p, nil
}

func fetchRelease(apiBase, repo string, client *http.Client) (release, error) {
	var r release
	url := strings.TrimRight(apiBase, "/") + "/repos/" + repo + "/releases/latest"
	resp, err := client.Get(url)
	if err != nil {
		return r, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return r, githubclient.StatusError(repo, resp)
	}
	if err := json.NewDecoder(resp.Body).Decode(&r); err != nil {
		return r, err
	}
	if r.Prerelease || r.Draft {
		return r, fmt.Errorf("latest release %q is prerelease or draft", r.TagName)
	}
	return r, nil
}

func findAsset(r release, name string) (string, bool) {
	for _, a := range r.Assets {
		if a.Name == name {
			return a.BrowserDownloadURL, true
		}
	}
	return "", false
}

func downloadHash(client *http.Client, url string) ([32]byte, error) {
	var sum [32]byte
	resp, err := client.Get(url)
	if err != nil {
		return sum, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return sum, fmt.Errorf("download returned %s", resp.Status)
	}
	h := sha256.New()
	if _, err := io.Copy(h, resp.Body); err != nil {
		return sum, err
	}
	copy(sum[:], h.Sum(nil))
	return sum, nil
}

func encodeHash(sum [32]byte, sri bool) string {
	if sri {
		return "sha256-" + base64.StdEncoding.EncodeToString(sum[:])
	}
	return hex.EncodeToString(sum[:])
}
