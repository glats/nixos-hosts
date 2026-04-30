package config

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// Config holds the detected configuration for the CLI
type Config struct {
	RepoRoot     string // NIXOS_REPO env or git detection or ~/.nixos
	Hostname     string // os.Hostname()
	WorktreesDir string // RepoRoot + "/.worktrees"
	MainBranch   string // "main" or "master"
}

// Detect discovers the configuration from environment and git
func Detect() (*Config, error) {
	cfg := &Config{
		Hostname: getHostname(),
	}

	// Determine repo root
	cfg.RepoRoot = os.Getenv("NIXOS_REPO")
	if cfg.RepoRoot == "" {
		cwd, err := os.Getwd()
		if err != nil {
			return nil, fmt.Errorf("failed to get current directory: %w", err)
		}
		cfg.RepoRoot = detectGitRoot(cwd)
		if cfg.RepoRoot == "" {
			// Fall back to default NixOS location
			cfg.RepoRoot = filepath.Join(os.Getenv("HOME"), ".nixos")
		}
	}

	// Determine worktrees directory
	cfg.WorktreesDir = filepath.Join(cfg.RepoRoot, ".worktrees")

	// Determine main branch
	cfg.MainBranch = detectMainBranch(cfg.RepoRoot)
	if cfg.MainBranch == "" {
		cfg.MainBranch = "main" // fallback
	}

	return cfg, nil
}

// getHostname returns the system hostname
func getHostname() string {
	hostname, err := os.Hostname()
	if err != nil {
		return "unknown"
	}
	return hostname
}

// detectGitRoot finds the git repository root starting from the given path
func detectGitRoot(startPath string) string {
	path := startPath
	for {
		if _, err := os.Stat(filepath.Join(path, ".git")); err == nil {
			return path
		}
		parent := filepath.Dir(path)
		if parent == path {
			break
		}
		path = parent
	}
	return ""
}

// detectMainBranch determines the main branch name (main or master)
func detectMainBranch(repoRoot string) string {
	// Check if main exists
	cmd := exec.Command("git", "rev-parse", "--verify", "main")
	cmd.Dir = repoRoot
	if err := cmd.Run(); err == nil {
		return "main"
	}

	// Check if master exists
	cmd = exec.Command("git", "rev-parse", "--verify", "master")
	cmd.Dir = repoRoot
	if err := cmd.Run(); err == nil {
		return "master"
	}

	// Try to get current branch and infer
	cmd = exec.Command("git", "rev-parse", "--abbrev-ref", "HEAD")
	cmd.Dir = repoRoot
	output, err := cmd.Output()
	if err == nil {
		branch := string(output)
		if branch == "main" || branch == "master" {
			return branch
		}
	}

	return "main" // default
}

// IsInWorktree checks if the current directory is inside a worktree
func IsInWorktree(repoRoot, worktreesDir string) bool {
	cwd, err := os.Getwd()
	if err != nil {
		return false
	}

	worktreesRoot := worktreesDir
	rel, err := filepath.Rel(worktreesRoot, cwd)
	if err != nil {
		return false
	}

	// If the relative path doesn't start with "..", we're in the worktrees dir
	return !filepath.IsAbs(rel) && rel != ".." && len(rel) > 0 && rel[0] != '.'
}
