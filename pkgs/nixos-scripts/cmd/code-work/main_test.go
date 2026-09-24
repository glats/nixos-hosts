package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/glats/nixos-scripts/internal/managedworktree"
)

func TestManagedSelectorAdmission(t *testing.T) {
	for _, args := range [][]string{{"fmt"}, {"eval", ".#x"}, {"flake-check"}, {"build", ".#x"}} {
		if err := validateManagedCheckArgs(args); err != nil {
			t.Errorf("%v rejected: %v", args, err)
		}
	}
	for _, args := range [][]string{{"fmt", "extra"}, {"eval", "--arg", "x"}, {"build", "--max-jobs", "8"}, {"switch"}, {"home-manager"}, {"flake-check", "--no-build"}} {
		if err := validateManagedCheckArgs(args); err == nil {
			t.Errorf("%v admitted", args)
		}
	}
}

func TestManagedRepositorySelector(t *testing.T) {
	if err := validateManagedSelector("/repo", "/repo", "master"); err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct{ cwd, root, branch string }{
		{"relative", "/repo", "master"}, {"/other", "/repo", "master"}, {"/repo", "/repo", "HEAD"},
	} {
		if err := validateManagedSelector(tc.cwd, tc.root, tc.branch); err == nil {
			t.Errorf("accepted unsafe selector %#v", tc)
		}
	}
}

func TestManagedCommitState(t *testing.T) {
	if !managedCommitReady("") || managedCommitReady(" M file") || managedCommitReady("A  file") {
		t.Fatal("commit state admission incorrect")
	}
}

// TestCodeWorkCommandHelperProcess provides deterministic fake commands and a
// subprocess entry point for exercising the real command-level dispatch.
func TestCodeWorkCommandHelperProcess(t *testing.T) {
	if os.Getenv("CODE_WORK_TEST_HELPER") != "1" {
		return
	}
	if os.Getenv("CODE_WORK_FAKE_COMMAND") == "opencode" {
		os.Exit(0)
	}
	if os.Getenv("CODE_WORK_FAKE_COMMAND") == "nix" {
		if marker := os.Getenv("CODE_WORK_NIX_MARKER"); marker != "" {
			_ = os.WriteFile(marker, []byte(strings.Join(os.Args[1:], " ")), 0o644)
		}
		if os.Getenv("CODE_WORK_NIX_FAIL") == "1" {
			os.Exit(1)
		}
		os.Exit(0)
	}
	args := os.Args[1:]
	for i, arg := range args {
		if arg == "--" {
			args = args[i+1:]
			break
		}
	}
	if len(args) == 0 {
		os.Exit(2)
	}
	var err error
	if args[0] == "managed" {
		err = managedCommand(args[1:])
	} else if args[0] == "new" || args[0] == "check" || args[0] == "ready" || args[0] == "status" || args[0] == "merge" || args[0] == "clean" || args[0] == "abandon" || args[0] == "recover-lock" {
		err = managedTopLevelCommand(args)
	} else if args[0] == "prune" {
		cmdPrune(resolveRepoRoot())
	} else {
		err = fmt.Errorf("unsupported helper command %q", args[0])
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	os.Exit(0)
}

type commandResult struct {
	output string
	err    error
}

func runCodeWork(t *testing.T, dir string, env map[string]string, args ...string) commandResult {
	t.Helper()
	cmd := exec.Command(os.Args[0], append([]string{"-test.run=TestCodeWorkCommandHelperProcess", "--"}, args...)...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "CODE_WORK_TEST_HELPER=1")
	for key, value := range env {
		cmd.Env = append(cmd.Env, key+"="+value)
	}
	out, err := cmd.CombinedOutput()
	return commandResult{output: string(out), err: err}
}

func setupCommandRepo(t *testing.T) string {
	t.Helper()
	repo := t.TempDir()
	for _, args := range [][]string{{"init", "-b", "master"}, {"config", "user.email", "[REDACTED]"}, {"config", "user.name", "Test"}} {
		git(t, repo, args...)
	}
	if err := os.WriteFile(filepath.Join(repo, ".gitignore"), []byte(".worktrees/\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(repo, "README"), []byte("base\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	git(t, repo, "add", ".gitignore")
	git(t, repo, "add", "README")
	git(t, repo, "commit", "-m", "base")
	bin := filepath.Join(t.TempDir(), "bin")
	if err := os.Mkdir(bin, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"nix", "opencode"} {
		script := fmt.Sprintf("#!/bin/sh\nCODE_WORK_TEST_HELPER=1 CODE_WORK_FAKE_COMMAND=%s exec %q -test.run=TestCodeWorkCommandHelperProcess -- \"$@\"\n", name, os.Args[0])
		if err := os.WriteFile(filepath.Join(bin, name), []byte(script), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	return repo
}

func git(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
	return string(out)
}

func startTask(t *testing.T, repo, id string) string {
	t.Helper()
	result := runCodeWork(t, repo, nil, "new", id)
	if result.err != nil {
		t.Fatalf("start %s: %v\n%s", id, result.err, result.output)
	}
	return managedworktree.PathFor(repo, id)
}

func commitTask(t *testing.T, path, name string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(path, name), []byte(name+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	git(t, path, "add", name)
	git(t, path, "commit", "-m", name)
}

func TestManagedCommandDispatchAndConflicts(t *testing.T) {
	repo := setupCommandRepo(t)
	first := startTask(t, repo, "alpha")
	second := startTask(t, repo, "beta")
	if first == second {
		t.Fatal("independent tasks share a workspace")
	}
	if result := runCodeWork(t, repo, nil, "new", "alpha"); result.err != nil {
		t.Fatalf("matching dispatch was not reused: %v\n%s", result.err, result.output)
	}
	stateDir := filepath.Join(repo, ".git", "managed-worktrees")
	record, err := managedworktree.LoadRecord(stateDir, "alpha")
	if err != nil {
		t.Fatal(err)
	}
	record.BaseBranch = "other"
	if err := managedworktree.SaveRecord(stateDir, record); err != nil {
		t.Fatal(err)
	}
	if result := runCodeWork(t, repo, nil, "new", "alpha"); result.err == nil {
		t.Fatal("conflicting dispatch was accepted")
	}
}

func TestManagedCommandCheckAllowlistAndDenial(t *testing.T) {
	repo := setupCommandRepo(t)
	marker := filepath.Join(t.TempDir(), "executed")
	path := startTask(t, repo, "check")
	result := runCodeWork(t, path, map[string]string{"CODE_WORK_NIX_MARKER": marker}, "check", "switch")
	if result.err == nil {
		t.Fatal("mutating check was accepted")
	}
	if _, err := os.Stat(marker); !os.IsNotExist(err) {
		t.Fatalf("denied mutation reached an executable: %v", err)
	}
	if result = runCodeWork(t, path, map[string]string{"CODE_WORK_NIX_MARKER": marker}, "check", "eval", ".#test"); result.err != nil {
		t.Fatalf("allowlisted check failed: %v\n%s", result.err, result.output)
	}
	if _, err := os.Stat(marker); err != nil {
		t.Fatalf("allowlisted command was not executed: %v", err)
	}
}

func TestManagedContextCommandsRejectOutsideWorktree(t *testing.T) {
	repo := setupCommandRepo(t)
	path := startTask(t, repo, "task")
	statePath := filepath.Join(repo, ".git", "managed-worktrees", "task.json")
	before, err := os.ReadFile(statePath)
	if err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{{"check", "fmt"}, {"ready"}, {"status"}} {
		result := runCodeWork(t, repo, nil, args...)
		if result.err == nil || !strings.Contains(result.output, "not inside a managed worktree") {
			t.Errorf("%v outside managed worktree = %v, %q", args, result.err, result.output)
		}
	}
	legacyPath := filepath.Join(t.TempDir(), "managed")
	git(t, repo, "branch", "legacy-managed")
	git(t, repo, "worktree", "add", legacyPath, "legacy-managed")
	for _, args := range [][]string{{"check", "fmt"}, {"ready"}, {"status"}} {
		result := runCodeWork(t, legacyPath, nil, args...)
		if result.err == nil || !strings.Contains(result.output, "not inside a managed worktree") {
			t.Errorf("%v from legacy worktree = %v, %q", args, result.err, result.output)
		}
	}
	after, err := os.ReadFile(statePath)
	if err != nil || string(before) != string(after) {
		t.Fatalf("outside command changed task state: %v", err)
	}
	if result := runCodeWork(t, path, nil, "status"); result.err != nil || !strings.Contains(result.output, "task active") {
		t.Fatalf("status from managed worktree failed: %v\n%s", result.err, result.output)
	}
}

func TestDeprecatedManagedShim(t *testing.T) {
	repo := setupCommandRepo(t)
	result := runCodeWork(t, repo, nil, "managed", "start", "demo")
	if result.err != nil {
		t.Fatalf("managed start failed: %v\n%s", result.err, result.output)
	}
	if strings.Count(result.output, "code-work managed is deprecated") != 1 {
		t.Fatalf("deprecation hint count = %d\n%s", strings.Count(result.output, "code-work managed is deprecated"), result.output)
	}
	if !strings.Contains(result.output, "Created managed task demo") {
		t.Fatalf("managed start did not forward to new: %s", result.output)
	}
	if strings.Contains(usageTemplate, "managed") {
		t.Fatal("managed shim is visible in help")
	}
	path := managedworktree.PathFor(repo, "demo")
	if result = runCodeWork(t, path, nil, "managed", "check", "demo", "fmt"); result.err != nil {
		t.Fatalf("managed check failed: %v\n%s", result.err, result.output)
	}
	if result = runCodeWork(t, repo, nil, "managed", "inspect", "demo"); result.err != nil || !strings.Contains(result.output, "demo active") {
		t.Fatalf("managed inspect failed: %v\n%s", result.err, result.output)
	}
	commitTask(t, path, "demo")
	if result = runCodeWork(t, path, nil, "managed", "ready", "demo"); result.err != nil {
		t.Fatalf("managed ready failed: %v\n%s", result.err, result.output)
	}
	if result = runCodeWork(t, repo, nil, "managed", "integrate", "demo", "--validate", "check"); result.err != nil {
		t.Fatalf("managed integrate failed: %v\n%s", result.err, result.output)
	}
	if result = runCodeWork(t, repo, nil, "managed", "cleanup", "demo"); result.err != nil {
		t.Fatalf("managed cleanup failed: %v\n%s", result.err, result.output)
	}
}

func TestManagedCommandReadyIntegrationAndFailureRetention(t *testing.T) {
	repo := setupCommandRepo(t)
	path := startTask(t, repo, "success")
	commitTask(t, path, "success")
	if result := runCodeWork(t, path, nil, "ready"); result.err != nil {
		t.Fatalf("ready failed: %v\n%s", result.err, result.output)
	}
	if result := runCodeWork(t, repo, nil, "merge", "success", "--validate", "check"); result.err != nil {
		t.Fatalf("ready integration failed: %v\n%s", result.err, result.output)
	}
	record, err := managedworktree.LoadRecord(filepath.Join(repo, ".git", "managed-worktrees"), "success")
	if err != nil || record.State != managedworktree.Integrated {
		t.Fatalf("successful integration state = %s, %v", record.State, err)
	}

	path = startTask(t, repo, "failure")
	commitTask(t, path, "failure")
	if result := runCodeWork(t, path, nil, "ready"); result.err != nil {
		t.Fatal(result.output)
	}
	result := runCodeWork(t, repo, map[string]string{"CODE_WORK_NIX_FAIL": "1"}, "merge", "failure", "--validate", "check")
	if result.err == nil {
		t.Fatal("failed validation unexpectedly succeeded")
	}
	record, err = managedworktree.LoadRecord(filepath.Join(repo, ".git", "managed-worktrees"), "failure")
	if err != nil || record.State != managedworktree.Ready || !pathExists(record.Path) {
		t.Fatalf("failed integration did not retain task: state=%s path=%v err=%v", record.State, pathExists(record.Path), err)
	}
}

func TestManagedCommandRejectsDirtyNonReadyAndBranchMismatch(t *testing.T) {
	repo := setupCommandRepo(t)
	path := startTask(t, repo, "unsafe")
	if err := os.WriteFile(filepath.Join(repo, "dirty"), []byte("dirty"), 0o644); err != nil {
		t.Fatal(err)
	}
	if result := runCodeWork(t, repo, nil, "merge", "unsafe", "--validate", "check"); result.err == nil {
		t.Fatal("dirty main checkout was accepted")
	}
	if err := os.Remove(filepath.Join(repo, "dirty")); err != nil {
		t.Fatal(err)
	}
	if result := runCodeWork(t, repo, nil, "merge", "unsafe", "--validate", "check"); result.err == nil {
		t.Fatal("non-ready task was accepted")
	}
	commitTask(t, path, "unsafe")
	if result := runCodeWork(t, path, nil, "ready"); result.err != nil {
		t.Fatalf("ready setup failed: %v\n%s", result.err, result.output)
	}
	record, err := managedworktree.LoadRecord(filepath.Join(repo, ".git", "managed-worktrees"), "unsafe")
	if err != nil {
		t.Fatal(err)
	}
	record.Branch = "managed/other"
	if err := managedworktree.SaveRecord(filepath.Join(repo, ".git", "managed-worktrees"), record); err != nil {
		t.Fatal(err)
	}
	if result := runCodeWork(t, repo, nil, "merge", "unsafe", "--validate", "check"); result.err == nil {
		t.Fatal("branch-mismatched task was accepted")
	}
}

func TestManagedReadyRejectsStagedChanges(t *testing.T) {
	repo := setupCommandRepo(t)
	path := startTask(t, repo, "staged")
	if err := os.WriteFile(filepath.Join(path, "staged"), []byte("staged\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	git(t, path, "add", "staged")
	result := runCodeWork(t, path, nil, "ready")
	if result.err == nil || !strings.Contains(result.output, "uncommitted changes") {
		t.Fatalf("ready accepted staged change: %v\n%s", result.err, result.output)
	}
	record, err := managedworktree.LoadRecord(filepath.Join(repo, ".git", "managed-worktrees"), "staged")
	if err != nil || record.State != managedworktree.Active {
		t.Fatalf("staged denial changed task state: %s, %v", record.State, err)
	}
}

func TestLegacyPruneUsesManagedLifecycleLock(t *testing.T) {
	repo := setupCommandRepo(t)
	path := startTask(t, repo, "serialized")
	commitTask(t, path, "serialized")
	stateDir := filepath.Join(repo, ".git", "managed-worktrees")
	lock, err := managedworktree.AcquireLock(stateDir, 0)
	if err != nil {
		t.Fatal(err)
	}
	if result := runCodeWork(t, path, nil, "ready"); result.err == nil {
		t.Fatal("lifecycle operation ignored the shared lock")
	}
	if result := runCodeWork(t, repo, nil, "prune"); result.err == nil {
		t.Fatal("legacy prune ignored the managed lifecycle lock")
	}
	if err := lock.Release(); err != nil {
		t.Fatal(err)
	}
	if result := runCodeWork(t, path, nil, "ready"); result.err != nil {
		t.Fatalf("unlocked lifecycle operation failed: %v\n%s", result.err, result.output)
	}
	if result := runCodeWork(t, repo, nil, "prune"); result.err != nil {
		t.Fatalf("unlocked prune failed: %v\n%s", result.err, result.output)
	}
}

func pathExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
