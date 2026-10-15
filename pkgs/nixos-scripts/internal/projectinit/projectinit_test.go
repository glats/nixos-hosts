package projectinit

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestInitCreatesOnlyEngram(t *testing.T) {
	dir := t.TempDir()
	result, err := Init(dir, Options{Name: "example"})
	if err != nil {
		t.Fatal(err)
	}
	if result.Git || result.Engram != "created" {
		t.Fatalf("unexpected result: %+v", result)
	}
	if !exists(filepath.Join(dir, ".engram", "config.json")) {
		t.Fatal("Engram config was not created")
	}
	if exists(filepath.Join(dir, "openspec")) {
		t.Fatal("OpenSpec state was created")
	}
}

func TestInitPreservesDifferentProjectWithoutForce(t *testing.T) {
	dir := t.TempDir()
	if err := os.Mkdir(filepath.Join(dir, ".engram"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, ".engram", "config.json"), []byte(`{"project_name":"other"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Init(dir, Options{Name: "example"}); err == nil {
		t.Fatal("Init accepted a conflicting config")
	}
}

func TestHasGitRecognizesWorktreeMarker(t *testing.T) {
	dir := t.TempDir()
	child := filepath.Join(dir, "child")
	if err := os.Mkdir(child, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, ".git"), []byte("gitdir: /tmp/worktree"), 0o644); err != nil {
		t.Fatal(err)
	}
	if !hasGit(child) {
		t.Fatal("hasGit did not recognize parent worktree marker")
	}
}

func TestInitDryRunDoesNotWrite(t *testing.T) {
	dir := t.TempDir()
	if _, err := Init(dir, Options{Name: "example", DryRun: true}); err != nil {
		t.Fatal(err)
	}
	if exists(filepath.Join(dir, ".engram", "config.json")) {
		t.Fatal("dry-run changed the project")
	}
}

func TestInitDetectsGitDirectoryFromRelativeTarget(t *testing.T) {
	root := t.TempDir()
	target := filepath.Join(root, "target")
	if err := os.MkdirAll(filepath.Join(root, ".git"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(target, 0o755); err != nil {
		t.Fatal(err)
	}

	previous, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(root); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := os.Chdir(previous); err != nil {
			t.Error(err)
		}
	})

	result, err := Init("target", Options{})
	if err != nil {
		t.Fatal(err)
	}
	canonicalTarget, err := filepath.EvalSymlinks(target)
	if err != nil {
		t.Fatal(err)
	}
	if !result.Git || result.Path != canonicalTarget {
		t.Fatalf("unexpected result: %+v", result)
	}
}

func TestInitDerivesNameFromDirectoryBasename(t *testing.T) {
	parent := t.TempDir()
	dir := filepath.Join(parent, "myproject")
	if err := os.Mkdir(dir, 0o755); err != nil {
		t.Fatal(err)
	}

	if _, err := Init(dir, Options{}); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, ".engram", "config.json"))
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "{\n  \"project_name\": \"myproject\"\n}\n" {
		t.Fatalf("config = %q", data)
	}
}

func TestInitRejectsMissingDirectoryWithoutWrites(t *testing.T) {
	parent := t.TempDir()
	missing := filepath.Join(parent, "missing")

	if _, err := Init(missing, Options{}); err == nil {
		t.Fatal("Init accepted a missing directory")
	}
	if exists(missing) || exists(filepath.Join(parent, ".engram", "config.json")) {
		t.Fatal("Init wrote files for a missing directory")
	}
}

func TestInitReportsCurrentMatchingProjectWithoutWrites(t *testing.T) {
	dir := t.TempDir()
	configPath := filepath.Join(dir, ".engram", "config.json")
	if err := os.Mkdir(filepath.Dir(configPath), 0o755); err != nil {
		t.Fatal(err)
	}
	original := []byte(`{"project_name":"example"}`)
	if err := os.WriteFile(configPath, original, 0o600); err != nil {
		t.Fatal(err)
	}

	result, err := Init(dir, Options{Name: "example"})
	if err != nil {
		t.Fatal(err)
	}
	if result.Engram != "current" {
		t.Fatalf("Engram state = %q, want current", result.Engram)
	}
	data, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != string(original) {
		t.Fatalf("config changed from %q to %q", original, data)
	}
}

func TestInitForceOverwritesConflictingProjectWithExpectedModeAndNewline(t *testing.T) {
	dir := t.TempDir()
	configPath := filepath.Join(dir, ".engram", "config.json")
	if err := os.Mkdir(filepath.Dir(configPath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(configPath, []byte(`{"project_name":"other"}`), 0o600); err != nil {
		t.Fatal(err)
	}

	result, err := Init(dir, Options{Name: "example", Force: true})
	if err != nil {
		t.Fatal(err)
	}
	if result.Engram != "conflict" {
		t.Fatalf("Engram state = %q, want conflict", result.Engram)
	}
	info, err := os.Stat(configPath)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o644 {
		t.Fatalf("config mode = %o, want 644", info.Mode().Perm())
	}
	data, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "{\n  \"project_name\": \"example\"\n}\n" {
		t.Fatalf("config = %q", data)
	}
}

func TestInitRejectsMalformedAndUnreadableEngramConfig(t *testing.T) {
	t.Run("malformed", func(t *testing.T) {
		dir := t.TempDir()
		configPath := filepath.Join(dir, ".engram", "config.json")
		if err := os.Mkdir(filepath.Dir(configPath), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(configPath, []byte("not json"), 0o644); err != nil {
			t.Fatal(err)
		}

		if _, err := Init(dir, Options{}); err == nil || !strings.Contains(err.Error(), "parse Engram configuration") {
			t.Fatalf("Init error = %v, want parse error", err)
		}
	})

	t.Run("unreadable", func(t *testing.T) {
		if os.Geteuid() == 0 {
			t.Skip("root can read files regardless of mode")
		}
		dir := t.TempDir()
		configPath := filepath.Join(dir, ".engram", "config.json")
		if err := os.Mkdir(filepath.Dir(configPath), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(configPath, []byte(`{"project_name":"example"}`), 0o000); err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { _ = os.Chmod(configPath, 0o644) })

		if _, err := Init(dir, Options{}); err == nil || !strings.Contains(err.Error(), "read Engram configuration") {
			t.Fatalf("Init error = %v, want read error", err)
		}
	})
}
