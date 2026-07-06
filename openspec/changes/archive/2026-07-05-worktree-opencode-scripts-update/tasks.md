# Tasks: worktree-opencode-scripts-update

**Date**: 2026-07-05
**Change**: Consolidate 9 worktree scripts into a single `bin/code-work` + shell function update + package cleanup
**Delivery**: single-pr
**Review budget**: normal (400 lines)

---

## Review Workload Forecast

| Metric | Value |
|--------|-------|
| New lines (bin/code-work) | ~183 |
| Modified lines (shell.nix, default.nix, AGENTS.md) | ~70 |
| Removed lines (9 old scripts + package entries) | ~1100 |
| Net diff (additions + deletions) | ~250-300 added, ~1100 removed |
| **400-line budget risk** | **Low** |

Decision needed before apply: No
Chained PRs recommended: No
400-line budget risk: Low

---

## Phase 1: Create `bin/code-work` Script

### Task 1.1: Write `bin/code-work` with all 4 commands

**Files**: `bin/code-work` (CREATE)

Write the complete `bin/code-work` bash script implementing:

- **Constants**: `REPO_ROOT` via `git rev-parse --show-toplevel`, `WORKTREES_DIR`, `SCRIPT_NAME`
- **Helper functions**: `die()`, `usage()`, `get_current_branch()`, `is_in_worktree()`, `get_worktree_name()`, `read_marker()`, `validate_name()`, `has_upstream()`, `check_gitignore()`
- **cmd_create(name)**: Validate name, check clean state, create branch from current branch, `git worktree add`, write `.worktree-base` marker, check `.gitignore`, print success with instructions
- **cmd_finish()**: Validate inside worktree, check `.worktree-base` exists, read marker, check dirty state, check upstream before deletion, `cd $REPO_ROOT`, checkout base branch, `git worktree remove`, `git branch -D`, `git worktree prune`
- **cmd_list()**: `git worktree list`, indicate current worktree if applicable
- **cmd_prune()**: `git worktree prune`
- **Main dispatch**: `case` statement for `--finish`, `--list`, `--prune`, `--help`, name argument, no-argument

Key requirements from design (Section 2):
- `set -euo pipefail`
- Exit codes: 0=success, 1=error, 2=usage
- Errors to stderr, info to stdout
- 15 error conditions from design Section 4
- Non-interactive (no `read` prompts)
- Upstream check before branch deletion in `cmd_finish`

**Verification**:
- `bash -n bin/code-work` passes (syntax check)
- `test -x bin/code-work` — make executable
- `bin/code-work --help` prints usage

---

### Task 1.2: Make executable and verify syntax

**Files**: `bin/code-work` (chmod +x)

- `chmod +x bin/code-work`
- `bash -n bin/code-work` — must exit 0
- `bin/code-work --help` — must print usage and exit 2
- `bin/code-work` (no args) — must print usage and exit 2

**Verification**:
- All three checks pass

---

## Phase 2: Update Package Definition

### Task 2.1: Update `pkgs/nixos-scripts/default.nix`

**Files**: `pkgs/nixos-scripts/default.nix` (MODIFY)

Replace the installPhase:
- **Remove**: All 9 old script entries (work-flow, start-work, finish-work, abort-work, list-work, git-flow, oc-wt) and the `git-worktree-flow` symlink
- **Add**: `cp $src/code-work $out/bin/` + `chmod +x $out/bin/code-work`
- **Keep**: format-nix, nixos-build, export-mate-config (unchanged)

**Verification**:
- `nix flake check --no-build` passes
- Review diff shows only package entries changed

---

## Phase 3: Update Shell Integration

### Task 3.1: Replace `code-work()` function in `home-linux/shell.nix`

**Files**: `home-linux/shell.nix` (MODIFY)

Replace the `code-work()` function (lines 64-83) with the new version from design Section 2.6:
- Dispatch `--finish`, `--list`, `--prune`, `--help` directly to `bin/code-work`
- For name argument: call `bin/code-work "$wt_name"`, then `cd` into worktree, launch `opencode`
- Print post-session hint about `code-work --finish`

**Verification**:
- `nix flake check --no-build` passes
- Function references `$HOME/.nixos/bin/code-work` (not old scripts)

---

### Task 3.2: Update shell aliases in `home-linux/shell.nix`

**Files**: `home-linux/shell.nix` (MODIFY)

Update aliases (lines 41-42):
- `"wt-done" = "code-work --finish";` (was `"finish-work"`)
- Remove `"wt-discard" = "abort-work";` (no --abort in new design)
- Add `"wt-list" = "code-work --list";`

**Verification**:
- `nix flake check --no-build` passes
- No references to old script names remain in shell.nix

---

## Phase 4: Remove Obsolete Scripts

### Task 4.1: Delete all 9 old scripts from `bin/`

**Files** (DELETE):
- `bin/work-flow`
- `bin/git-flow`
- `bin/git-worktree-flow`
- `bin/opencode-worktree`
- `bin/oc-wt`
- `bin/start-work`
- `bin/finish-work`
- `bin/abort-work`
- `bin/list-work`

**Verification**:
- `ls bin/` shows no old scripts
- `git status` confirms all 9 deleted

---

### Task 4.2: Update AGENTS.md comment

**Files**: `AGENTS.md` (MODIFY)

Line 28 currently reads:
```
bin/                             # Shell scripts (nixos-build, format-nix, git-flow, etc.)
```

Update to:
```
bin/                             # Shell scripts (nixos-build, format-nix, code-work, etc.)
```

**Verification**:
- Grep for `git-flow` in AGENTS.md returns no matches
- Grep for `work-flow` in AGENTS.md returns no matches

---

## Phase 5: Final Verification

### Task 5.1: Full flake check and diff review

**Commands**:
- `format-nix` — format all changed files
- `nix flake check --no-build` — must exit 0
- `git diff --stat` — review all changes
- `git grep -l 'work-flow\|start-work\|finish-work\|abort-work\|list-work\|git-flow\|oc-wt' -- '*.nix' '*.md'` — must return no hits (except openspec artifacts)

**Verification**:
- All checks pass
- No stale references to old scripts in code (openspec docs are excluded)

---

### Task 5.2: Manual smoke test

**Commands** (from `/home/glats/.nixos`):
```bash
# 1. Test help
bin/code-work --help

# 2. Test no-args
bin/code-work

# 3. Test list (from main repo)
bin/code-work --list

# 4. Test prune
bin/code-work --prune

# 5. Test create (requires clean branch)
bin/code-work "smoke-test"

# 6. Test finish (from inside worktree)
cd .worktrees/smoke-test && bin/code-work --finish

# 7. Test error: finish from main repo
bin/code-work --finish  # expect "not inside a worktree"
```

**Verification**:
- Each command produces expected output
- No errors outside expected error paths

---

## Task Dependency Graph

```
Phase 1 (1.1 → 1.2)  ← must complete before Phase 2
Phase 2 (2.1)        ← can start after 1.2
Phase 3 (3.1 → 3.2)  ← can start after 1.2 (parallel with Phase 2)
Phase 4 (4.1 → 4.2)  ← must complete after Phase 2
Phase 5 (5.1 → 5.2)  ← must be last
```

## Files Changed Summary

| File | Action | Est. Lines |
|------|--------|-----------|
| `bin/code-work` | CREATE | ~183 |
| `pkgs/nixos-scripts/default.nix` | MODIFY | ~40 changed |
| `home-linux/shell.nix` | MODIFY | ~30 changed |
| `AGENTS.md` | MODIFY | 1 line |
| `bin/work-flow` | DELETE | -417 |
| `bin/git-flow` | DELETE | -380 |
| `bin/git-worktree-flow` | DELETE | -148 |
| `bin/opencode-worktree` | DELETE | -64 |
| `bin/oc-wt` | DELETE | -54 |
| `bin/start-work` | DELETE | -5 |
| `bin/finish-work` | DELETE | -5 |
| `bin/abort-work` | DELETE | -5 |
| `bin/list-work` | DELETE | -5 |
| **Total** | | ~255 added, ~1083 removed |
