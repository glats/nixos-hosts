// Command code-work manages named git worktrees under <repo>/.worktrees
// with a create/done/abort/list/prune lifecycle.
//
// Port of bin/code-work: usage text, messages, exit codes and branch guards
// preserved. REPO_ROOT is the main repository root (first entry of
// `git worktree list --porcelain`), so the tool works both from the main
// checkout and from any linked worktree.
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
)

// gitignoreRe matches the grep -qE '^\.(worktrees|worktrees/)' check.
var gitignoreRe = regexp.MustCompile(`^\.(worktrees|worktrees/)`)

const usageTemplate = `Usage: %[1]s <worktree-name>    Create a named worktree
       %[1]s --done            Finish worktree (success: cleanup after push)
       %[1]s --abort           Discard worktree (failure: force remove)
       %[1]s --list            List all worktrees
       %[1]s --prune           Prune stale worktree references
       %[1]s --help            Show this help message

Examples:
  %[1]s my-feature       Create worktree 'my-feature' from current branch
  %[1]s --done           Finish current worktree (run from inside it)
  %[1]s --abort          Discard current worktree without saving
`

// die ports the bash die(): "Error: <msg>" to stderr, exit 1.
func die(msg string) {
	fmt.Fprintln(os.Stderr, "Error:", msg)
	os.Exit(1)
}

// dieCode is die() with the bash die's optional second argument.
func dieCode(msg string, code int) {
	fmt.Fprintln(os.Stderr, "Error:", msg)
	os.Exit(code)
}

// usage ports the bash usage(): optional message, heredoc to stderr, exit 2.
func usage(scriptName, msg string) {
	if msg != "" {
		fmt.Fprintln(os.Stderr, "Error:", msg)
		fmt.Fprintln(os.Stderr, "")
	}
	fmt.Fprintf(os.Stderr, usageTemplate, scriptName)
	os.Exit(2)
}

// exitFromErr maps a subprocess failure to the shell's exit-code semantics:
// propagate the child's exit code, or 127 when the command could not run at
// all (bash prints a shell-level "command not found" line; the closest
// portable equivalent is the exec error itself).
func exitFromErr(err error) {
	if exitErr, ok := err.(*exec.ExitError); ok {
		os.Exit(exitErr.ExitCode())
	}
	fmt.Fprintln(os.Stderr, "Error:", err)
	os.Exit(127)
}

// gitRun executes git with inherited stdio and returns the error; callers
// decide whether it is fatal (bash: bare command under set -e, or an
// if-condition).
func gitRun(args ...string) error {
	cmd := exec.Command("git", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// gitFail is gitRun with set -e semantics: a failed subprocess terminates
// the script with git's exit code.
func gitFail(args ...string) {
	if err := gitRun(args...); err != nil {
		exitFromErr(err)
	}
}

// gitOut runs git capturing stdout with stderr discarded (bash: 2>/dev/null
// inside command substitution) and strips trailing newlines like $(...).
func gitOut(args ...string) (string, error) {
	out, err := exec.Command("git", args...).Output()
	if err != nil {
		return "", err
	}
	return strings.TrimRight(string(out), "\n"), nil
}

// gitCapture runs git capturing stdout with stderr inherited (bash: command
// substitution without redirection) and strips trailing newlines; a failed
// subprocess terminates the script with git's exit code.
func gitCapture(args ...string) string {
	cmd := exec.Command("git", args...)
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	if err != nil {
		exitFromErr(err)
	}
	return strings.TrimRight(string(out), "\n")
}

// resolveRepoRoot ports the REPO_ROOT=$(git worktree list --porcelain |
// grep "^worktree " | head -1 | sed ...) determination: the first porcelain
// entry is the main repo root; failure or no entries yields "".
func resolveRepoRoot() string {
	out, err := exec.Command("git", "worktree", "list", "--porcelain").Output()
	if err != nil {
		return ""
	}
	return gitutil.MainWorktree(string(out))
}

// getCurrentBranch ports get_current_branch(): abbreviated ref of HEAD,
// dying on failure or detached HEAD.
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

// hasUpstream ports has_upstream(): silent rev-parse of the branch's
// upstream ref.
func hasUpstream(branch string) bool {
	return exec.Command("git", "rev-parse", "--abbrev-ref", branch+"@{u}").Run() == nil
}

// hasUncommittedChanges ports the [[ -n "$(git status --porcelain 2>/dev/null)" ]]
// dirty checks; a failed status counts as clean, as in the bash original.
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

// refExists ports the `git show-ref --verify --quiet refs/...` checks.
func refExists(ref string) bool {
	return exec.Command("git", "show-ref", "--verify", "--quiet", ref).Run() == nil
}

// readMarker ports read_marker(): the base branch recorded in the
// worktree's .worktree-base marker, or the multi-line recovery instructions
// and exit 1 when the marker is missing.
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
		fmt.Fprintln(os.Stderr, err) // bash: cat failure under set -e
		os.Exit(1)
	}
	return strings.TrimRight(string(data), "\n")
}

// checkGitignore ports check_gitignore(): non-fatal warning when
// .worktrees is not ignored.
func checkGitignore(repoRoot string) {
	data, err := os.ReadFile(filepath.Join(repoRoot, ".gitignore"))
	if err != nil {
		return // bash only checks when .gitignore exists
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
	switch cmd {
	case "--done":
		cmdDone(pwd, repoRoot, worktreesDir)
	case "--abort":
		cmdAbort(pwd, repoRoot, worktreesDir)
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

// cmdCreate ports cmd_create(): create worktree <name> from the current
// branch (or an existing local/origin branch of the same name).
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

	// Resolve branch: local, remote, or create fresh.
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
	fmt.Println("  opencode")
	fmt.Println("")
	fmt.Println("When done:")
	fmt.Println("  code-work --done     # success: cleanup after push")
	fmt.Println("  code-work --abort    # discard: throw away everything")
	fmt.Println("=====================================")
}

// cmdDone ports cmd_done(): finish the current worktree after its branch
// has been pushed — return to the base branch, remove the worktree, delete
// the branch and prune.
func cmdDone(pwd, repoRoot, worktreesDir string) {
	if repoRoot == "" {
		die("Not inside a git repository")
	}
	if !gitutil.InWorktrees(pwd, worktreesDir) {
		die(fmt.Sprintf("Not inside a worktree directory (current: %s, worktrees: %s)", pwd, worktreesDir))
	}
	wtName := gitutil.WorktreeName(pwd, worktreesDir)
	wtPath := pwd

	baseBranch := readMarker(wtPath, repoRoot, worktreesDir)

	if hasUncommittedChanges(wtPath) {
		fmt.Fprintf(os.Stderr, "Error: uncommitted changes in worktree '%s'.\n", wtName)
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "Commit before finishing:")
		fmt.Fprintln(os.Stderr, "  git add -A && git commit -m 'message'")
		os.Exit(1)
	}

	currentBranch := gitCapture("-C", wtPath, "rev-parse", "--abbrev-ref", "HEAD")
	if !hasUpstream(currentBranch) {
		fmt.Fprintf(os.Stderr, "Error: Branch '%s' has not been pushed to upstream.\n", currentBranch)
		fmt.Fprintln(os.Stderr, "Local commits would be lost on deletion.")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "To save your work before cleaning up:")
		fmt.Fprintf(os.Stderr, "  git push -u origin %s\n", currentBranch)
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "Then run 'code-work --done' again.")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "To force cleanup anyway:")
		fmt.Fprintf(os.Stderr, "  cd %s\n", repoRoot)
		fmt.Fprintf(os.Stderr, "  git branch -D %s\n", currentBranch)
		fmt.Fprintf(os.Stderr, "  git worktree remove %s\n", wtPath)
		fmt.Fprintln(os.Stderr, "  git worktree prune")
		os.Exit(1)
	}

	// === Cleanup ===
	if err := os.Chdir(repoRoot); err != nil {
		die(err.Error())
	}

	fmt.Printf("> Returning to base branch '%s'...\n", baseBranch)
	if err := gitRun("checkout", baseBranch); err != nil {
		die(fmt.Sprintf("Failed to checkout base branch '%s'. It may have been deleted.", baseBranch))
	}

	fmt.Printf("> Removing worktree '%s'...\n", wtName)
	if err := gitRun("worktree", "remove", wtPath, "--force"); err != nil {
		die(fmt.Sprintf("Failed to remove worktree at %s", wtPath))
	}

	fmt.Printf("> Deleting branch '%s'...\n", currentBranch)
	gitFail("branch", "-D", currentBranch)

	fmt.Fprintln(os.Stdout, "> Pruning stale worktree references...")
	gitFail("worktree", "prune")

	fmt.Println("")
	fmt.Println("=====================================")
	fmt.Printf("> Worktree '%s' done and cleaned up.\n", wtName)
	fmt.Printf("> Returned to branch '%s'.\n", baseBranch)
	fmt.Println("=====================================")
}

// cmdAbort ports cmd_abort(): discard the current worktree and its branch
// regardless of dirty state.
func cmdAbort(pwd, repoRoot, worktreesDir string) {
	if repoRoot == "" {
		die("Not inside a git repository")
	}
	if !gitutil.InWorktrees(pwd, worktreesDir) {
		die("Not inside a worktree directory")
	}
	wtName := gitutil.WorktreeName(pwd, worktreesDir)
	wtPath := pwd

	currentBranch := gitCapture("-C", wtPath, "rev-parse", "--abbrev-ref", "HEAD")

	fmt.Printf("> Discarding worktree '%s'...\n", wtName)

	if err := os.Chdir(repoRoot); err != nil {
		die(err.Error())
	}

	// git worktree remove --force 2>/dev/null || rm -rf "$wt_path"
	// (only stderr is discarded; stdout stays inherited)
	remove := exec.Command("git", "worktree", "remove", wtPath, "--force")
	remove.Stderr = io.Discard
	if err := remove.Run(); err != nil {
		if err := os.RemoveAll(wtPath); err != nil {
			fmt.Fprintln(os.Stderr, err) // rm -rf error under set -e
			os.Exit(1)
		}
	}

	// git branch -D ... 2>/dev/null || true (stdout visible, as in bash)
	branch := exec.Command("git", "branch", "-D", currentBranch)
	branch.Stderr = io.Discard
	_ = branch.Run()

	gitFail("worktree", "prune")

	fmt.Printf("> Worktree '%s' discarded.\n", wtName)
}

// cmdList ports cmd_list(): worktree table plus a current-worktree hint.
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

// cmdPrune ports cmd_prune(): drop stale worktree references.
func cmdPrune(repoRoot string) {
	if repoRoot == "" {
		die("Not inside a git repository")
	}
	gitFail("-C", repoRoot, "worktree", "prune")
	fmt.Println("> Stale worktree references pruned.")
}
