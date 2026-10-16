package main

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/glats/nixos-scripts/internal/gitutil"
	"github.com/glats/nixos-scripts/internal/managedworktree"
)

var gitignoreRe = regexp.MustCompile(`^\.(worktrees|worktrees/)`)

const usageTemplate = `Usage: %[1]s <worktree-name>    Create a named worktree
	%[1]s new <task> [--base <branch>]
	%[1]s check <fmt|eval|flake-check|build> [target]
	%[1]s ready | status
	%[1]s merge <task> --validate <check|build> [--activate <system|home>]
	%[1]s clean|abandon <task> | recover-lock
        %[1]s --done [task]     Finish worktree and show safe cleanup guidance
        %[1]s --abort <task>    Discard worktree (destructive: force remove)
       %[1]s --list            List all worktrees
       %[1]s --prune           Prune stale worktree references
       %[1]s --help            Show this help message

Examples:
  %[1]s my-feature       Create worktree 'my-feature' from current branch
  %[1]s --done my-feature    Finish worktree 'my-feature'
  %[1]s --abort my-feature   Discard worktree 'my-feature' without saving
Managed writing tasks use cwd for check, ready, and status.
`

func die(msg string) {
	fmt.Fprintln(os.Stderr, "Error:", msg)
	os.Exit(1)
}

func dieCode(msg string, code int) {
	fmt.Fprintln(os.Stderr, "Error:", msg)
	os.Exit(code)
}

func usage(scriptName, msg string) {
	if msg != "" {
		fmt.Fprintln(os.Stderr, "Error:", msg)
		fmt.Fprintln(os.Stderr, "")
	}
	fmt.Fprintf(os.Stderr, usageTemplate, scriptName)
	os.Exit(2)
}

func exitFromErr(err error) {
	if exitErr, ok := err.(*exec.ExitError); ok {
		os.Exit(exitErr.ExitCode())
	}
	fmt.Fprintln(os.Stderr, "Error:", err)
	os.Exit(127)
}

func gitRun(args ...string) error {
	cmd := exec.Command("git", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func gitFail(args ...string) {
	if err := gitRun(args...); err != nil {
		exitFromErr(err)
	}
}

func gitOut(args ...string) (string, error) {
	out, err := exec.Command("git", args...).Output()
	if err != nil {
		return "", err
	}
	return strings.TrimRight(string(out), "\n"), nil
}

func gitCapture(args ...string) string {
	cmd := exec.Command("git", args...)
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	if err != nil {
		exitFromErr(err)
	}
	return strings.TrimRight(string(out), "\n")
}

func resolveRepoRoot() string {
	out, err := exec.Command("git", "worktree", "list", "--porcelain").Output()
	if err != nil {
		return ""
	}
	return gitutil.MainWorktree(string(out))
}

func getCurrentBranch() string {
	branch, err := gitOut("rev-parse", "--abbrev-ref", "HEAD")
	if err != nil {
		die("Failed to determine current branch")
	}
	if branch == "HEAD" {
		die("Detached HEAD state. Checkout a branch before creating a worktree.")
	}
	return branch
}

func hasUncommittedChanges(dir string) bool {
	args := []string{"status", "--porcelain"}
	if dir != "" {
		args = append([]string{"-C", dir}, args...)
	}
	out, err := exec.Command("git", args...).Output()
	if err != nil {
		return false
	}
	return string(out) != ""
}

func refExists(ref string) bool {
	return exec.Command("git", "show-ref", "--verify", "--quiet", ref).Run() == nil
}

func readMarker(wtPath, repoRoot, worktreesDir string) string {
	marker := filepath.Join(wtPath, ".worktree-base")
	fi, err := os.Stat(marker)
	if err != nil || !fi.Mode().IsRegular() {
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "Error: No .worktree-base found in this worktree.")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "This worktree was created with an older version or manually.")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "To finish it manually:")
		fmt.Fprintf(os.Stderr, "  1. cd %s\n", repoRoot)
		fmt.Fprintln(os.Stderr, "  2. git checkout <base-branch>")
		fmt.Fprintf(os.Stderr, "  3. git worktree remove %s\n", wtPath)
		fmt.Fprintf(os.Stderr, "  4. git branch -d %s\n", gitutil.WorktreeName(wtPath, worktreesDir))
		os.Exit(1)
	}
	data, err := os.ReadFile(marker)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	return strings.TrimRight(string(data), "\n")
}

func checkGitignore(repoRoot string) {
	data, err := os.ReadFile(filepath.Join(repoRoot, ".gitignore"))
	if err != nil {
		return
	}
	for _, line := range strings.Split(string(data), "\n") {
		if gitignoreRe.MatchString(line) {
			return
		}
	}
	fmt.Fprintln(os.Stderr, "Warning: .worktrees/ not in .gitignore. Add it to prevent accidental commits.")
}

func main() {
	pwd, err := os.Getwd()
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}
	repoRoot := resolveRepoRoot()
	worktreesDir := ""
	if repoRoot != "" {
		worktreesDir = filepath.Join(repoRoot, ".worktrees")
	}
	scriptName := filepath.Base(os.Args[0])

	cmd := ""
	args := os.Args[1:]
	if len(args) > 0 {
		cmd = args[0]
	}
	if cmd == "managed" {
		if err := managedCommand(args[1:]); err != nil {
			die(err.Error())
		}
		return
	}
	switch cmd {
	case "new", "check", "ready", "status", "merge", "clean", "abandon", "recover-lock":
		if err := managedTopLevelCommand(args); err != nil {
			die(err.Error())
		}
	case "--done":
		if len(args) > 2 {
			usage(scriptName, "--done accepts at most one worktree name")
		}
		name := ""
		if len(args) == 2 {
			name = args[1]
		}
		cmdDone(pwd, repoRoot, worktreesDir, name)
	case "--abort":
		if len(args) != 2 {
			usage(scriptName, "--abort requires a worktree name")
		}
		cmdAbort(repoRoot, worktreesDir, args[1])
	case "--list", "list":
		cmdList(pwd, repoRoot, worktreesDir)
	case "--prune", "prune":
		cmdPrune(repoRoot)
	case "--help", "-h":
		usage(scriptName, "")
	case "":
		usage(scriptName, "Missing worktree name")
	default:
		cmdCreate(repoRoot, worktreesDir, args[0])
	}
}

func cmdCreate(repoRoot, worktreesDir, name string) {
	if name == "" {
		usage(filepath.Base(os.Args[0]), "Missing worktree name")
	}
	if repoRoot == "" {
		die("Not inside a git repository")
	}
	if !gitutil.ValidName(name) {
		dieCode(fmt.Sprintf("Invalid worktree name '%s'. Use alphanumeric, dots, hyphens, underscores, slashes. No leading slash.", name), 2)
	}

	wtDir := filepath.Join(worktreesDir, name)
	if fi, err := os.Stat(wtDir); err == nil && fi.IsDir() {
		die(fmt.Sprintf("Worktree '%s' already exists at %s", name, wtDir))
	}

	currentBranch := getCurrentBranch()

	if hasUncommittedChanges("") {
		fmt.Fprintf(os.Stderr, "Error: Current branch '%s' has uncommitted changes.\n", currentBranch)
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "Commit or stash before creating a worktree:")
		fmt.Fprintln(os.Stderr, "  git add -A && git commit -m 'message'")
		fmt.Fprintln(os.Stderr, "  # or: git stash")
		os.Exit(1)
	}

	if refExists("refs/heads/" + name) {
		fmt.Printf("> Using existing branch '%s'\n", name)
	} else if refExists("refs/remotes/origin/" + name) {
		fmt.Printf("> Creating local branch '%s' from origin/%s\n", name, name)
		gitFail("branch", name, "origin/"+name)
	} else {
		fmt.Printf("> Creating new branch '%s' from '%s'\n", name, currentBranch)
		gitFail("branch", name, currentBranch)
	}

	gitFail("worktree", "add", wtDir, name)

	if err := os.WriteFile(filepath.Join(wtDir, ".worktree-base"), []byte(currentBranch+"\n"), 0o644); err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}

	checkGitignore(repoRoot)

	fmt.Println("=====================================")
	fmt.Printf("> Created worktree: %s\n", name)
	fmt.Printf("> Location: %s\n", wtDir)
	fmt.Printf("> Branch: %s\n", name)
	fmt.Println("")
	fmt.Println("To work in this worktree:")
	fmt.Printf("  cd %s\n", wtDir)
	fmt.Println("  # start your preferred assistant: opencode, claude, ...")
	fmt.Println("")
	fmt.Println("When done:")
	fmt.Printf("  code-work --done %s    # show safe native cleanup guidance\n", name)
	fmt.Printf("  code-work --abort %s   # discard everything (destructive)\n", name)
	fmt.Println("=====================================")
}

func cmdDone(pwd, repoRoot, worktreesDir, name string) {
	if repoRoot == "" {
		die("Not inside a git repository")
	}
	wtPath := ""
	if name == "" {
		if !gitutil.InWorktrees(pwd, worktreesDir) {
			die(fmt.Sprintf("Not inside a worktree directory (current: %s, worktrees: %s)", pwd, worktreesDir))
		}
		name = gitutil.WorktreeName(pwd, worktreesDir)
		wtPath = pwd
	} else if !gitutil.ValidName(name) {
		dieCode(fmt.Sprintf("Invalid worktree name '%s'.", name), 2)
	} else {
		wtPath = filepath.Join(worktreesDir, name)
	}
	if fi, err := os.Stat(wtPath); err != nil || !fi.IsDir() {
		die(fmt.Sprintf("Worktree '%s' not found at %s", name, wtPath))
	}

	baseBranch := readMarker(wtPath, repoRoot, worktreesDir)

	if hasUncommittedChanges(wtPath) {
		fmt.Fprintf(os.Stderr, "Warning: uncommitted changes in worktree '%s'.\n", name)
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "Commit or stash them before integrating:")
		fmt.Fprintln(os.Stderr, "  git add -A && git commit -m 'message'")
		fmt.Fprintln(os.Stderr, "  # or: git stash")
		fmt.Fprintln(os.Stderr, "")
	}

	currentBranch := gitCapture("-C", wtPath, "rev-parse", "--abbrev-ref", "HEAD")
	fmt.Println("=====================================")
	fmt.Printf("> Worktree '%s' is ready for manual cleanup.\n", name)
	fmt.Println("")
	fmt.Println("Integrate your branch before removing it:")
	fmt.Printf("  1. Merge '%s' into '%s', or open and merge a PR\n", currentBranch, baseBranch)
	fmt.Printf("  2. cd %s\n", repoRoot)
	fmt.Printf("  3. git worktree remove %s\n", wtPath)
	fmt.Printf("  4. git branch -d %s\n", currentBranch)
	fmt.Println("")
	fmt.Fprintf(os.Stdout, "To discard this worktree instead, run 'code-work --abort %s' (destructive).\n", name)
	fmt.Fprintln(os.Stdout, "Use 'code-work --list' or 'code-work --prune' to inspect worktrees.")
	fmt.Println("=====================================")
}

func cmdAbort(repoRoot, worktreesDir, name string) {
	if repoRoot == "" {
		die("Not inside a git repository")
	}
	if !gitutil.ValidName(name) {
		dieCode(fmt.Sprintf("Invalid worktree name '%s'.", name), 2)
	}
	wtPath := filepath.Join(worktreesDir, name)
	if fi, err := os.Stat(wtPath); err != nil || !fi.IsDir() {
		die(fmt.Sprintf("Worktree '%s' not found at %s", name, wtPath))
	}
	if cwd, err := os.Getwd(); err == nil && filepath.Clean(cwd) == filepath.Clean(wtPath) {
		die(fmt.Sprintf("Refusing to discard worktree '%s': you are inside it. Run from the main checkout.", name))
	}

	currentBranch := gitCapture("-C", wtPath, "rev-parse", "--abbrev-ref", "HEAD")

	fmt.Printf("> Discarding worktree '%s'...\n", name)

	remove := exec.Command("git", "worktree", "remove", wtPath, "--force")
	remove.Stderr = io.Discard
	if err := remove.Run(); err != nil {
		if err := os.RemoveAll(wtPath); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	}

	branch := exec.Command("git", "branch", "-D", currentBranch)
	branch.Stderr = io.Discard
	_ = branch.Run()

	cmdPrune(repoRoot)

	fmt.Printf("> Worktree '%s' discarded.\n", name)
}

func cmdList(pwd, repoRoot, worktreesDir string) {
	if repoRoot == "" {
		die("Not inside a git repository")
	}
	gitFail("-C", repoRoot, "worktree", "list")
	if gitutil.InWorktrees(pwd, worktreesDir) {
		fmt.Println("")
		fmt.Printf("  (current worktree: %s)\n", gitutil.WorktreeName(pwd, worktreesDir))
	}
}

func cmdPrune(repoRoot string) {
	if repoRoot == "" {
		die("Not inside a git repository")
	}
	commonDir, err := managedCommonDir(repoRoot)
	if err != nil {
		die("Failed to determine Git common directory")
	}
	lock, err := managedworktree.AcquireLock(filepath.Join(commonDir, "managed-worktrees"), 0)
	if err != nil {
		die(err.Error())
	}
	defer lock.Release()
	gitFail("-C", repoRoot, "worktree", "prune")
	fmt.Println("> Stale worktree references pruned.")
}
