package nixbuild

import (
	"os"
	"os/exec"
	"strings"
)

func GitHubAuthEnv(getenv func(string) string, ghToken func() (string, error)) map[string]string {
	out := map[string]string{}
	token := strings.TrimSpace(getenv("GITHUB_TOKEN"))
	if token == "" {
		token = strings.TrimSpace(getenv("GH_TOKEN"))
	}
	if token == "" && ghToken != nil {
		if fromGH, err := ghToken(); err == nil {
			token = strings.TrimSpace(fromGH)
		}
		if token != "" {
			out["GITHUB_TOKEN"] = token
		}
	}
	if token == "" {
		return map[string]string{}
	}
	line := "access-tokens = github.com=" + token
	if existing := getenv("NIX_CONFIG"); existing != "" {
		line = existing + "\n" + line
	}
	out["NIX_CONFIG"] = line
	return out
}

func GHAuthToken() (string, error) {
	out, err := exec.Command("gh", "auth", "token").Output()
	return string(out), err
}

func ApplyGitHubAuth() {
	for k, v := range GitHubAuthEnv(os.Getenv, GHAuthToken) {
		os.Setenv(k, v)
	}
}
