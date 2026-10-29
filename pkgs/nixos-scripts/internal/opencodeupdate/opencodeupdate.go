package opencodeupdate

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

const defaultRegistry = "https://registry.npmjs.org"

const (
	manifestPath   = "pkgs/opencode-npm-packages-v2/package.json"
	executablePath = "pkgs/opencode/default.nix"
	scope          = "@opencode/"
)

var (
	exactVersion  = regexp.MustCompile(`^\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?$`)
	versionLine   = regexp.MustCompile(`(?m)^(\s*version = ")[^"]*(";)`)
	platformHash  = regexp.MustCompile(`(@opencode/cli-([a-z0-9-]+)/-/cli-[a-z0-9-]+-\$\{version\}\.tgz";\s*hash = ")[^"]*(")`)
	manifestEntry = func(name string) *regexp.Regexp {
		return regexp.MustCompile(`("` + regexp.QuoteMeta(name) + `":\s*")[^"]*(")`)
	}
)

type packument struct {
	Version      string            `json:"version"`
	Dependencies map[string]string `json:"dependencies"`
	Dist         struct {
		Integrity string `json:"integrity"`
	} `json:"dist"`
}

func Run(root string) error {
	registry := os.Getenv("NPM_CONFIG_REGISTRY")
	if registry == "" {
		registry = defaultRegistry
	}
	return Update(root, registry, &http.Client{Timeout: time.Minute})
}

func Update(root, registry string, client *http.Client) error {
	fetch := func(name, version string) (packument, error) {
		var p packument
		url := strings.TrimRight(registry, "/") + "/" + strings.Replace(name, "/", "%2f", 1) + "/" + version
		resp, err := client.Get(url)
		if err != nil {
			return p, fmt.Errorf("%s@%s: %w", name, version, err)
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			return p, fmt.Errorf("%s@%s: registry returned %s", name, version, resp.Status)
		}
		if err := json.NewDecoder(resp.Body).Decode(&p); err != nil {
			return p, fmt.Errorf("%s@%s: %w", name, version, err)
		}
		return p, nil
	}

	plugin, err := fetch(scope+"plugin", "latest")
	if err != nil {
		return err
	}
	release := plugin.Version
	if !exactVersion.MatchString(release) {
		return fmt.Errorf("%splugin latest version %q is not an exact release", scope, release)
	}

	manifest, err := os.ReadFile(filepath.Join(root, manifestPath))
	if err != nil {
		return err
	}
	var parsed struct {
		Dependencies map[string]string `json:"dependencies"`
	}
	if err := json.Unmarshal(manifest, &parsed); err != nil {
		return fmt.Errorf("%s: %w", manifestPath, err)
	}

	coupled := plugin.Dependencies
	if _, ok := parsed.Dependencies[scope+"schema"]; ok {
		schema, err := fetch(scope+"schema", release)
		if err != nil {
			return err
		}
		merged := map[string]string{}
		for name, version := range schema.Dependencies {
			merged[name] = version
		}
		for name, version := range plugin.Dependencies {
			merged[name] = version
		}
		coupled = merged
	}

	manifestText := string(manifest)
	for name := range parsed.Dependencies {
		want := ""
		if strings.HasPrefix(name, scope) {
			if _, err := fetch(name, release); err != nil {
				return err
			}
			want = release
		} else if version, ok := coupled[name]; ok {
			want = version
		} else {
			continue
		}
		if !exactVersion.MatchString(want) {
			return fmt.Errorf("%s: release %s declares non-exact version %q", name, release, want)
		}
		manifestText = manifestEntry(name).ReplaceAllString(manifestText, "${1}"+want+"${2}")
	}

	executable, err := os.ReadFile(filepath.Join(root, executablePath))
	if err != nil {
		return err
	}
	if !versionLine.Match(executable) || !platformHash.Match(executable) {
		return fmt.Errorf("%s: version or platform hashes not found", executablePath)
	}
	var hashErr error
	executableText := platformHash.ReplaceAllStringFunc(string(executable), func(block string) string {
		match := platformHash.FindStringSubmatch(block)
		meta, err := fetch(scope+"cli-"+match[2], release)
		if err == nil && meta.Dist.Integrity == "" {
			err = fmt.Errorf("%scli-%s@%s: registry returned no integrity", scope, match[2], release)
		}
		if err != nil {
			hashErr = err
			return block
		}
		return match[1] + meta.Dist.Integrity + match[3]
	})
	if hashErr != nil {
		return hashErr
	}
	executableText = versionLine.ReplaceAllString(executableText, "${1}"+release+"${2}")

	if err := os.WriteFile(filepath.Join(root, manifestPath), []byte(manifestText), 0o644); err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(root, executablePath), []byte(executableText), 0o644)
}
