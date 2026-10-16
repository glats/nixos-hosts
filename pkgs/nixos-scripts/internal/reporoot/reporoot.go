package reporoot

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const EnvVar = "NIXOS_REPO"

const DefaultFallback = ".nixos"

func Resolve() (string, error) {
	if v := os.Getenv(EnvVar); v != "" {
		if fi, err := os.Stat(v); err == nil && fi.IsDir() {
			return v, nil
		}
	}
	if top, err := gitToplevel(); err == nil {
		return top, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	fallback := filepath.Join(home, DefaultFallback)
	if fi, err := os.Stat(fallback); err == nil && fi.IsDir() {
		return fallback, nil
	}
	return "", errors.New("cannot find repo root")
}

func FlakePath(root string) string {
	cwd, err := os.Getwd()
	if err != nil {
		return root
	}
	canonicalRoot, err := filepath.EvalSymlinks(root)
	if err != nil {
		return root
	}
	wt := filepath.Join(canonicalRoot, ".worktrees") + string(filepath.Separator)
	if strings.HasPrefix(cwd, wt) {
		return "."
	}
	return root
}

func gitToplevel() (string, error) {
	out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output()
	if err != nil {
		return "", err
	}
	top := strings.TrimSpace(string(out))
	if top == "" {
		return "", errors.New("empty git toplevel")
	}
	return top, nil
}
