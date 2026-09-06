package reporoot

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestResolveEnvOverride(t *testing.T) {
	dir := t.TempDir()
	t.Setenv(EnvVar, dir)
	got, err := Resolve()
	if err != nil {
		t.Fatalf("Resolve: %v", err)
	}
	if got != dir {
		t.Fatalf("Resolve() = %q, want %q", got, dir)
	}
}

func TestResolveGitToplevel(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not available")
	}
	dir := t.TempDir()
	run := func(args ...string) {
		cmd := exec.Command("git", args...)
		cmd.Dir = dir
		cmd.Env = append(os.Environ(),
			"GIT_AUTHOR_NAME=t", "GIT_AUTHOR_EMAIL=t@t",
			"GIT_COMMITTER_NAME=t", "GIT_COMMITTER_EMAIL=t@t",
		)
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v (%s)", args, err, out)
		}
	}
	run("init", "-q")
	run("commit", "--allow-empty", "-m", "init")

	// Unset the env override so the git branch applies.
	t.Setenv(EnvVar, "")
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chdir("/tmp") })

	got, err := Resolve()
	if err != nil {
		t.Fatalf("Resolve: %v", err)
	}
	want, _ := filepath.EvalSymlinks(dir)
	if got != want {
		t.Fatalf("Resolve() = %q, want %q", got, want)
	}
}

func TestResolveFallbackHomeNixos(t *testing.T) {
	home := t.TempDir()
	if err := os.MkdirAll(filepath.Join(home, DefaultFallback), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv(EnvVar, "")
	t.Setenv("HOME", home)
	// cwd is the real repo (a git repo) — force the fallback by running from
	// a non-git directory.
	nonGit := t.TempDir()
	if err := os.Chdir(nonGit); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chdir("/tmp") })

	got, err := Resolve()
	if err != nil {
		t.Fatalf("Resolve: %v", err)
	}
	if got != filepath.Join(home, DefaultFallback) {
		t.Fatalf("Resolve() = %q, want %q", got, filepath.Join(home, DefaultFallback))
	}
}

func TestResolveNoCandidate(t *testing.T) {
	empty := t.TempDir()
	home := t.TempDir() // no .nixos inside
	t.Setenv(EnvVar, "")
	t.Setenv("HOME", home)
	if err := os.Chdir(empty); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chdir("/tmp") })

	if _, err := Resolve(); err == nil {
		t.Fatal("Resolve() should fail with no candidates")
	}
}

func TestFlakePathWorktree(t *testing.T) {
	root := t.TempDir()
	wt := filepath.Join(root, ".worktrees", "demo")
	if err := os.MkdirAll(wt, 0o755); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chdir("/tmp") })

	os.Chdir(wt)
	if got := FlakePath(root); got != "." {
		t.Fatalf("FlakePath inside worktree = %q, want %q", got, ".")
	}

	os.Chdir(root)
	if got := FlakePath(root); got != root {
		t.Fatalf("FlakePath at root = %q, want %q", got, root)
	}
}
