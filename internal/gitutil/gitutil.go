// Package gitutil implements the git-worktree plumbing used by the
// code-work command: parsing of `git worktree list --porcelain` output and
// the worktree-directory naming rules from the bash original.
package gitutil

import (
	"regexp"
	"strings"
)

// NameRe is the worktree-name contract from the bash original: starts with
// an alphanumeric, then alphanumerics, dots, hyphens, underscores and
// slashes. No leading slash.
var NameRe = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9._/-]*$`)

// Worktree is one entry of `git worktree list --porcelain` output.
type Worktree struct {
	Path     string // absolute path of the worktree
	Head     string // commit SHA the worktree HEAD points at ("HEAD <sha>" line)
	Branch   string // full ref from the "branch <ref>" line, when present
	Detached bool   // "detached" line present
	Bare     bool   // "bare" line present
}

// ParseWorktreeList parses the full porcelain output of
// `git worktree list --porcelain` into entries, in output order. Blank
// separator lines and unknown attributes are ignored.
func ParseWorktreeList(out string) []Worktree {
	var entries []Worktree
	var cur *Worktree
	for _, line := range strings.Split(out, "\n") {
		switch {
		case strings.HasPrefix(line, "worktree "):
			entries = append(entries, Worktree{Path: strings.TrimPrefix(line, "worktree ")})
			cur = &entries[len(entries)-1]
		case cur == nil:
			// Attribute line before any worktree header: nothing to attach
			// it to (should not happen, but bash's grep-based original was
			// equally indifferent).
		case strings.HasPrefix(line, "HEAD "):
			cur.Head = strings.TrimPrefix(line, "HEAD ")
		case strings.HasPrefix(line, "branch "):
			cur.Branch = strings.TrimPrefix(line, "branch ")
		case line == "detached":
			cur.Detached = true
		case line == "bare":
			cur.Bare = true
		}
	}
	return entries
}

// MainWorktree returns the path of the first worktree in porcelain output —
// the main repository root — or "" when out has no worktree entries (the
// bash original landed on "" via `grep | head -1 | sed` when the command
// failed outside a git repository).
func MainWorktree(out string) string {
	entries := ParseWorktreeList(out)
	if len(entries) == 0 {
		return ""
	}
	return entries[0].Path
}

// InWorktrees reports whether dir sits inside worktreesDir using the same
// shell prefix match as the bash original ([[ "$PWD" == "$WORKTREES_DIR"* ]]):
// plain string prefix, no path separator required. An empty worktreesDir
// never matches (the bash check was guarded by a non-empty REPO_ROOT).
func InWorktrees(dir, worktreesDir string) bool {
	return worktreesDir != "" && strings.HasPrefix(dir, worktreesDir)
}

// WorktreeName strips the "worktreesDir/" prefix from dir, mirroring the
// bash ${PWD#$WORKTREES_DIR/} expansion used for nested names like
// feat/multi-github-identity. When dir does not carry the prefix it is
// returned unchanged.
func WorktreeName(dir, worktreesDir string) string {
	return strings.TrimPrefix(dir, worktreesDir+"/")
}

// ValidName reports whether name satisfies the worktree-name rule.
func ValidName(name string) bool {
	return NameRe.MatchString(name)
}
