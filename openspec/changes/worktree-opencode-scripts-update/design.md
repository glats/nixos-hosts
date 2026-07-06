# Design: worktree-opencode-scripts-update

**Date**: 2026-07-05
**Change**: Consolidate 9 worktree scripts into a single `bin/code-work` + shell function update + package cleanup
**Delivery**: single-pr

---

## 1. Architecture Overview

### 1.1 Component Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                    User Shell (zsh)                          │
│                                                              │
│  code-work "name"                                            │
│    ├── calls bin/code-work <name>    (create worktree)       │
│    ├── cd .worktrees/<name>                                  │
│    └── opencode                     (interactive session)    │
│                                                              │
│  code-work --finish (from inside worktree)                   │
│    └── calls bin/code-work --finish                          │
│                                                              │
│  code-work --list / --prune                                  │
│    └── calls bin/code-work --list / --prune                  │
└──────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────┐
│              bin/code-work (pure bash, set -euo pipefail)    │
│                                                              │
│  Functions:  usage, die, get_current_branch,                 │
│              is_in_worktree, get_worktree_name,              │
│              read_marker, validate_name,                     │
│              cmd_create, cmd_finish, cmd_list, cmd_prune     │
│                                                              │
│  Input:  argv[1] = subcommand or name                        │
│  Output: status messages to stdout, errors to stderr         │
│  Exit:   0 success, 1 error, 2 usage error                   │
└──────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────┐
│                     Git layer                                 │
│  git worktree add/list/remove/prune                           │
│  git branch, git checkout, git rev-parse                     │
│  git status --porcelain                                       │
└──────────────────────────────────────────────────────────────┘
```

### 1.2 Layered Responsibility

| Layer | File | Responsibility |
|-------|------|---------------|
| UX Shell | `home-linux/shell.nix` `code-work()` function | Dispatch to script, cd into worktree, launch opencode |
| Tool | `bin/code-work` | Pure git operations, no interactive prompts, no cd |
| Git | system git | Low-level git worktree, branch, checkout operations |

### 1.3 Design Decision: Tool/UX Separation

**Decision**: `bin/code-work` is a pure git tool that does NOT cd or launch opencode. The shell function provides the interactive UX (cd + opencode launch).

**Rationale**:
- Script remains testable in CI (no interactive dependencies, no terminal emulator needed)
- Script works from any directory
- Clear separation of concerns — git logic separate from terminal UX
- Shell function can be modified independently (e.g., to use a different editor) without changing the script
- `--finish` naturally works from inside the worktree directory

**Tradeoff**: Users who invoke `bin/code-work` directly (bypassing the shell function) need to manually cd into the worktree. This is documented in the usage message and in the script's `--help`.

---

## 2. Module Design

### 2.1 Script Structure (`bin/code-work`)

```bash
#!/usr/bin/env bash
set -euo pipefail

# ==== Constants (computed) ====
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
WORKTREES_DIR="$REPO_ROOT/.worktrees"
SCRIPT_NAME=$(basename "$0")

# ==== Helper Functions ====

# die(msg, exit_code=1) — print error to stderr and exit
# usage(msg) — print usage and exit 2
# get_current_branch() → echo branch_name or die
# is_in_worktree() → true if PWD starts with WORKTREES_DIR
# get_worktree_name() → echo basename of WORKTREES_DIR from PWD
# read_marker(worktree_path) → echo base_branch from .worktree-base
# validate_name(name) → die if name contains invalid characters
# has_upstream(branch_name) → true if branch has remote tracking
# check_gitignore() — warn if .worktrees/ not in .gitignore

# ==== Command Functions ====

# cmd_create(name) — create worktree + write marker + print next steps
# cmd_finish() — validate worktree, check dirty, remove worktree+branch
# cmd_list() — git worktree list
# cmd_prune() — git worktree prune

# ==== Main Dispatch ====
case "${1:-}" in
  --finish|finish)  shift; cmd_finish "$@" ;;
  --list|list)      cmd_list ;;
  --prune|prune)    cmd_prune ;;
  --help|-h)        usage ;;
  "")               usage "Missing worktree name" ;;
  *)                cmd_create "$1" ;;
esac
```

**Full pseudocode for each function follows in sections 2.2-2.5.**

### 2.2 cmd_create(name)

```
cmd_create(name):
  # Validate
  if name is empty:
    usage("Missing worktree name")
    exit 2

  if REPO_ROOT is empty:
    die("Not inside a git repository")

  if name does not match ^[a-zA-Z0-9][a-zA-Z0-9._-]*$:
    die("Invalid worktree name 'name'. Use alphanumeric, dots, hyphens, underscores. No slashes.")

  if WORKTREES_DIR/name exists:
    die("Worktree 'name' already exists at WORKTREES_DIR/name")

  # Capture current branch
  CURRENT_BRANCH = git rev-parse --abbrev-ref HEAD
  if CURRENT_BRANCH == "HEAD":
    die("Detached HEAD state. Checkout a branch before creating a worktree.")

  # Check dirty state
  if git status --porcelain has output:
    echo "Error: Current branch '$CURRENT_BRANCH' has uncommitted changes."
    echo "Commit or stash before creating a worktree:"
    echo "  git add -A && git commit -m 'message'"
    echo "  # or: git stash"
    exit 1

  # Create branch from current branch
  if branch 'name' already exists:
    die("Branch 'name' already exists. Choose a different worktree name.")

  git branch name CURRENT_BRANCH

  # Create worktree
  git worktree add WORKTREES_DIR/name name

  # Write marker file
  echo CURRENT_BRANCH > WORKTREES_DIR/name/.worktree-base

  # Check .gitignore (non-fatal warning)
  if REPO_ROOT/.gitignore does not contain .worktrees/:
    echo "Warning: .worktrees/ not in .gitignore. Add it to prevent accidental commits."

  # Success output
  echo "====================================="
  echo "> Created worktree: name"
  echo "> Location: WORKTREES_DIR/name"
  echo "> Branch: name (from CURRENT_BRANCH)"
  echo ""
  echo "To work in this worktree:"
  echo "  cd WORKTREES_DIR/name"
  echo "  opencode"
  echo ""
  echo "When done:"
  echo "  cd WORKTREES_DIR/name"
  echo "  code-work --finish"
  echo "====================================="

  return 0
```

**Edge cases**:
| Case | Behavior |
|------|----------|
| branch exists | Die with error — user must pick different name or clean up old branch |
| worktree dir exists | Die with error — means previous cleanup failed |
| name has spaces/slashes | Die with invalid name error (validation gate) |
| detached HEAD | Die — must be on a branch |
| dirty current branch | Die with uncommitted changes error |
| not in git repo | Die (REPO_ROOT detection fails at script top) |

### 2.3 cmd_finish()

```
cmd_finish():
  # Validate we are inside a worktree
  if REPO_ROOT is empty:
    die("Not inside a git repository")

  if PWD does not start with WORKTREES_DIR:
    die("Not inside a worktree directory")
    echo "Current: $PWD"
    echo "Worktrees are in: $WORKTREES_DIR"

  # Get worktree identity
  WT_NAME = basename of PWD (= last component of WORKTREES_DIR path)
  WT_PATH = PWD

  # Check marker file
  if WT_PATH/.worktree-base does not exist:
    die("No .worktree-base found in this worktree.")
    echo ""
    echo "This worktree was created with an older version or manually."
    echo "To finish it manually:"
    echo "  1. cd REPO_ROOT"
    echo "  2. git checkout master    # (or your main branch)"
    echo "  3. git worktree remove WT_PATH"
    echo "  4. git branch -d WT_NAME"

  # Read marker
  BASE_BRANCH = cat WT_PATH/.worktree-base

  # Check dirty state
  if git -C WT_PATH status --porcelain has output:
    echo "Error: uncommitted changes in worktree 'WT_NAME'."
    echo "Commit before finishing:"
    echo "  git add -A && git commit -m 'message'"
    exit 1

  # Check upstream (non-interactive: error if not pushed)
  CURRENT_BRANCH = git -C WT_PATH rev-parse --abbrev-ref HEAD
  if has_upstream(CURRENT_BRANCH) is false:
    echo "Error: Branch '$CURRENT_BRANCH' has not been pushed to upstream."
    echo "Local commits would be lost on deletion."
    echo ""
    echo "To save your work before cleaning up:"
    echo "  git push -u origin CURRENT_BRANCH"
    echo ""
    echo "Then run 'code-work --finish' again."
    echo ""
    echo "To force cleanup anyway:"
    echo "  cd REPO_ROOT"
    echo "  git branch -D CURRENT_BRANCH"
    echo "  git worktree remove WT_PATH"
    echo "  git worktree prune"
    exit 1

  # === Cleanup ===
  cd REPO_ROOT

  # Checkout base branch
  echo "> Returning to base branch '$BASE_BRANCH'..."
  git checkout BASE_BRANCH

  # Remove worktree
  echo "> Removing worktree 'WT_NAME'..."
  git worktree remove WT_PATH --force

  # Delete branch (safe — upstream exists since we checked)
  echo "> Deleting branch 'CURRENT_BRANCH'..."
  git branch -D CURRENT_BRANCH

  # Prune stale refs
  echo "> Pruning stale worktree references..."
  git worktree prune

  echo ""
  echo "====================================="
  echo "> Worktree 'WT_NAME' finished and cleaned up."
  echo "> Returned to branch '$BASE_BRANCH'."
  echo "====================================="

  return 0
```

**Edge cases**:
| Case | Behavior |
|------|----------|
| Not in worktree | Die with clear message |
| No `.worktree-base` | Die with manual cleanup instructions |
| Uncommitted changes | Die — user must commit first |
| Branch not pushed upstream | Die with push instruction — nothing is deleted |
| Base branch checkout fails | Die (e.g., base branch was deleted) — worktree preserved |
| `git worktree remove` fails | Die — print error, preserve branch |
| Running from main/master (not in worktree) | Caught by "not in worktree" check |

### 2.4 cmd_list()

```
cmd_list():
  if REPO_ROOT is empty:
    die("Not inside a git repository")

  git -C REPO_ROOT worktree list

  # Indicate current worktree if applicable
  if PWD starts with WORKTREES_DIR:
    echo ""
    echo "  (current worktree: $(basename $PWD))"
```

### 2.5 cmd_prune()

```
cmd_prune():
  if REPO_ROOT is empty:
    die("Not inside a git repository")

  git -C REPO_ROOT worktree prune
  echo "> Stale worktree references pruned."
```

### 2.6 Shell Function (`code-work()` in `home-linux/shell.nix`)

```zsh
code-work() {
  case "${1:-}" in
    --finish|--list|--prune|--help|-h)
      "${HOME}/.nixos/bin/code-work" "$@"
      ;;
    "")
      "${HOME}/.nixos/bin/code-work" --help
      ;;
    *)
      local wt_name="$1"
      # Create worktree (exits on error)
      "${HOME}/.nixos/bin/code-work" "$wt_name" || return

      # Navigate into worktree and launch opencode
      local repo_root
      repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || repo_root="${HOME}/.nixos"

      if [[ -d "$repo_root/.worktrees/$wt_name" ]]; then
        cd "$repo_root/.worktrees/$wt_name"
        opencode || true
        echo ""
        echo "> Run 'code-work --finish' to save and cleanup"
        echo "> (From the worktree directory: .worktrees/$wt_name)"
      fi
      ;;
  esac
}
```

**Shell aliases**:
```
wt-done  →  code-work --finish
wt-list  →  code-work --list
```

Note: `wt-discard` is removed (no `--abort` subcommand exists). The `--finish` non-interactive design makes `abort` unnecessary.

---

## 3. Data Flow

### 3.1 Marker File: `.worktree-base`

```
Purpose:      Record which branch the worktree was created from
Location:     WORKTREES_DIR/<name>/.worktree-base
Format:       Single line containing the source branch name
              Example: "master" or "feature/my-change"
Created by:   cmd_create() immediately after git worktree add
Consumed by:  cmd_finish() to determine base branch for checkout
Lifetime:     Lives inside the worktree directory; deleted when worktree is removed
Missing:      cmd_finish() errors with manual cleanup instructions
```

### 3.2 Lifecycle States

```
                   ┌──────────────┐
                   │ User creates  │
                   │ worktree via  │
                   │ code-work "x" │
                   └──────┬───────┘
                          │
                          ▼
              ┌───────────────────────┐
              │  State: ACTIVE        │
              │  - Worktree exists    │
              │  - Branch exists      │
              │  - .worktree-base set │
              │  - User works/commits │
              └───────┬───────────────┘
                      │
            ┌─────────┴─────────┐
            │                   │
            ▼                   ▼
  ┌─────────────────┐   ┌──────────────┐
  │ code-work        │   │ User never   │
  │ --finish (clean) │   │ finishes     │
  └────────┬────────┘   └──────┬───────┘
           │                   │
           ▼                   ▼
  ┌─────────────────┐   ┌──────────────┐
  │ State: FINISHED  │   │ State: STALE │
  │ - Worktree gone  │   │ - Orphaned   │
  │ - Branch deleted │   │   files+ref  │
  │ - .git/prune'd   │   │ - Manual     │
  └─────────────────┘   │   cleanup     │
                        │   needed      │
                        └──────────────┘
```

### 3.3 Git Operations Summary

| Operation | Command | Called By | Error If |
|-----------|---------|-----------|----------|
| Find repo root | `git rev-parse --show-toplevel` | All commands | Not in git repo |
| Get current branch | `git rev-parse --abbrev-ref HEAD` | cmd_create, cmd_finish | Detached HEAD |
| Check dirty | `git status --porcelain` | cmd_create, cmd_finish | Has output |
| Create branch | `git branch <name> <base>` | cmd_create | Branch exists |
| Create worktree | `git worktree add <path> <branch>` | cmd_create | Worktree/branch exists |
| Read upstream | `git rev-parse --abbrev-ref <branch>@{u}` | cmd_finish | No upstream |
| Checkout | `git checkout <branch>` | cmd_finish | Branch not found |
| Remove worktree | `git worktree remove <path> [--force]` | cmd_finish | Dirty worktree |
| Delete branch | `git branch -D <name>` | cmd_finish (after upstream check) | — |
| List worktrees | `git worktree list` | cmd_list | — |
| Prune refs | `git worktree prune` | cmd_finish, cmd_prune | — |

---

## 4. Error Handling Matrix

| # | Error Condition | Detected By | Message | Exit | Action Taken |
|---|----------------|-------------|---------|------|-------------|
| 1 | Not in git repo | `REPO_ROOT` empty at script top | "Not inside a git repository" | 1 | No worktree ops |
| 2 | Missing name argument | `cmd_create` argument check | "Missing worktree name" + usage | 2 | None |
| 3 | Invalid name (spaces, slashes) | `validate_name` regex check | "Invalid worktree name '<name>'. Use alphanumeric, dots, hyphens, underscores." | 2 | None |
| 4 | Worktree already exists | Directory check `-d WORKTREES_DIR/name` | "Worktree '<name>' already exists" | 1 | None |
| 5 | Branch already exists | `git branch` command fails | "Branch '<name>' already exists. Choose a different worktree name." | 1 | None |
| 6 | Detached HEAD | `git rev-parse --abbrev-ref HEAD` = "HEAD" | "Detached HEAD state. Checkout a branch first." | 1 | None |
| 7 | Dirty current branch (create) | `git status --porcelain` non-empty | "Current branch has uncommitted changes." + instructions | 1 | None |
| 8 | Not in worktree (finish) | PWD does not start with WORKTREES_DIR | "Not inside a worktree directory" + current path | 1 | None |
| 9 | Missing .worktree-base | File not found | "No .worktree-base found" + manual cleanup instructions | 1 | None |
| 10 | Dirty worktree (finish) | `git status --porcelain` non-empty in worktree | "Uncommitted changes in worktree. Commit before finishing." | 1 | Worktree preserved |
| 11 | Branch not pushed upstream | `git rev-parse --abbrev-ref @{u}` fails | "Branch has not been pushed to upstream." + instructions | 1 | Worktree preserved |
| 12 | Base branch checkout fails | `git checkout BASE_BRANCH` fails | "Failed to checkout base branch '<base>'. It may have been deleted." | 1 | Worktree preserved |
| 13 | Worktree remove fails | `git worktree remove` fails | "Failed to remove worktree." + details from git | 1 | Branch preserved |
| 14 | Unknown subcommand | `case` default | usage message | 2 | None |
| 15 | Running --finish from main repo (not worktree) | PWD check (same as #8) | "Not inside a worktree directory" | 1 | None |

### 4.1 Exit Code Policy

| Code | Meaning | Conditions |
|------|---------|-----------|
| 0 | Success | All operations completed |
| 1 | Error | Any runtime error (validation, git failure, state mismatch) |
| 2 | Usage | Missing argument, unknown subcommand, invalid name format |

### 4.2 Message Format

- **Errors**: `echo >&2 "Error: <message>"` — always to stderr
- **Warnings**: `echo >&2 "Warning: <message>"` — non-fatal, to stderr
- **Success/Info**: `echo "> <message>"` — to stdout
- **Decorators**: `> ` prefix for info lines, `=====================================` for section separators

---

## 5. Cleanup Plan

### 5.1 Files to Remove (9 scripts)

| # | File | Lines | Notes |
|---|------|-------|-------|
| 1 | `bin/work-flow` | 417 | Replaced by `bin/code-work` |
| 2 | `bin/git-flow` | 380 | 90% duplicate of work-flow |
| 3 | `bin/git-worktree-flow` | 148 | Partial overlap, symlink at package time |
| 4 | `bin/opencode-worktree` | 64 | Uses git-flow; not packaged |
| 5 | `bin/oc-wt` | 54 | Orphaned worktree bug |
| 6 | `bin/start-work` | 5 | Shell alias replacement |
| 7 | `bin/finish-work` | 5 | Shell alias replacement |
| 8 | `bin/abort-work` | 5 | Removed (no --abort in new design) |
| 9 | `bin/list-work` | 5 | Shell alias replacement |

### 5.2 Files to Verify

| File | Action | Reason |
|------|--------|--------|
| `.gitignore` | Verify `.worktrees/` present | Already confirmed present (line 19) |

### 5.3 Package Change (`pkgs/nixos-scripts/default.nix`)

**Remove from installPhase** (9 entries + 1 symlink):
```
work-flow, start-work, finish-work, abort-work, list-work
git-flow, oc-wt
git-worktree-flow symlink
```

**Add to installPhase** (1 entry):
```
code-work
```

**Final installPhase** (keeping existing utility scripts):
```bash
installPhase = ''
  mkdir -p $out/bin

  # Install worktree workflow script
  cp $src/code-work $out/bin/
  chmod +x $out/bin/code-work

  # Install utility scripts (unchanged)
  cp $src/format-nix $out/bin/
  chmod +x $out/bin/format-nix

  cp $src/nixos-build $out/bin/
  chmod +x $out/bin/nixos-build

  cp $src/export-mate-config $out/bin/
  chmod +x $out/bin/export-mate-config
'';
```

### 5.4 Shell Change (`home-linux/shell.nix`)

**Replace** `code-work()` function body with simplified dispatch (see 2.6).

**Update aliases**:
- `wt-done` → `code-work --finish` (was `finish-work`)
- `wt-discard` → REMOVE
- `wt-list` → ADD: `code-work --list`

---

## 6. Compatibility

### 6.1 Old Worktrees (Without `.worktree-base`)

Old worktrees created by `work-flow` or `git-flow` do NOT have `.worktree-base`.

When a user is inside such a worktree and runs `code-work --finish`:

1. Script detects PWD is inside WORKTREES_DIR ✓
2. Script checks for `.worktree-base` → NOT FOUND ✗
3. Script prints: "No .worktree-base found in this worktree." + manual instructions
4. Script exits 1, nothing is modified

**Manual cleanup instructions printed**:
```
Error: No .worktree-base found in this worktree.
This worktree was created with an older version or manually.

To finish it manually:
  1. cd <REPO_ROOT>
  2. git checkout master    # (or your main branch)
  3. git worktree remove <WT_PATH>
  4. git branch -d <WT_NAME>
```

### 6.2 Old Scripts in Git History

Old scripts remain in git history. After the Nix rebuild, they are removed from PATH but can still be referenced from historical commits. Any scripts or workflows that call these by absolute path will break — this is acceptable since they are personal convenience scripts in `~/bin`.

### 6.3 Branch Name Collision

The old scripts always branched from `master`/`main`. The new script branches from the CURRENT branch. If a user creates a worktree with the same name as an old worktree on a different base, the branch points to a different commit. This is fine — `git branch` creates from the specified base, and `git worktree add` checks out the branch at that commit.

---

## 7. Rollout Order

### Phase 1: Create `bin/code-work`

1. Write `bin/code-work` script
2. `chmod +x bin/code-work`
3. Verify: `code-work --help` prints usage

### Phase 2: Update Package and Shell

4. Update `pkgs/nixos-scripts/default.nix` — add code-work, remove old scripts
5. Update `home-linux/shell.nix` — replace function, update aliases

### Phase 3: Test

6. `nix flake check --no-build` passes
7. Manual test: `code-work "test-design"` from repo root
8. Manual test: `code-work --list` from repo root
9. Manual test: `cd .worktrees/test-design && code-work --finish`
10. Manual test: `code-work --prune`

### Phase 4: Remove Old Scripts

11. `git rm bin/work-flow bin/git-flow bin/git-worktree-flow`
12. `git rm bin/opencode-worktree bin/oc-wt`
13. `git rm bin/start-work bin/finish-work bin/abort-work bin/list-work`
14. `format-nix` to format all changed files

### Phase 5: Verify

15. `nix flake check --no-build` — must exit 0
16. `git diff --stat` — review changes before commit
17. Commit: `feat(bin): consolidate worktree scripts into code-work`

---

## 8. Testing Strategy

### 8.1 Static Verification

| Check | Method | Expected |
|-------|--------|----------|
| Script syntax | `bash -n bin/code-work` | No errors |
| Script executable | `test -x bin/code-work` | True |
| Nix flake | `nix flake check --no-build` | Exit 0 |

### 8.2 Manual Test Scenarios

**Scenario 1: Create worktree**
```bash
cd /home/glats/.nixos
# Ensure clean master branch
git checkout master
git status --porcelain  # should be empty
# Create worktree
code-work "test-design"
# Verify
ls .worktrees/test-design/
cat .worktrees/test-design/.worktree-base  # should say "master"
git branch --list test-design  # should show branch
```

**Scenario 2: Create with dirty branch**
```bash
echo "uncommitted" > /tmp/test-dirty
cp /tmp/test-dirty .worktrees/test-design/  # or touch a file in main repo
# Should fail with "uncommitted changes" error
code-work "test-dirty"  # expect error
```

**Scenario 3: Create duplicate**
```bash
# After Scenario 1
code-work "test-design"  # expect "already exists" error
```

**Scenario 4: List worktrees**
```bash
code-work --list  # should show test-design
```

**Scenario 5: Prune**
```bash
code-work --prune  # should succeed
```

**Scenario 6: Finish worktree**
```bash
cd /home/glats/.nixos/.worktrees/test-design
# Ensure clean state
git status --porcelain  # should be empty
# Push branch first
git push -u origin test-design || echo "Need remote access"
# Or: skip upstream check with instructions
code-work --finish
```

**Scenario 7: Finish from wrong directory**
```bash
cd /home/glats/.nixos
code-work --finish  # expect "not inside a worktree"
```

**Scenario 8: Finish with uncommitted changes**
```bash
cd /home/glats/.nixos/.worktrees/test-design
touch UNCOMMITTED
code-work --finish  # expect "uncommitted changes" error
```

**Scenario 9: Cancel cleanup (recreate after finish)**
```bash
# After Scenario 6 succeeds, verify
ls .worktrees/test-design  # should not exist
git branch --list test-design  # should not exist
```

### 8.3 Error Message Review

For each error in the matrix (Section 4), verify:
- Message is clear and actionable
- Exit code is correct (1 for runtime errors, 2 for usage)
- Error goes to stderr (verify with `2>/dev/null`)
- No destructive action is taken before the error

### 8.4 Non-Regression Checks

| Old behavior | New equivalent | Status |
|-------------|----------------|--------|
| `work-flow start "name"` | `code-work "name"` | New, branches from current branch |
| `work-flow finish "msg"` | `code-work --finish` | Different: no auto-commit, no merge |
| `work-flow list` | `code-work --list` | Equivalent |
| `work-flow abort` | REMOVED | No equivalent — intentional |
| `start-work "name"` | Shell alias: not needed | Shell function `code-work "name"` |
| `finish-work` | `code-work --finish` | Same, via alias `wt-done` |
| `list-work` | `code-work --list` | Same, via alias `wt-list` |

---

## Appendix A: Script Size Estimate

| Component | Estimated Lines |
|-----------|----------------|
| Shebang + set + constants | 5 |
| Helper functions (die, usage, get_current_branch, etc.) | 40 |
| cmd_create (validation + create + output) | 50 |
| cmd_finish (validation + checks + cleanup) | 60 |
| cmd_list | 8 |
| cmd_prune | 5 |
| Main dispatch case | 15 |
| **Total** | **~183** |

This is roughly half the size of `work-flow` alone (417 lines).

## Appendix B: Key Changes from Old Scripts

| Aspect | Old (work-flow/git-flow) | New (code-work) |
|--------|------------------------|-----------------|
| REPO_ROOT | Hardcoded `/home/glats/.nixos` | Dynamic via `git rev-parse --show-toplevel` |
| Base branch | Hardcoded `main`/`master` | Current branch at creation time |
| Name generation | Random auto-names | Explicit name required |
| Marker file | None | `.worktree-base` in worktree root |
| Finish behavior | Auto-commit + merge to main | Cleanup only (no commit, no merge) |
| Interactive prompts | Yes (read for input) | No (all errors, no prompts) |
| Upstream check | None | Check before branch deletion |
| opencode launch | Shell function only | Shell function (tool/UX separation) |
| --abort command | Yes | Removed |
| Script count | 9 scripts | 1 script |
