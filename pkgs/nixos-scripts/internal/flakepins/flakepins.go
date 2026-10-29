package flakepins

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/glats/nixos-scripts/internal/githubclient"
)

const (
	defaultAPIBase = "https://api.github.com"
	flakeFile      = "flake.nix"
)

var (
	versionAttrRe = regexp.MustCompile(`(?m)^[ \t]*version = "([^"]*)";`)
	mainVersionRe = regexp.MustCompile(`-X main\.version=([0-9A-Za-z.+_-]+)`)
	tagVersionRe  = regexp.MustCompile(`^v?(\d+\.\d+\.\d+(?:[-+.][0-9A-Za-z.-]+)?)$`)
)

type literal struct {
	path string
	re   *regexp.Regexp
}

type input struct {
	name  string
	owner string
	repo  string
	urlRe *regexp.Regexp
	// literals are version literals that must advance with the release.
	literals []literal
}

var inputs = []input{
	{
		name:  "gentle-ai-src",
		owner: "Gentleman-Programming",
		repo:  "gentle-ai",
		urlRe: regexp.MustCompile(`github:Gentleman-Programming/gentle-ai/([0-9a-f]{40})`),
		literals: []literal{
			{path: "pkgs/gentle-ai/default.nix", re: versionAttrRe},
			{path: "pkgs/gentle-ai/default.nix", re: mainVersionRe},
			{path: "pkgs/gentle-ai-assets/render.nix", re: versionAttrRe},
			{path: "pkgs/gentle-ai-assets/default.nix", re: versionAttrRe},
		},
	},
	{
		name:  "engram-src",
		owner: "Gentleman-Programming",
		repo:  "engram",
		urlRe: regexp.MustCompile(`github:Gentleman-Programming/engram/([^"]+)`),
	},
}

type release struct {
	TagName    string `json:"tag_name"`
	Draft      bool   `json:"draft"`
	Prerelease bool   `json:"prerelease"`
}

type refObject struct {
	Type string `json:"type"`
	SHA  string `json:"sha"`
}

type tagRef struct {
	Object refObject `json:"object"`
}

type gitTag struct {
	Object refObject `json:"object"`
}

func Run(root string) error {
	return Update(root, apiBase(), githubclient.New(apiBase()))
}

func apiBase() string {
	if v := strings.TrimSpace(os.Getenv("GITHUB_API_URL")); v != "" {
		return strings.TrimRight(v, "/")
	}
	return defaultAPIBase
}

func Update(root, apiBase string, client *http.Client) error {
	versions := make([]string, len(inputs))
	commits := make([]string, len(inputs))
	for i, in := range inputs {
		version, commit, err := in.resolve(client, apiBase)
		if err != nil {
			return err
		}
		versions[i] = version
		commits[i] = commit
	}

	flakeText, err := os.ReadFile(filepath.Join(root, flakeFile))
	if err != nil {
		return err
	}
	newFlake := string(flakeText)
	for i, in := range inputs {
		next, err := replaceGroup(newFlake, commits[i], in.urlRe)
		if err != nil {
			return fmt.Errorf("%s: input url not found in %s", in.name, flakeFile)
		}
		newFlake = next
	}

	content := map[string]string{}
	var order []string
	apply := func(name, path string, re *regexp.Regexp, value string) error {
		cur, ok := content[path]
		if !ok {
			data, err := os.ReadFile(filepath.Join(root, path))
			if err != nil {
				return err
			}
			cur = string(data)
			content[path] = cur
			order = append(order, path)
		}
		next, err := replaceGroup(cur, value, re)
		if err != nil {
			return fmt.Errorf("%s: %s: version literal not found", name, path)
		}
		content[path] = next
		return nil
	}
	for i, in := range inputs {
		for _, lit := range in.literals {
			if err := apply(in.name, lit.path, lit.re, versions[i]); err != nil {
				return err
			}
		}
	}

	if err := os.WriteFile(filepath.Join(root, flakeFile), []byte(newFlake), 0o644); err != nil {
		return err
	}
	for _, path := range order {
		if err := os.WriteFile(filepath.Join(root, path), []byte(content[path]), 0o644); err != nil {
			return err
		}
	}
	return nil
}

func (in input) resolve(client *http.Client, apiBase string) (version, commit string, err error) {
	var rels []release
	if err := getJSON(client, fmt.Sprintf("%s/repos/%s/%s/releases?per_page=100", apiBase, in.owner, in.repo), &rels); err != nil {
		return "", "", fmt.Errorf("%s: %w", in.name, err)
	}
	tag := ""
	for _, r := range rels {
		if r.Draft || r.Prerelease {
			continue
		}
		if m := tagVersionRe.FindStringSubmatch(r.TagName); m != nil {
			tag, version = r.TagName, m[1]
			break
		}
	}
	if tag == "" {
		return "", "", fmt.Errorf("%s: no stable release with a version tag found (prerelease-only, non-version tags only, or no releases)", in.name)
	}

	commit, err = in.resolveTagCommit(client, apiBase, tag)
	if err != nil {
		return "", "", fmt.Errorf("%s: tag %q: %w", in.name, tag, err)
	}
	return version, commit, nil
}

func (in input) resolveTagCommit(client *http.Client, apiBase, tag string) (string, error) {
	var ref tagRef
	if err := getJSON(client, fmt.Sprintf("%s/repos/%s/%s/git/ref/tags/%s", apiBase, in.owner, in.repo, tag), &ref); err != nil {
		return "", err
	}
	obj := ref.Object
	for depth := 0; ; depth++ {
		switch obj.Type {
		case "commit":
			if obj.SHA == "" {
				return "", errors.New("tag object points to an empty commit")
			}
			return obj.SHA, nil
		case "tag":
			if depth >= 8 {
				return "", errors.New("tag dereference exceeded depth")
			}
			var t gitTag
			if err := getJSON(client, fmt.Sprintf("%s/repos/%s/%s/git/tags/%s", apiBase, in.owner, in.repo, obj.SHA), &t); err != nil {
				return "", err
			}
			obj = t.Object
		default:
			return "", fmt.Errorf("tag has no commit (ref object type %q)", obj.Type)
		}
	}
}

func getJSON(client *http.Client, url string, out any) error {
	resp, err := client.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return githubclient.StatusError("github", resp)
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

func replaceGroup(text, replacement string, re *regexp.Regexp) (string, error) {
	idx := re.FindAllStringSubmatchIndex(text, -1)
	if len(idx) == 0 {
		return "", errors.New("pattern not found")
	}
	var b strings.Builder
	last := 0
	for _, m := range idx {
		start := m[2]
		end := m[3]
		b.WriteString(text[last:start])
		b.WriteString(replacement)
		last = end
	}
	b.WriteString(text[last:])
	return b.String(), nil
}
