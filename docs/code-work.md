# Code-work: quick start

`code-work` creates a Git worktree, enters it, and leaves the choice of AI
assistant to you. It does not launch OpenCode, OpenCode v2, Claude, or any
other tool.

## Quick path

Run this from a clean main checkout:

```bash
code-work my-change
# You are now in .worktrees/my-change on branch my-change.

opencode2 # or: opencode, claude, or no assistant
```

When the work is ready, integrate the branch manually. From inside the
worktree, get the exact safe cleanup commands with:

```bash
code-work --done
```

The named form also works from the main checkout:

```bash
code-work --done my-change
```

## Daily commands

| Command | Result |
| --- | --- |
| `code-work <task>` | Create and enter `.worktrees/<task>` on branch `<task>`. |
| `code-work --done [task]` | Show manual integration and safe cleanup guidance; makes no Git changes. |
| `code-work --abort <task>` | Force-remove the named worktree and branch. Destructive. |
| `code-work --list` | List worktrees. |
| `code-work --prune` | Remove stale Git worktree references. |

`--abort` always requires the task name and refuses to run when your shell is
inside that target worktree. Use it only when you intend to discard all branch
work.

## Cleanup after integration

After merging the branch or merging its PR, run the commands printed by
`code-work --done`. They use Git's safe defaults:

```bash
git worktree remove .worktrees/my-change
git branch -d my-change
```

Use `git branch -D` only when intentionally discarding unmerged commits. For
immediate discard instead, use `code-work --abort my-change` from the main
checkout.
