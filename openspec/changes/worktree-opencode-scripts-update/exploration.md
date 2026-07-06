# Exploration: worktree-opencode-scripts-update

**Date**: 2026-07-05

---

## Current State

### Script Inventory

The `bin/` directory contains 9 worktree-related scripts and 1 zsh shell function:

| Script | Lines | Role | Status |
|--------|-------|------|--------|
| `work-flow` | 417 | Core worktree manager (init, start, finish, abort, status, list, clean) | Best maintained, active |
| `git-flow` | 380 | Nearly identical to work-flow (~90% overlap) | Redundant |
| `git-worktree-flow` | 148 | Lower-level worktree mgmt (init, new, list, clean, prune) | Partial overlap with work-flow |
| `opencode-worktree` | 64 | Creates worktree + drops into bash with aliases (done, discard, status) | Uses git-flow internally; not packaged |
| `oc-wt` | 54 | Creates worktree + opens opencode directly | Orphaned worktree on exit |
| `start-work` | 5 | `exec work-flow start "$@"` | Thin wrapper, could be alias |
| `finish-work` | 5 | `exec work-flow finish "$@"` | Thin wrapper, could be alias |
| `abort-work` | 5 | `exec work-flow abort "$@"` | Thin wrapper, could be alias |
| `list-work` | 5 | `exec work-flow list "$@"` | Thin wrapper, could be alias |

### Shell Integration (home-linux/shell.nix)

```zsh
code-work() {
  local repo_root="${config.home.homeDirectory}/.nixos"
  local worktree_name="${1:-}"
  if [[ -n "$worktree_name" ]]; then
    "$repo_root/bin/work-flow" start "$worktree_name"
  else
    "$repo_root/bin/work-flow" start
    worktree_name=$(git -C "$repo_root" worktree list --porcelain | \
      grep "worktree $repo_root/.worktrees/" | tail -1 | sed "s|worktree $repo_root/.worktrees/||")
  fi
  local worktree_path="$repo_root/.worktrees/$worktree_name"
  cd "$worktree_path"
  opencode
  echo "> Run 'finish-work' to save or 'abort-work' to discard"
}
```

Shell aliases:
- `wt-done` -> `finish-work`
- `wt-discard` -> `abort-work`
- PATH includes `$HOME/.nixos/bin`

### Nix Package (pkgs/nixos-scripts/default.nix)

Packages: work-flow, start-work, finish-work, abort-work, list-work, git-flow, oc-wt, format-nix, nixos-build, export-mate-config
- `git-worktree-flow` is a symlink to `git-flow` at package time (line 46)
- `opencode-worktree` is **NOT** included in the package

### OpenCode Version

```
opencode 1.17.11
```

Native managed workspace cloning + session relocation since 1.16.0.

### SDD Workflow

- `openspec/changes/` directory with 46 existing changes
- OpenCode commands (sdd-new, sdd-explore, etc.) drive the lifecycle
- state.yaml tracks DAG state for each change
- No integration between the git worktree layer and the SDD layer

### Git State

- Repo uses `master` as main branch (not `main`)
- `.worktrees/` is gitignored
- No current worktrees on disk
- No `.worktreeinclude` or marker file mechanism

---

## Identified Issues

### 1. Script Duplication

`git-flow` (380 lines) and `work-flow` (417 lines) are ~90% identical. Both share:

- `init_repo` — identical logic
- `generate_worktree_name` — identical
- `done_worktree` / `finish_worktree` — near-identical (work-flow adds main-branch-uncommitted check)
- `discard_worktree` / `abort_worktree` — identical
- `status_worktree` — same output, different suggested commands
- `list_worktrees` — identical
- `clean_worktree` — identical

The only meaningful difference: `work-flow` checks if main branch has uncommitted changes before starting and before finishing. This is a strict improvement over `git-flow`.

`git-worktree-flow` (148 lines) is a lighter variant with `new` (not `start`), `prune`, and no finish/abort/status. It overlaps with work-flow's init/start/list/clean.

The four thin wrappers (start-work, finish-work, abort-work, list-work) are 5 lines each and just `exec work-flow <subcommand> "$@"`. They could all be shell aliases.

### 2. Hardcoded Paths

Every script hardcodes:
```bash
REPO_ROOT="/home/glats/.nixos"
```

This is fragile and breaks if the repo is cloned elsewhere or if worktrees are used from a submodule.

### 3. No SDD Integration

- Worktree names are random: `agent-YYYYMMDD-HHMMSS-random6`
- No connection to `openspec/changes/<change-name>/`
- SDD state.yaml is never updated by worktree operations
- No way to know which SDD change a worktree is for

### 4. No Config Copying

When creating a worktree, `.config/opencode/` is not copied. The worktree gets fresh Nix store symlinks. This means:

- OpenCode config (providers, agents, MCPs) must be rebuilt via Nix
- Customizations made in main repo are not inherited
- No `.worktreeinclude` file mechanism exists

### 5. No Worktree Metadata

No marker files to track:
- `.agent-parent-branch` — which branch this worktree was created from
- `.agent-context` — SDD change name, description, purpose
- `.agent-state` — lifecycle state (active, finished, aborted)

### 6. No Merge Safety

`git-flow done` and `work-flow finish` call `git merge --no-ff` directly. There is no `git merge-tree` pre-check to detect conflicts before attempting the merge. A failed merge leaves the worktree in a dirty state.

### 7. Interactive Confirmations Block Scripting

Both `done`/`finish` and `discard`/`abort` use `read` for interactive input:
```bash
echo -n "Type 'discard' to confirm: "
read -r confirm
```

This makes the scripts unsuitable for non-interactive or automated use.

### 8. Orphaned Worktrees

`oc-wt` and the shell's `code-work()` function both:
1. Create a worktree
2. cd into it
3. Launch `opencode`
4. After `opencode` exits, return to main repo
5. **The worktree is left orphaned** with uncommitted changes

There is no trap or cleanup, and no auto-commit on opencode exit.

### 9. Incomplete Packaging

`opencode-worktree` (64 lines) is not included in the `nixos-scripts` package, even though `oc-wt` and `git-flow` are.

---

## Affected Areas

| Path | Impact | Action |
|------|--------|--------|
| `bin/work-flow` | Core script to consolidate into | Extend with SDD hooks |
| `bin/git-flow` | 90% redundant with work-flow | Remove |
| `bin/git-worktree-flow` | Partial overlap | Keep as alias or remove |
| `bin/opencode-worktree` | Uses git-flow internally | Remove or refactor |
| `bin/oc-wt` | Orphaned worktree bug | Remove (absorb into shell function) |
| `bin/start-work` | Thin wrapper | Convert to alias or remove |
| `bin/finish-work` | Thin wrapper | Convert to alias or remove |
| `bin/abort-work` | Thin wrapper | Convert to alias or remove |
| `bin/list-work` | Thin wrapper | Convert to alias or remove |
| `home-linux/shell.nix` | Shell function and aliases | Update |
| `pkgs/nixos-scripts/default.nix` | Package definition | Update |
| `shared/opencode.nix` | Add config copy mechanism | Minor update |
| `.gitignore` | May need updates | Verify |

---

## Community Research (2026 Best Practices)

### opencode-worktree (DanHenton)
- npm package, 550+ stars
- Worktree-per-task approach (default) with worktree-per-agent as option
- File lock for serialized merges (prevents concurrent agent conflicts)
- Marker files: `.agent-parent-branch`, `.agent-context`
- Auto-injects context from parent branch into worktree
- Config copying via rsync include/exclude patterns

### Rift (priyashpatil)
- TypeScript-based agent session manager
- 13 releases, v0.5.3
- Hooks system for pre/post merge actions
- Hash-based port mapping for concurrent agent sessions
- Supports any CLI agent (OpenCode, Claude, Cursor)

### git-wt (kuderr)
- Pure Bash, minimal dependencies
- Memorable worktree names (no UUIDs)
- Centralized `~/.git-wt` storage
- Editor integration (VS Code, IntelliJ)
- `--copy-env` flag for environment inheritance

### git-worktree-runner (CodeRabbit)
- Bash-based, works with Claude, Cursor, OpenCode, Copilot, Gemini
- Worktree-per-agent or worktree-per-task mode
- CI-friendly (headless mode for automated reviews)

### OpenCode 1.16.0+ Native Worktrees
- Managed workspace cloning (automatic worktree creation)
- Session relocation (resume work across sessions)
- No external script needed for basic workflow

### Cursor Worktrees
- Native worktree support via Agents Window
- `/worktree` command
- `/best-of-n` for multi-model comparison
- `.cursor/worktrees.json` config

### Distilled Best Practices

| Practice | Description |
|----------|-------------|
| Worktree-per-task | One worktree per SDD change, not per agent session |
| Marker files | `.agent-parent-branch`, `.agent-context`, `.agent-state` |
| Serialized merges | File lock to prevent concurrent merges from agents |
| Merge-tree pre-check | `git merge-tree` before `git merge` to detect conflicts early |
| Auto-commit on exit | Trap SIGTERM/EXIT to auto-commit + cleanup |
| Config copying | Copy `.config/opencode/` into worktree at creation |
| Sequential merge | One merge at a time, test after each |
| Cleanup policy | Remove worktree after merge + `git worktree prune` in CI |

---

## Approaches

### Approach A: Consolidate into unified `code-work` script with full SDD integration

Merge `work-flow` + `git-flow` into a single `work-flow` script. Add SDD-aware subcommands (`--sdd <change-name>`). Remove all redundant scripts.

| Aspect | Detail |
|--------|--------|
| **Mechanics** | Extend existing `work-flow` with: `--sdd <change-name>` for named worktrees; marker file creation; config copying; merge-tree pre-check; `--yes` flag; EXIT trap |
| **Retained** | `work-flow` as sole standalone script |
| **Removed** | `git-flow`, `opencode-worktree`, `oc-wt`, `git-worktree-flow` (or alias), 4 thin wrappers |
| **Shell** | Convert wrappers to zsh aliases; update `code-work()` to use `--sdd` |
| **Package** | Update `pkgs/nixos-scripts/default.nix` |
| **Effort** | Medium (1-2 sessions) |
| **Lines changed** | ~450 (work-flow extended + others removed + shell + package) |

**Pros:**
- Single source of truth for worktree management
- Full SDD integration (named worktrees, marker files, context)
- Adds modern best practices (merge-tree pre-check, --yes, traps)
- Eliminates ~400 lines of dead code

**Cons:**
- Still Bash (no testability improvement)
- Risk of regression if current code-flow is referenced elsewhere
- More complexity in one file

### Approach B: Minimal SDD wrappers around existing work-flow

Create 3 new scripts (`bin/sdd-start`, `bin/sdd-finish`, `bin/sdd-abort`) that wrap `work-flow` with SDD awareness. Leave existing scripts untouched.

| Aspect | Detail |
|--------|--------|
| **Mechanics** | New `sdd-start <change-name>` calls `work-flow start <change-name>`, creates marker files; `sdd-finish` updates state.yaml; `sdd-abort` cleans up |
| **Retained** | All existing scripts |
| **New** | `bin/sdd-start`, `bin/sdd-finish`, `bin/sdd-abort` (~30 lines each) |
| **Effort** | Low (1 session) |
| **Lines changed** | ~100 (3 new scripts + package update) |

**Pros:**
- Minimal risk, fastest to ship
- Leaves existing workflow intact
- Easy to review

**Cons:**
- Perpetuates underlying duplication
- Two systems to maintain (bare and SDD-aware)
- Does NOT fix the orphaned worktree, merge safety, or interactive blocking issues

### Approach C: OpenCode skill/command for worktree management

Create an OpenCode skill (`skills/worktree-manager/SKILL.md`) or command (`commands/worktree.md`) that manages worktrees from within OpenCode.

| Aspect | Detail |
|--------|--------|
| **Mechanics** | New skill/command file that uses inline bash to call git-worktree with SDD context from ENV |
| **Retained** | Existing scripts unchanged (or removed if fully replaced) |
| **Effort** | Medium (2 sessions) — need to understand skill/command API |
| **Lines changed** | ~60-100 (new skill or command file) |

**Pros:**
- Deepest OpenCode integration
- Could leverage OpenCode 1.16+ native workspace features
- No standalone scripts needed for OpenCode users

**Cons:**
- Ties workflow to OpenCode exclusively
- Does not help when working outside OpenCode (shell, tmux, SSH)
- New API surface to learn and maintain
- OpenCode native features may supercede this work

### Approach D: Extend work-flow as single source + SDD hooks (Recommended)

Keep `work-flow` as the sole standalone script. Remove `git-flow`. Add SDD awareness via `--sdd <change-name>` flag. Add modern best practices. Convert thin wrappers to shell aliases.

| Aspect | Detail |
|--------|--------|
| **Mechanics** | Extend `work-flow` with `--sdd <change-name>` flag; add marker file creation/reading; add merge-tree pre-check; add `--yes`; add EXIT trap for auto-cleanup; copy `.config/opencode/` into worktree; make REPO_ROOT dynamic (`git rev-parse --show-toplevel`) |
| **Retained** | `work-flow` as sole standalone script; `git-worktree-flow` as alias |
| **Removed** | `git-flow`, `opencode-worktree`, `oc-wt`, 4 thin wrappers |
| **Shell** | Convert thin wrappers to zsh aliases; update `code-work()` to pass `--sdd` |
| **Package** | Update `pkgs/nixos-scripts/default.nix` |
| **Effort** | Medium (1-2 sessions) |
| **Lines changed** | ~350 (work-flow modified + others removed + shell + package) |

**Pros:**
- Single source of truth
- Backwards-compatible (existing `work-flow start` still works without `--sdd`)
- SDD hooks via marker files are lightweight and reversible
- Adds modern best practices without coupling to SDD
- Bash is well-suited for git operations (direct CLI calls, no abstraction layer)
- Leaves option for future Go migration (as explored in #541)

**Cons:**
- Still Bash (no unit tests)
- Marker files add filesystem state that could be stale or orphaned
- Needs careful migration for any active worktrees

---

## Recommendation

**Approach D** with selective elements from Approach A: Extend `work-flow` as the single source of truth, add SDD hooks via `--sdd <change-name>`, consolidate away `git-flow` and the 4 thin wrappers.

This approach:
1. **Eliminates ~400 lines of dead code** by removing `git-flow` (the near-duplicate) and 4 thin wrappers (5 lines each)
2. **Keeps the proven foundation**: `work-flow` is already the best-maintained script and the one used by shell integration
3. **Adds SDD integration via `--sdd` flag**: naming worktrees after change names, writing marker files for context, enabling state.yaml awareness
4. **Adds modern best practices**: `git merge-tree` pre-check, `--yes` flag for non-interactive use, EXIT trap for auto-cleanup, config copying at creation time
5. **Fixes all identified issues** with a single coherent change
6. **Leaves the Go migration option open** for a future change if bash maintenance becomes burdensome

The key design principle: **SDD awareness should be opt-in** via `--sdd`, not forced. Pure git worktree operations should still work for non-SDD tasks.

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing worktrees | Active worktrees use old naming/branch scheme | Migration: detect old worktrees and offer `work-flow migrate` |
| Shell alias conflicts | start-work/finish-work/abort-work changed from scripts to aliases | Check all references; update in shell.nix with a soft transition period |
| Packaging gaps | opencode-worktree not in nixos-scripts package | If replaced with shell function, remove from package; verify remaining scripts still work |
| SDD coupling risk | Adding SDD hooks could break pure git operations | Keep `--sdd` as opt-in flag; all existing subcommands work unchanged |
| OpenCode version drift | OpenCode 1.16+ native workspaces may obsolete this | Design for graceful coexistence; native worktree support supplements, not replaces |
| Marker file staleness | Orphaned marker files on failed cleanup | Add `work-flow prune` subcommand that cleans marker files too |

---

## Depth Chart

```
Layer 3: SDD Commands (sdd-new, sdd-explore, sdd-propose, ...)
         ─── calls ───
Layer 2: work-flow --sdd <change-name>
         ├── init             Initialize .worktrees + .gitignore
         ├── start [--sdd]    Create worktree (SDD-aware or plain)
         ├── finish [msg]     Commit + merge + cleanup
         ├── abort            Discard + cleanup
         ├── status           Show current state
         ├── list             List all worktrees
         ├── clean [name]     Remove worktree(s)
         ├── prune            git worktree prune + stale markers
         └── migrate          Convert old worktrees to new format
         ─── calls ───
Layer 1: Git (worktree, branch, merge, merge-tree)
```

The SDD commands (layer 3) are OpenCode commands that call `work-flow` (layer 2) with `--sdd` context. Layer 2 wraps raw git operations (layer 1) with safety, naming, and lifecycle automation.
