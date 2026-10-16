package gitutil

import (
	"path/filepath"
	"regexp"
	"strings"
)

var NameRe = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9._/-]*$`)

type Worktree struct {
	Path     string
	Head     string
	Branch   string
	Detached bool
	Bare     bool
}

func ParseWorktreeList(out string) []Worktree {
	var entries []Worktree
	var cur *Worktree
	for _, line := range strings.Split(out, "\n") {
		switch {
		case strings.HasPrefix(line, "worktree "):
			entries = append(entries, Worktree{Path: strings.TrimPrefix(line, "worktree ")})
			cur = &entries[len(entries)-1]
		case cur == nil:

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

func MainWorktree(out string) string {
	entries := ParseWorktreeList(out)
	if len(entries) == 0 {
		return ""
	}
	return entries[0].Path
}

func InWorktrees(dir, worktreesDir string) bool {
	return worktreesDir != "" && strings.HasPrefix(dir, worktreesDir)
}

func WorktreeName(dir, worktreesDir string) string {
	return strings.TrimPrefix(dir, worktreesDir+"/")
}

func ValidName(name string) bool {
	return NameRe.MatchString(name) && filepath.Clean(name) == name && !filepath.IsAbs(name)
}
