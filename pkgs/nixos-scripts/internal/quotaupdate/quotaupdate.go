package quotaupdate

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"time"
)

const (
	defaultRegistry = "https://registry.npmjs.org"
	packageName     = "@slkiser/opencode-quota"
	packageDir      = "pkgs/opencode-quota-patched"
	flakeAttr       = "opencode-quota-patched"
)

var (
	stableVersion = regexp.MustCompile(`^(\d+)\.(\d+)\.(\d+)$`)
	exactPin      = regexp.MustCompile(`^\d+\.\d+\.\d+$`)
	pinLine       = regexp.MustCompile(`("@slkiser/opencode-quota":\s*")[^"]*(")`)
	versionLine   = regexp.MustCompile(`(?m)^(\s*"version":\s*")[^"]*(")`)
)

type Runner func(dir, name string, args ...string) error

type semver [3]int

func parse(v string) (semver, bool) {
	m := stableVersion.FindStringSubmatch(v)
	if m == nil {
		return semver{}, false
	}
	var s semver
	for i := range s {
		s[i], _ = strconv.Atoi(m[i+1])
	}
	return s, true
}

func (a semver) less(b semver) bool {
	for i := range a {
		if a[i] != b[i] {
			return a[i] < b[i]
		}
	}
	return false
}

func Run(root string) error {
	registry := os.Getenv("NPM_CONFIG_REGISTRY")
	if registry == "" {
		registry = defaultRegistry
	}
	run := func(dir, name string, args ...string) error {
		cmd := exec.Command(name, args...)
		cmd.Dir = dir
		cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
		return cmd.Run()
	}
	return Update(root, registry, &http.Client{Timeout: time.Minute}, run, os.Stdout)
}

func Update(root, registry string, client *http.Client, run Runner, out io.Writer) error {
	manifestPath := filepath.Join(root, packageDir, "package.json")
	manifest, err := os.ReadFile(manifestPath)
	if err != nil {
		return err
	}
	var parsed struct {
		Dependencies map[string]string `json:"dependencies"`
	}
	if err := json.Unmarshal(manifest, &parsed); err != nil {
		return fmt.Errorf("%s: %w", manifestPath, err)
	}
	current := parsed.Dependencies[packageName]
	if !exactPin.MatchString(current) {
		return fmt.Errorf("%s: %s must be an exact version, got %q", manifestPath, packageName, current)
	}
	currentVersion, _ := parse(current)

	req, err := http.NewRequest(http.MethodGet, registry+"/@slkiser%2fopencode-quota", nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/vnd.npm.install-v1+json")
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("%s: %w", packageName, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%s: registry returned %s", packageName, resp.Status)
	}
	var doc struct {
		Versions map[string]json.RawMessage `json:"versions"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&doc); err != nil {
		return fmt.Errorf("%s: %w", packageName, err)
	}

	next, newest := currentVersion, currentVersion
	nextText, newestText := current, current
	for text := range doc.Versions {
		v, ok := parse(text)
		if !ok {
			continue
		}
		if v[0] == currentVersion[0] && next.less(v) {
			next, nextText = v, text
		}
		if newest.less(v) {
			newest, newestText = v, text
		}
	}

	if nextText != current {
		updated := pinLine.ReplaceAllString(string(manifest), "${1}"+nextText+"${2}")
		updated = versionLine.ReplaceAllString(updated, "${1}"+nextText+"${2}")
		if err := os.WriteFile(manifestPath, []byte(updated), 0o644); err != nil {
			return err
		}
		fmt.Fprintf(out, "%s %s -> %s\n", packageName, current, nextText)
		dir := filepath.Join(root, packageDir)
		if err := run(dir, "npm", "install", "--package-lock-only", "--save-exact", "--legacy-peer-deps", "--no-audit", "--no-fund"); err != nil {
			return fmt.Errorf("%s: regenerating the lock: %w", packageName, err)
		}
		if err := run(root, "nix", "run", "nixpkgs#nix-update", "--", "--flake", "--no-src", "--version=skip", flakeAttr); err != nil {
			return fmt.Errorf("%s: updating npmDepsHash: %w", packageName, err)
		}
	}
	if newest[0] > currentVersion[0] {
		fmt.Fprintf(out, "%s %s is a new major release; the local patches (enterprise-spend-limit, response-headers) need to be rebased before moving from %s\n", packageName, newestText, nextText)
	}
	return nil
}
