package main

import (
	"io"
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

func TestParseArgs(t *testing.T) {
	tests := []struct {
		name      string
		argv      []string
		directory string
		check     bool
		help      bool
		wantErr   string
	}{
		{name: "defaults", argv: nil},
		{name: "explicit directory and check", argv: []string{"/tmp/project", "--check"}, directory: "/tmp/project", check: true},
		{name: "check before directory", argv: []string{"--check", "project"}, directory: "project", check: true},
		{name: "help", argv: []string{"--help"}, help: true},
		{name: "unknown flag", argv: []string{"--nope"}, wantErr: "Unknown argument: --nope"},
		{name: "duplicate directory", argv: []string{"one", "two"}, wantErr: "Unexpected extra directory: two"},
		{name: "empty directory", argv: []string{""}, wantErr: "Directory argument must not be empty"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parseArgs(tt.argv)
			if tt.wantErr != "" {
				if err == nil || !strings.Contains(err.Error(), tt.wantErr) {
					t.Fatalf("parseArgs(%v) error = %v, want %q", tt.argv, err, tt.wantErr)
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			want := commandArgs{directory: tt.directory, check: tt.check, help: tt.help}
			if got != want {
				t.Fatalf("parseArgs(%v) = %+v, want %+v", tt.argv, got, want)
			}
		})
	}
}

func TestCheckModeUsesExplicitAndDiscoveredRoots(t *testing.T) {
	root := t.TempDir()
	explicit := filepath.Join(root, "explicit")
	discovered := filepath.Join(root, "discovered", "nested")
	if err := os.MkdirAll(explicit, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(discovered, 0o755); err != nil {
		t.Fatal(err)
	}
	writeFlake(t, explicit)
	writeFlake(t, filepath.Join(root, "discovered"))

	for _, tc := range []struct {
		name string
		argv []string
		cwd  string
	}{
		{name: "explicit", argv: []string{explicit, "--check"}, cwd: root},
		{name: "discovered", argv: []string{"--check"}, cwd: discovered},
	} {
		t.Run(tc.name, func(t *testing.T) {
			args, err := parseArgs(tc.argv)
			if err != nil {
				t.Fatal(err)
			}
			selected, err := resolveTarget(args.directory, tc.cwd)
			if err != nil {
				t.Fatal(err)
			}
			if tc.name == "explicit" && selected != explicit {
				t.Fatalf("selected root = %q, want %q", selected, explicit)
			}
			if tc.name == "discovered" && selected != filepath.Join(root, "discovered") {
				t.Fatalf("selected root = %q, want discovered root", selected)
			}

			file := filepath.Join(selected, "example.nix")
			original := []byte("{ }")
			if err := os.WriteFile(file, original, 0o644); err != nil {
				t.Fatal(err)
			}
			oldFormatter := runFormatter
			runFormatter = func(file string, _, _ io.Writer) error {
				return os.WriteFile(file, []byte("{ }\n"), 0o644)
			}
			t.Cleanup(func() { runFormatter = oldFormatter })

			var rc int
			checkFile(file, &rc)
			if rc != 1 {
				t.Fatalf("checkFile() rc = %d, want 1 for an unformatted file", rc)
			}
			got, err := os.ReadFile(file)
			if err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(got, original) {
				t.Fatalf("checkFile() modified source: got %q, want %q", got, original)
			}

			formatted := []byte("{ }\n")
			if err := os.WriteFile(file, formatted, 0o644); err != nil {
				t.Fatal(err)
			}
			rc = 0
			checkFile(file, &rc)
			if rc != 0 {
				t.Fatalf("checkFile() rc = %d, want 0 for a formatted file", rc)
			}
			got, err = os.ReadFile(file)
			if err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(got, formatted) {
				t.Fatalf("checkFile() modified formatted source: got %q, want %q", got, formatted)
			}
		})
	}
}

func TestEligibleFilesAreFormatted(t *testing.T) {
	root := t.TempDir()
	files := []string{
		"root.nix",
		"nested/child.nix",
		".git/ignored.nix",
		".worktrees/ignored.nix",
		".format-nix-stale.nix",
	}
	for _, name := range files {
		path := filepath.Join(root, name)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte("before"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	eligible, err := nixFiles(root)
	if err != nil {
		t.Fatal(err)
	}
	oldFormatter := runFormatter
	runFormatter = func(file string, _, _ io.Writer) error {
		return os.WriteFile(file, []byte("after"), 0o644)
	}
	t.Cleanup(func() { runFormatter = oldFormatter })
	for _, file := range eligible {
		var rc int
		formatFile(file, &rc)
		if rc != 0 {
			t.Fatalf("fmtFile(%q) rc = %d, want 0", file, rc)
		}
	}

	for _, name := range []string{"root.nix", "nested/child.nix"} {
		got, err := os.ReadFile(filepath.Join(root, name))
		if err != nil {
			t.Fatal(err)
		}
		if string(got) != "after" {
			t.Fatalf("eligible file %s = %q, want formatted content", name, got)
		}
	}
}

func TestResolveTargetExplicitDirectoryWins(t *testing.T) {
	cwd := t.TempDir()
	other := t.TempDir()
	writeFlake(t, cwd)
	writeFlake(t, other)

	got, err := resolveTarget(other, cwd)
	if err != nil {
		t.Fatal(err)
	}
	if got != other {
		t.Fatalf("resolveTarget() = %q, want explicit directory %q", got, other)
	}
}

func TestResolveTargetFindsNearestAncestor(t *testing.T) {
	root := t.TempDir()
	writeFlake(t, root)
	nested := filepath.Join(root, "one", "two")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}

	got, err := resolveTarget("", nested)
	if err != nil {
		t.Fatal(err)
	}
	if got != root {
		t.Fatalf("resolveTarget() = %q, want nearest flake %q", got, root)
	}
}

func TestResolveTargetRejectsInvalidExplicitDirectoryAndMissingFlake(t *testing.T) {
	missing := filepath.Join(t.TempDir(), "missing")
	if _, err := resolveTarget(missing, t.TempDir()); err == nil {
		t.Fatal("resolveTarget() accepted missing explicit directory")
	}

	nonFlake := t.TempDir()
	if _, err := resolveTarget(nonFlake, t.TempDir()); err == nil {
		t.Fatal("resolveTarget() accepted directory without flake.nix")
	}
}

func TestResolveTargetReportsNoContainingFlake(t *testing.T) {
	cwd := t.TempDir()
	if _, err := resolveTarget("", cwd); err == nil || !strings.Contains(err.Error(), "No flake.nix found") {
		t.Fatalf("resolveTarget() error = %v, want missing-flake error", err)
	}
}

func writeFlake(t *testing.T, root string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(root, "flake.nix"), []byte("{}\n"), 0o644); err != nil {
		t.Fatal(err)
	}
}
