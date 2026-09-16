package main

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestNixFilesSkipsGitAndWorktrees(t *testing.T) {
	root := t.TempDir()
	files := []string{
		"a.nix",
		"dir/b.nix",
		".git/c.nix",
		".worktrees/wt1/d.nix",
		".worktrees/wt2/sub/e.nix",
		".format-nix-stale.nix",
		"notes.txt",
	}
	for _, f := range files {
		p := filepath.Join(root, f)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte("{}"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	got, err := nixFiles(root)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{
		filepath.Join(root, "a.nix"),
		filepath.Join(root, "dir", "b.nix"),
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("nixFiles(%q) = %v, want %v", root, got, want)
	}
}

func TestCreateCheckCopyUsesRepositoryLocalNixTempFile(t *testing.T) {
	root := t.TempDir()
	oldwd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(root); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chdir(oldwd) })

	src := filepath.Join(root, "example.nix")
	if err := os.WriteFile(src, []byte("{ }\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	copyPath, err := createCheckCopy(src)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Remove(copyPath) })

	if filepath.Dir(copyPath) != "." {
		t.Fatalf("createCheckCopy() path = %q, want repository-local path", copyPath)
	}
	name := filepath.Base(copyPath)
	if !strings.HasPrefix(name, ".format-nix-") || !strings.HasSuffix(name, ".nix") {
		t.Fatalf("createCheckCopy() name = %q, want .format-nix-*.nix", name)
	}
}
