package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/glats/nixos-scripts/internal/managedworktree"
)

func managedGit(root string, args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = root
	out, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(out)), err
}

func managedStateDir(root string) string { return filepath.Join(root, ".git", "managed-worktrees") }

func managedCommonDir(root string) (string, error) {
	out, err := managedGit(root, "rev-parse", "--git-common-dir")
	if err != nil {
		return "", err
	}
	if !filepath.IsAbs(out) {
		out = filepath.Join(root, out)
	}
	return filepath.Clean(out), nil
}

func validateManagedSelector(cwd, root, branch string) error {
	if !filepath.IsAbs(cwd) || filepath.Clean(cwd) != filepath.Clean(root) {
		return fmt.Errorf("managed operation requires the main checkout")
	}
	if branch == "HEAD" || branch == "" {
		return fmt.Errorf("managed operation requires an attached main branch")
	}
	return nil
}

func managedCommitReady(status string) bool { return status == "" }

func managedClean(root string) error {
	status, err := managedGit(root, "status", "--porcelain")
	if err != nil {
		return err
	}
	if status == "?? .worktree-base" {
		return nil
	}
	if !managedCommitReady(status) {
		return fmt.Errorf("checkout has uncommitted changes")
	}
	return nil
}

func managedRoot() (string, string, error) {
	root := resolveRepoRoot()
	if root == "" {
		return "", "", fmt.Errorf("not inside a git repository")
	}
	cwd, err := os.Getwd()
	if err != nil {
		return "", "", err
	}
	return root, cwd, nil
}

func managedRun(root string, args ...string) error {
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Dir = root
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func managedArgs(args []string) (string, string, error) {
	if len(args) < 1 || len(args) > 2 {
		return "", "", fmt.Errorf("usage: managed check <id> <fmt|eval|flake-check|build> [target]")
	}
	check := args[0]
	target := ""
	if len(args) == 2 {
		target = args[1]
	}
	if strings.HasPrefix(check, "-") || strings.HasPrefix(target, "-") {
		return "", "", fmt.Errorf("options are not accepted")
	}
	switch check {
	case "fmt", "flake-check":
		if target != "" {
			return "", "", fmt.Errorf("%s does not accept a target", check)
		}
	case "eval", "build":
		if target == "" {
			return "", "", fmt.Errorf("%s requires a scoped target", check)
		}
	default:
		return "", "", fmt.Errorf("check %q is not allowlisted", check)
	}
	return check, target, nil
}

func validateManagedCheckArgs(args []string) error { _, _, err := managedArgs(args); return err }

func managedCheck(root, id, check string, target string) error {
	record, err := managedworktree.LoadRecord(managedStateDir(root), id)
	if err != nil {
		return fmt.Errorf("load task: %w", err)
	}
	if record.State != managedworktree.Active && record.State != managedworktree.Ready {
		return fmt.Errorf("task %q is not active", id)
	}
	if filepath.Clean(record.Path) != filepath.Clean(managedworktree.PathFor(root, id)) {
		return fmt.Errorf("task workspace path mismatch")
	}
	args := []string{check}
	if target != "" {
		args = append(args, target)
	}
	if err := validateManagedCheckArgs(args); err != nil {
		return err
	}
	var command []string
	switch check {
	case "fmt":
		command = []string{"nix", "fmt", "--", "."}
	case "eval":
		command = []string{"nix", "eval", target}
	case "flake-check":
		command = []string{"nix", "flake", "check", "--no-build"}
	case "build":
		command = []string{"nix", "build", target, "--no-link", "--max-jobs", "1", "--cores", "1"}
	}
	cmd := exec.Command(command[0], command[1:]...)
	cmd.Dir = record.Path
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func managedStart(root, cwd string, args []string) error {
	if len(args) < 1 || len(args) > 3 {
		return fmt.Errorf("usage: new <task-id> [--base <branch>]")
	}
	id := args[0]
	if !managedworktree.ValidTaskID(id) {
		return fmt.Errorf("invalid task id %q", id)
	}
	branch, err := managedGit(root, "branch", "--show-current")
	if err != nil {
		return err
	}
	if err := validateManagedSelector(cwd, root, branch); err != nil {
		return err
	}
	if err := managedClean(root); err != nil {
		return err
	}
	base := branch
	if len(args) == 3 && args[1] == "--base" {
		base = args[2]
	} else if len(args) != 1 {
		return fmt.Errorf("usage: new <task-id> [--base <branch>]")
	}
	stateDir, err := managedCommonDir(root)
	if err != nil {
		return err
	}
	stateDir = filepath.Join(stateDir, "managed-worktrees")
	lock, err := managedworktree.AcquireLock(stateDir, 0)
	if err != nil {
		return err
	}
	defer lock.Release()
	if existing, err := managedworktree.LoadRecord(stateDir, id); err == nil {
		if existing.Branch == managedworktree.BranchFor(id) && existing.Path == managedworktree.PathFor(root, id) && existing.BaseBranch == base && existing.State == managedworktree.Active {
			fmt.Printf("Reusing active task %s at %s\n", id, existing.Path)
			return nil
		}
		return fmt.Errorf("recorded task %q does not match requested workspace", id)
	}
	path := managedworktree.PathFor(root, id)
	branchName := managedworktree.BranchFor(id)
	if _, err := os.Stat(path); err == nil {
		return fmt.Errorf("worktree already exists at %s", path)
	}
	baseCommit, err := managedGit(root, "rev-parse", base)
	if err != nil {
		return fmt.Errorf("resolve base: %w", err)
	}
	if err := managedRun(root, "git", "branch", branchName, base); err != nil {
		return err
	}
	if err := managedRun(root, "git", "worktree", "add", path, branchName); err != nil {
		managedRun(root, "git", "branch", "-D", branchName)
		return err
	}
	if err := managedRun(root, "git", "worktree", "lock", path, "--reason", "managed writing task"); err != nil {
		return err
	}
	now := time.Now().UTC()
	record := managedworktree.Record{ID: id, Branch: branchName, Path: path, BaseBranch: base, BaseCommit: baseCommit, State: managedworktree.Active, CreatedAt: now, UpdatedAt: now}
	if err := managedworktree.SaveRecord(stateDir, record); err != nil {
		return err
	}
	fmt.Printf("Created managed task %s at %s\n", id, path)
	return launchManagedAgent(path)
}

func launchManagedAgent(path string) error {
	cmd := exec.Command("opencode", "--agent", "managed-writing-task", path)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	fmt.Printf("Launching: opencode --agent managed-writing-task %s\n", path)
	return cmd.Run()
}

func managedReady(root, cwd, id string) error {
	lock, err := managedworktree.AcquireLock(managedStateDir(root), 0)
	if err != nil {
		return err
	}
	defer lock.Release()
	record, err := managedworktree.LoadRecord(managedStateDir(root), id)
	if err != nil {
		return err
	}
	if filepath.Clean(cwd) != filepath.Clean(record.Path) {
		return fmt.Errorf("ready must be requested from the assigned worktree")
	}
	if record.Branch != managedworktree.BranchFor(id) || filepath.Clean(record.Path) != filepath.Clean(managedworktree.PathFor(root, id)) {
		return fmt.Errorf("task metadata mismatch")
	}
	if err := managedClean(record.Path); err != nil {
		return err
	}
	if err := managedworktree.Transition(&record, managedworktree.Ready); err != nil {
		return err
	}
	return managedworktree.SaveRecord(managedStateDir(root), record)
}

func managedTransition(root, id string, next managedworktree.State) error {
	lock, err := managedworktree.AcquireLock(managedStateDir(root), 0)
	if err != nil {
		return err
	}
	defer lock.Release()
	record, err := managedworktree.LoadRecord(managedStateDir(root), id)
	if err != nil {
		return err
	}
	if err := managedworktree.Transition(&record, next); err != nil {
		return err
	}
	return managedworktree.SaveRecord(managedStateDir(root), record)
}

func managedInspect(root, id string) error {
	if id != "" {
		r, err := managedworktree.LoadRecord(managedStateDir(root), id)
		if err != nil {
			return err
		}
		fmt.Printf("%s %s %s\n", r.ID, r.State, r.Path)
		return nil
	}
	entries, err := os.ReadDir(managedStateDir(root))
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	for _, entry := range entries {
		if strings.HasSuffix(entry.Name(), ".json") {
			id := strings.TrimSuffix(entry.Name(), ".json")
			if err := managedInspect(root, id); err != nil {
				return err
			}
		}
	}
	return nil
}

func managedCleanup(root, id string) error {
	lock, err := managedworktree.AcquireLock(managedStateDir(root), 0)
	if err != nil {
		return err
	}
	defer lock.Release()
	record, err := managedworktree.LoadRecord(managedStateDir(root), id)
	if err != nil {
		return err
	}
	if record.State != managedworktree.Integrated && record.State != managedworktree.Abandoned {
		return fmt.Errorf("clean requires integrated or abandoned task")
	}
	managedRun(root, "git", "worktree", "unlock", record.Path)
	if err := managedRun(root, "git", "worktree", "remove", "--force", record.Path); err != nil {
		return err
	}
	if err := managedRun(root, "git", "branch", "-D", record.Branch); err != nil {
		return err
	}
	return os.Remove(filepath.Join(managedStateDir(root), id+".json"))
}

func managedIntegrate(root, cwd, id string, args []string) error {
	if len(args) < 2 || args[0] != "--validate" {
		return fmt.Errorf("usage: merge <id> --validate <check|build> [--activate <system|home>]")
	}
	branch, err := managedGit(root, "branch", "--show-current")
	if err != nil {
		return err
	}
	if err := validateManagedSelector(cwd, root, branch); err != nil {
		return err
	}
	if err := managedClean(root); err != nil {
		return err
	}
	record, err := managedworktree.LoadRecord(managedStateDir(root), id)
	if err != nil {
		return err
	}
	if record.State != managedworktree.Ready || record.Branch != managedworktree.BranchFor(id) {
		return fmt.Errorf("task is not ready or branch mismatches")
	}
	validate := args[1]
	if validate != "check" && validate != "build" {
		return fmt.Errorf("validation must be check or build")
	}
	lock, err := managedworktree.AcquireLock(managedStateDir(root), 0)
	if err != nil {
		return err
	}
	defer lock.Release()
	if err := managedRun(root, "git", "merge", "--no-ff", "--no-edit", record.Branch); err != nil {
		return err
	}
	if validate == "check" {
		err = managedRun(root, "nix", "flake", "check", "--no-build")
	} else {
		err = managedRun(root, "nixos-build", "build")
	}
	if err != nil {
		managedRun(root, "git", "reset", "--merge", "ORIG_HEAD")
		return fmt.Errorf("validation failed; merge rolled back: %w", err)
	}
	if len(args) > 2 {
		if len(args) != 4 || args[2] != "--activate" || (args[3] != "system" && args[3] != "home") {
			return fmt.Errorf("activation must be --activate system|home")
		}
		if args[3] == "system" {
			err = managedRun(root, "nixos-build", "switch")
		} else {
			err = managedRun(root, "home-manager", "switch", "--flake", ".")
		}
		if err != nil {
			return err
		}
	}
	if err := managedworktree.Transition(&record, managedworktree.Integrated); err != nil {
		return err
	}
	return managedworktree.SaveRecord(managedStateDir(root), record)
}

func managedTopLevelCommand(args []string) error {
	root, cwd, err := managedRoot()
	if err != nil {
		return err
	}
	if len(args) == 0 {
		return fmt.Errorf("usage: new|check|ready|status|merge|clean|abandon|recover-lock")
	}
	switch args[0] {
	case "new":
		return managedStart(root, cwd, args[1:])
	case "ready":
		if len(args) != 1 {
			return fmt.Errorf("usage: ready")
		}
		id, err := managedworktree.ResolveTaskID(managedStateDir(root), cwd)
		if err != nil {
			return err
		}
		return managedReady(root, cwd, id)
	case "check":
		check, target, err := managedArgs(args[1:])
		if err != nil {
			return err
		}
		id, err := managedworktree.ResolveTaskID(managedStateDir(root), cwd)
		if err != nil {
			return err
		}
		return managedCheck(root, id, check, target)
	case "status":
		if len(args) != 1 {
			return fmt.Errorf("usage: status")
		}
		id, err := managedworktree.ResolveTaskID(managedStateDir(root), cwd)
		if err != nil {
			return err
		}
		return managedInspect(root, id)
	case "merge":
		if len(args) < 4 {
			return fmt.Errorf("usage: merge <id> --validate <check|build>")
		}
		return managedIntegrate(root, cwd, args[1], args[2:])
	case "abandon":
		if len(args) != 2 {
			return fmt.Errorf("usage: abandon <id>")
		}
		return managedTransition(root, args[1], managedworktree.Abandoned)
	case "clean":
		if len(args) != 2 {
			return fmt.Errorf("usage: clean <id>")
		}
		return managedCleanup(root, args[1])
	case "recover-lock":
		state, err := managedCommonDir(root)
		if err != nil {
			return err
		}
		return os.Remove(filepath.Join(state, "managed-worktrees", ".lock"))
	default:
		return fmt.Errorf("unknown managed command %q", args[0])
	}
}

// managedCommand is a one-release hidden compatibility adapter. It keeps old
// task-addressed forms working while directing new callers to the top-level API.
func managedCommand(args []string) error {
	fmt.Fprintln(os.Stderr, "code-work managed is deprecated; use code-work <canonical form>")
	root, cwd, err := managedRoot()
	if err != nil {
		return err
	}
	if len(args) == 0 {
		return fmt.Errorf("usage: managed start|ready|check|integrate|inspect|cleanup|abandon|recover-lock")
	}
	switch args[0] {
	case "start":
		return managedStart(root, cwd, args[1:])
	case "ready":
		if len(args) != 2 {
			return fmt.Errorf("usage: managed ready <id>")
		}
		return managedReady(root, cwd, args[1])
	case "check":
		if len(args) != 3 && len(args) != 4 {
			return fmt.Errorf("usage: managed check <id> <check> [target]")
		}
		return managedCheck(root, args[1], args[2], func() string {
			if len(args) == 4 {
				return args[3]
			}
			return ""
		}())
	case "integrate":
		if len(args) < 4 {
			return fmt.Errorf("usage: managed integrate <id> --validate <check|build>")
		}
		return managedIntegrate(root, cwd, args[1], args[2:])
	case "inspect":
		if len(args) > 2 {
			return fmt.Errorf("usage: managed inspect [id]")
		}
		id := ""
		if len(args) == 2 {
			id = args[1]
		}
		return managedInspect(root, id)
	case "abandon":
		if len(args) != 2 {
			return fmt.Errorf("usage: managed abandon <id>")
		}
		return managedTransition(root, args[1], managedworktree.Abandoned)
	case "cleanup":
		if len(args) != 2 {
			return fmt.Errorf("usage: managed cleanup <id>")
		}
		return managedCleanup(root, args[1])
	case "recover-lock":
		state, err := managedCommonDir(root)
		if err != nil {
			return err
		}
		return os.Remove(filepath.Join(state, "managed-worktrees", ".lock"))
	default:
		return fmt.Errorf("unknown managed command %q", args[0])
	}
}
