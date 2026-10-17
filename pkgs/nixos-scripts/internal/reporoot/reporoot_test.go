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
	home := t.TempDir()
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
	alias := filepath.Join(t.TempDir(), "repo-alias")
	if err := os.Symlink(root, alias); err != nil {
		t.Skipf("symlinks unavailable: %v", err)
	}
	if got := FlakePath(alias); got != "." {
		t.Fatalf("FlakePath inside worktree via aliased root = %q, want %q", got, ".")
	}

	os.Chdir(root)
	if got := FlakePath(root); got != root {
		t.Fatalf("FlakePath at root = %q, want %q", got, root)
	}
	if got := FlakePath(alias); got != alias {
		t.Fatalf("FlakePath at root with alias = %q, want %q", got, alias)
	}
}

func gitRun(t *testing.T, dir string, args ...string) {
	t.Helper()
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

func TestFlakePathExternalGitWorktree(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not available")
	}
	root, _ := filepath.EvalSymlinks(t.TempDir())
	gitRun(t, root, "init", "-q")
	gitRun(t, root, "commit", "--allow-empty", "-m", "init")
	wt := filepath.Join(t.TempDir(), "feature-x")
	gitRun(t, root, "worktree", "add", "-q", "-b", "feature/x", wt)
	wt, _ = filepath.EvalSymlinks(wt)

	other, _ := filepath.EvalSymlinks(t.TempDir())
	gitRun(t, other, "init", "-q")
	t.Cleanup(func() { os.Chdir("/tmp") })

	sub := filepath.Join(wt, "sub")
	if err := os.MkdirAll(sub, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, dir := range []string{wt, sub} {
		os.Chdir(dir)
		if got := FlakePath(root); got != wt {
			t.Fatalf("FlakePath in external worktree %q = %q, want %q", dir, got, wt)
		}
	}

	os.Chdir(root)
	if got := FlakePath(root); got != root {
		t.Fatalf("FlakePath at main checkout = %q, want %q", got, root)
	}

	os.Chdir(other)
	if got := FlakePath(root); got != root {
		t.Fatalf("FlakePath in unrelated repo = %q, want %q", got, root)
	}
}
