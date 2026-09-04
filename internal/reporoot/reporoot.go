// Package reporoot resolves the NixOS config repo root and flake path.
//
// Go replacement for bin/lib/common.sh repo_root() and the worktree-aware
// flake-path rule from bin/nixos-build. Compiled binaries have no script
// directory, so resolution follows the env → git → fallback chain:
//
//  1. $NIXOS_REPO when set and a directory
//  2. git rev-parse --show-toplevel from the current working directory
//  3. $HOME/.nixos when it exists
package reporoot

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// EnvVar allows overriding the repo root (mirrors bin/nixos-build's NIXOS_REPO).
const EnvVar = "NIXOS_REPO"

// DefaultFallback is used when cwd is not a git repo and NIXOS_REPO is unset.
const DefaultFallback = ".nixos"

// Resolve returns the repo root. An error is returned when none of the
// resolution steps apply.
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

// FlakePath returns the flake reference for a rebuild from the current
// directory: inside <root>/.worktrees the local copy wins ("."), otherwise
// the repo root itself.
func FlakePath(root string) string {
	cwd, err := os.Getwd()
	if err != nil {
		return root
	}
	wt := filepath.Join(root, ".worktrees") + string(filepath.Separator)
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
