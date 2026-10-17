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
	if top, ok := sameRepoWorktree(canonicalRoot); ok {
		return top
	}
	return root
}

func sameRepoWorktree(canonicalRoot string) (string, bool) {
	top, err := gitToplevel()
	if err != nil {
		return "", false
	}
	if top, err = filepath.EvalSymlinks(top); err != nil || top == canonicalRoot {
		return "", false
	}
	cwdCommon, err := gitCommonDir("")
	if err != nil {
		return "", false
	}
	rootCommon, err := gitCommonDir(canonicalRoot)
	if err != nil || cwdCommon != rootCommon {
		return "", false
	}
	return top, true
}

func gitCommonDir(dir string) (string, error) {
	cmd := exec.Command("git", "rev-parse", "--path-format=absolute", "--git-common-dir")
	cmd.Dir = dir
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return filepath.EvalSymlinks(strings.TrimSpace(string(out)))
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
