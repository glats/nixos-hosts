package main

import (
	"os"
	"path/filepath"
	"reflect"
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
