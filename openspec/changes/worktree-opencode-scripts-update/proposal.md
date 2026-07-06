# Proposal: worktree-opencode-scripts-update

**Date**: 2026-07-05
**Change**: Consolidate 10 worktree scripts into a single `bin/code-work` with cleanup and SDD hooks

---

## Intent

Replace the fragmented, duplicate worktree script ecosystem (10 files, ~1100 total lines) with a single `bin/code-work` script that handles the complete worktree lifecycle. Remove 9 obsolete scripts, update package definitions, and keep shell integration as aliases.

---

## Scope

### In Scope

| Item | Detail |
|------|--------|
| `bin/code-work` | New script with 4 subcommands (name, `--finish`, `--list`, `--prune`) |
| `.worktree-base` | Marker file recording base branch at creation time |
| Dynamic REPO_ROOT | Use `git rev-parse --show-toplevel` instead of hardcoded path |
| Script removal | Remove 9 scripts (see Cleanup) |
| Package update | `pkgs/nixos-scripts/default.nix` — replace old scripts with `code-work` |
| Shell integration | `home-linux/shell.nix` — update `code-work()` function and aliases |
| Backward compat | Graceful handling of old worktrees without `.worktree-base` |

### Out of Scope

- SDD state.yaml integration (future change)
- OpenCode skill/command for worktree management
- Merge-tree pre-check (`git merge-tree` before merge)
- Config copying (`.config/opencode/` into worktree)
- Go migration or any language change

---

## Capabilities

| Capability | Command | Behavior |
|------------|---------|----------|
| Create worktree | `code-work "name"` | Branches from current branch, creates worktree in `.worktrees/name`, writes `.worktree-base` with base branch name, opens opencode in worktree |
| Finish worktree | `code-work --finish` | Checks for uncommitted changes (errors if found), returns to repo root, checks out base branch from `.worktree-base`, removes worktree, deletes local branch (if pushed upstream), runs `git worktree prune` |
| List worktrees | `code-work --list` | Runs `git worktree list` with formatted output |
| Prune stale refs | `code-work --prune` | Runs `git worktree prune` to clean stale worktree references |

### Marker File Design

- **File**: `.worktree-base` stored at the root of each worktree directory
- **Content**: Single line with the base branch name (e.g., `master`)
- **Written**: By `code-work "name"` immediately after `git worktree add`
- **Read**: By `code-work --finish` to determine which branch to return to
- **Missing**: If `.worktree-base` is absent, `--finish` errors with a message directing the user to check `git branch -r` or specify base branch manually

### Non-interactive by Design

- `code-work --finish` errors on uncommitted changes (does not ask for confirmation)
- `code-work --finish` auto-commits are intentionally NOT included — the user/agent should commit before finishing
- No interactive prompts — suitable for scripted/CI use

---

## Approach

### Script Design (bin/code-work)

A single bash script (~150 lines) with argument parsing:

```
code-work
  ├── <name>          → Create named worktree + open opencode
  ├── --finish        → Check, return, cleanup
  ├── --list          → List worktrees
  └── --prune         → git worktree prune
```

Key design decisions:
- **Name required** (no random names): The user must provide a task name. This eliminates the random-name problem and forces SDD-aligned naming.
- **Current branch as base**: Worktree branches off the current branch, not hardcoded to `master`. The marker records the base branch for `--finish`.
- **Error on dirty worktree**: `--finish` refuses if there are uncommitted changes. Users/agents must `git add + git commit` before finishing.
- **Git-native**: No state files outside the worktree. `.worktree-base` is inside the worktree and travels with it.
- **Self-cleaning**: On success, `--finish` removes the worktree AND deletes the local branch (if pushed upstream). Runs `git worktree prune` at the end.

### Cleanup: Scripts to Remove (9 files)

| File | Lines | Reason |
|------|-------|--------|
| `bin/work-flow` | 417 | Replaced by `code-work` |
| `bin/git-flow` | 380 | 90% duplicate of work-flow |
| `bin/git-worktree-flow` | 148 | Partial overlap, symlink to git-flow |
| `bin/opencode-worktree` | 64 | Uses git-flow internally |
| `bin/oc-wt` | 54 | Orphaned worktree bug |
| `bin/start-work` | 5 | Thin wrapper, becomes shell alias |
| `bin/finish-work` | 5 | Thin wrapper, becomes shell alias |
| `bin/abort-work` | 5 | Thin wrapper, becomes shell alias |
| `bin/list-work` | 5 | Thin wrapper, becomes shell alias |

### Shell Integration Changes

Replace the existing `code-work()` function in `home-linux/shell.nix` with a streamlined version that calls `bin/code-work` directly. Update shell aliases:

- `wt-done` → `code-work --finish` (instead of `finish-work`)
- `wt-discard` → legacy removal (no abort in new script)
- `wt-list` → `code-work --list` (new)

### Package Update

In `pkgs/nixos-scripts/default.nix`:
- Add: `cp $src/code-work $out/bin/`
- Remove: all 9 old scripts
- Remove: `ln -s git-flow git-worktree-flow` symlink

### Backward Compatibility

Since there are no active worktrees (per exploration), backward compat is straightforward:
- Old scripts are removed from the repo and package
- Nix rebuild will install only `code-work` in PATH
- If an old worktree is found, `--finish` detects missing `.worktree-base` and errors with a helpful message

---

## Affected Areas

| Path | Action |
|------|--------|
| `bin/code-work` | **CREATE** — new script (~150 lines) |
| `bin/work-flow` | REMOVE |
| `bin/git-flow` | REMOVE |
| `bin/git-worktree-flow` | REMOVE |
| `bin/opencode-worktree` | REMOVE |
| `bin/oc-wt` | REMOVE |
| `bin/start-work` | REMOVE |
| `bin/finish-work` | REMOVE |
| `bin/abort-work` | REMOVE |
| `bin/list-work` | REMOVE |
| `home-linux/shell.nix` | MODIFY — update `code-work()` function and aliases |
| `pkgs/nixos-scripts/default.nix` | MODIFY — replace old scripts with `code-work` |
| `.gitignore` | VERIFY — `.worktrees/` already present (line 19) |

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Workflow disruption | Users used to `work-flow start` or old wrappers | Nix rebuild installs `code-work`; old scripts still in git history and on disk until rebuild |
| Lost `abort` function | New `code-work` has no `--abort` | Explicitly intentional: agents should commit before finishing; abort is a crutch that leaves dirty state. Document in shell help |
| Missing `.worktree-base` | Old worktrees can't be auto-finished | `--finish` errors with actionable message: "No .worktree-base found. Run: git checkout <base-branch> && git worktree remove <path> && git branch -d <branch>" |
| PATH ordering | System `code-work` vs this script | Only one in PATH — `nixos-scripts` package installs to `$HOME/.nixos/bin` |
| Nix build failure | Missing file in package | Verify with `nix flake check --no-build` |

---

## Rollback Plan

1. **Revert code**: `git revert <merge-commit>` restores all old scripts and package
2. **Nix rebuild**: `nixos-build switch` reinstalls old scripts to PATH
3. **New worktrees**: Any worktrees created with `code-work` during the change window still have `.worktree-base` and can be finished manually even after rollback
4. **Marker files are harmless**: `.worktree-base` in rolled-back worktrees causes no harm — old scripts ignore unknown files

---

## Dependencies

- `openspec/changes/worktree-opencode-scripts-update/exploration.md` (complete)
- Validating: `.worktrees/` in `.gitignore` — **confirmed present** (line 19)

---

## Success Criteria

1. `nix flake check --no-build` passes
2. `code-work "test-change"` creates worktree with `.worktree-base`, branches from current branch, opens opencode
3. `code-work --list` shows all worktrees
4. `code-work --prune` runs without error
5. From inside the worktree: `code-work --finish` errors on uncommitted changes, succeeds on clean state, returns to base branch, removes worktree + branch
6. `code-work --finish` on worktree without `.worktree-base` gives helpful error
7. All 9 old scripts are removed from `bin/` and from the package
8. Shell aliases `wt-done` → `code-work --finish` work in new shell
