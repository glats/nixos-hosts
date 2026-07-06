# Delta Spec: bin/code-work

**Change**: worktree-opencode-scripts-update
**Domain**: bin/code-work
**Date**: 2026-07-05
**Mode**: Delta (no existing main spec — all requirements are ADDED)

---

## Overview

Consolidate 9 existing worktree scripts (~1100 lines) into a single `bin/code-work` bash script with 4 subcommands. Update the Nix package definition and shell integration to reflect the new script. Remove all obsolete scripts.

---

## ADDED Requirements

### REQ-CW-1: Create worktree (`code-work <name>`)

- **ID**: REQ-CW-1
- **Priority**: P0
- **Description**: The script SHALL accept a positional name argument and create a named git worktree from the current branch, launching `opencode` inside it.

**Specification**:

1. The script SHALL accept a single positional argument as the worktree name (e.g., `code-work "fix-nvidia"`).
2. The script MUST detect the repository root automatically via `git rev-parse --show-toplevel`. It MUST NOT use hardcoded paths.
3. The script MUST create worktrees in the `.worktrees/<name>` directory under the repository root.
4. The script MUST create a branch from the CURRENT branch (not hardcoded to `master` or `main`). The branch name SHALL be the worktree name provided as argument.
5. The script SHALL verify that the current branch has no uncommitted changes before creating the worktree. If uncommitted changes exist, it SHALL print an error and exit with non-zero status.
6. The script SHALL write a `.worktree-base` file in the root of the new worktree directory containing the base branch name (the branch that was current at creation time).
7. After successful creation, the script MUST run `opencode` in the worktree directory.
8. The script MUST verify that `.worktrees/` is listed in `.gitignore`. If not present, it SHALL print a warning.
9. If no name argument is given, the script MAY auto-generate a name (e.g., `agent-YYYYMMDD-HHMMSS`), but the primary design requires an explicit name.

**Scenarios**:

```
Scenario: Create worktree from current branch
  Given the current git branch is "feature/my-change"
  And there are no uncommitted changes
  When the user runs `code-work "fix-nvidia"`
  Then a worktree is created at `.worktrees/fix-nvidia`
  And a branch named "fix-nvidia" is created from "feature/my-change"
  And a `.worktree-base` file exists in the worktree root containing "feature/my-change"
  And `opencode` is launched in the worktree directory
```

```
Scenario: Reject creation when current branch has uncommitted changes
  Given the current branch has uncommitted changes
  When the user runs `code-work "fix-nvidia"`
  Then the script prints an error message
  And exits with non-zero status
  And no worktree is created
```

```
Scenario: Warn when .worktrees/ not in .gitignore
  Given `.worktrees/` is not in `.gitignore`
  When the user runs `code-work "fix-nvidia"`
  Then the script prints a warning about missing `.gitignore` entry
  And still creates the worktree successfully
```

```
Scenario: Auto-generate name when no argument given
  Given the user runs `code-work` without arguments
  When no name is provided
  Then the script MAY auto-generate a name with format `agent-YYYYMMDD-HHMMSS`
```

```
Scenario: Dynamic repo root detection
  Given the repository is cloned at a custom path (not /home/glats/.nixos)
  When the user runs `code-work "test"`
  Then the script uses `git rev-parse --show-toplevel` to find the correct root
  And creates `.worktrees/test` at the detected root
```

### REQ-CW-2: Finish worktree (`code-work --finish`)

- **ID**: REQ-CW-2
- **Priority**: P0
- **Description**: The script SHALL detect it is inside a worktree, validate state, and clean up.

**Specification**:

1. The script MUST detect it is being run from inside a worktree directory by checking if the current working directory contains a `.worktree-base` file.
2. The script MUST check for uncommitted changes. If any exist, it SHALL print a clear error message and exit with non-zero status.
3. The script MUST read `.worktree-base` to determine the base branch to return to.
4. The script SHALL return to the repository root.
5. The script SHALL checkout the base branch recorded in `.worktree-base`.
6. The script SHALL remove the worktree via `git worktree remove <worktree-name>`.
7. The script SHALL delete the local worktree branch via `git branch -D <branch-name>`.
8. After successful cleanup, the script SHALL run `git worktree prune`.
9. If `.worktree-base` is missing, the script SHALL print a helpful error message directing the user to manually finish the worktree (e.g., `git checkout <base-branch> && git worktree remove <path> && git branch -d <branch>`).
10. The script SHOULD check if the branch was pushed to upstream before deleting it. If the branch has no upstream, it SHALL ask the user for confirmation before deleting.

**Scenarios**:

```
Scenario: Finish worktree cleanly
  Given the current directory is inside a worktree
  And `.worktree-base` exists with content "master"
  And there are no uncommitted changes
  When the user runs `code-work --finish`
  Then the script checks out the "master" branch
  And removes the worktree via `git worktree remove`
  And deletes the local branch via `git branch -D`
  And runs `git worktree prune`
  And exits with status 0
```

```
Scenario: Error on uncommitted changes
  Given the current directory is inside a worktree
  And there are uncommitted changes
  When the user runs `code-work --finish`
  Then the script prints: "Error: uncommitted changes in worktree. Commit before finishing."
  And exits with non-zero status
  And the worktree is not removed
```

```
Scenario: Missing .worktree-base
  Given the current directory is inside a worktree
  And `.worktree-base` does not exist (legacy worktree)
  When the user runs `code-work --finish`
  Then the script prints a helpful error message with manual steps
  And exits with non-zero status
```

```
Scenario: Branch pushed upstream — safe delete
  Given the worktree branch has an upstream configured
  And there are no uncommitted changes
  When the user runs `code-work --finish`
  Then the script deletes the local branch without asking
```

```
Scenario: Branch not pushed upstream — ask before delete
  Given the worktree branch has no upstream configured
  And there are no uncommitted changes
  When the user runs `code-work --finish`
  Then the script asks for confirmation before deleting the local branch
```

### REQ-CW-3: List worktrees (`code-work --list`)

- **ID**: REQ-CW-3
- **Priority**: P1
- **Description**: The script SHALL display all git worktrees.

**Specification**:

1. The script MUST run `git worktree list` and display its output.
2. The script SHOULD indicate which worktree is currently active (if running from inside a worktree).

**Scenarios**:

```
Scenario: List worktrees from main repo
  Given the current directory is the main repository root
  When the user runs `code-work --list`
  Then the script runs `git worktree list`
  And displays all worktrees with their paths and branches
```

```
Scenario: List worktrees from inside a worktree
  Given the current directory is inside a worktree
  When the user runs `code-work --list`
  Then the script runs `git worktree list`
  And indicates the current worktree as active
```

### REQ-CW-4: Prune stale worktrees (`code-work --prune`)

- **ID**: REQ-CW-4
- **Priority**: P1
- **Description**: The script SHALL clean stale git worktree references.

**Specification**:

1. The script MUST run `git worktree prune` to clean stale administrative references.

**Scenarios**:

```
Scenario: Prune stale worktrees
  Given there are stale worktree references
  When the user runs `code-work --prune`
  Then the script runs `git worktree prune`
  And exits with status 0
```

### REQ-CW-5: Error handling

- **ID**: REQ-CW-5
- **Priority**: P0
- **Description**: The script SHALL use strict error handling and clear error messages.

**Specification**:

1. The script MUST use `set -euo pipefail` at the top.
2. The script SHALL print clear, actionable error messages.
3. The script SHALL exit with non-zero status on any error.
4. The script MUST use `git rev-parse --show-toplevel` to find the repo root — it MUST NOT use hardcoded paths.
5. Unknown subcommands or invalid arguments SHALL print a usage message and exit non-zero.

**Scenarios**:

```
Scenario: Unknown subcommand
  Given the user runs `code-work --unknown-flag`
  When the flag is not recognized
  Then the script prints usage information
  And exits with non-zero status
```

```
Scenario: No arguments
  Given the user runs `code-work` with no arguments
  When no subcommand or name is provided
  Then the script prints usage information
  And exits with non-zero status (unless auto-generate behavior is implemented)
```

### REQ-CW-6: General script structure

- **ID**: REQ-CW-6
- **Priority**: P0
- **Description**: The script SHALL be a single, executable bash script consistent with existing `bin/` scripts.

**Specification**:

1. The script SHALL be a single bash script file located at `bin/code-work`.
2. The script SHALL be executable (`chmod +x`).
3. The script SHALL be consistent with existing `bin/` scripts in style (bash shebang, exit codes, argument parsing).
4. The script SHALL be self-contained with no external dependencies beyond git, bash, and standard Unix tools.

**Scenarios**:

```
Scenario: Script is executable
  Given the file `bin/code-work` exists
  When the file permissions are checked
  Then it SHALL have the executable bit set
```

### REQ-CW-7: Package definition update (pkgs/nixos-scripts/default.nix)

- **ID**: REQ-CW-7
- **Priority**: P0
- **Description**: The nixos-scripts package SHALL include `code-work` and exclude all removed scripts.

**Specification**:

1. `bin/code-work` MUST be added to the package via `cp $src/code-work $out/bin/`.
2. All 9 removed scripts listed in REQ-RM-1 MUST be removed from the package.
3. The `ln -s git-flow git-worktree-flow` symlink MUST be removed.
4. `nix flake check --no-build` MUST pass after all changes.

**Scenarios**:

```
Scenario: code-work is packaged
  Given the nixos-scripts package definition is updated
  When the package is built
  Then `code-work` is installed to `$out/bin/code-work`
```

```
Scenario: Old scripts removed from package
  Given the nixos-scripts package definition is updated
  When the package is built
  Then none of the 9 removed scripts are present in `$out/bin/`
```

### REQ-CW-8: Shell integration update (home-linux/shell.nix)

- **ID**: REQ-CW-8
- **Priority**: P1
- **Description**: The `code-work` shell function and aliases SHALL be updated to use the new script.

**Specification**:

1. The `code-work()` zsh function in `home-linux/shell.nix` SHALL be replaced to call `bin/code-work` directly.
2. The shell alias `wt-done` SHALL point to `code-work --finish`.
3. The shell alias `wt-discard` SHALL be removed (no `--abort` subcommand exists).
4. The shell alias `wt-list` SHALL be added, pointing to `code-work --list`.

**Scenarios**:

```
Scenario: Shell function calls code-work directly
  Given the `code-work()` function is updated
  When the user runs `code-work "name"`
  Then it calls `$HOME/.nixos/bin/code-work "name"`
```

```
Scenario: wt-done alias works
  Given the shell aliases are updated
  When the user runs `wt-done`
  Then it calls `code-work --finish`
```

```
Scenario: wt-list alias works
  Given the shell aliases are updated
  When the user runs `wt-list`
  Then it calls `code-work --list`
```

---

## REMOVED Requirements

### REQ-RM-1: Obsolete scripts

- **ID**: REQ-RM-1
- **Priority**: P0
- **Description**: 9 obsolete scripts SHALL be removed from `bin/`.

**Removed scripts** (Reason: All functionality absorbed into `bin/code-work`; these scripts caused fragmentation and maintenance burden):

| File | Reason |
|------|--------|
| `bin/work-flow` | Core worktree manager (417 lines) — replaced by `code-work` |
| `bin/git-flow` | 90% duplicate of work-flow (380 lines) — redundant |
| `bin/git-worktree-flow` | Partial overlap with work-flow (148 lines) — replaced |
| `bin/opencode-worktree` | Uses git-flow internally (64 lines) — not packaged; replaced |
| `bin/oc-wt` | Orphaned worktree bug (54 lines) — replaced by `code-work` |
| `bin/start-work` | Thin wrapper (5 lines) — converted to shell alias |
| `bin/finish-work` | Thin wrapper (5 lines) — converted to shell alias |
| `bin/abort-work` | Thin wrapper (5 lines) — removed; no `--abort` in new design |
| `bin/list-work` | Thin wrapper (5 lines) — converted to shell alias |

**Migration**: After the Nix rebuild installs the new package, the old scripts will no longer be in PATH. Users can still reference them from git history. Any scripts or configurations that directly call these binaries by path must be updated.

**Scenarios**:

```
Scenario: Scripts removed from filesystem
  Given the cleanup PR is merged
  When the filesystem is checked
  Then none of the 9 files listed above exist in `bin/`
```

```
Scenario: Scripts removed from package
  Given the nixos-scripts package definition is updated
  When the package builds
  Then none of the 9 scripts are copied to `$out/bin/`
```

---

## Requirements Coverage Summary

| ID | Description | Priority | Scenarios |
|----|-------------|----------|-----------|
| REQ-CW-1 | Create worktree | P0 | 5 scenarios |
| REQ-CW-2 | Finish worktree | P0 | 5 scenarios |
| REQ-CW-3 | List worktrees | P1 | 2 scenarios |
| REQ-CW-4 | Prune worktrees | P1 | 1 scenario |
| REQ-CW-5 | Error handling | P0 | 2 scenarios |
| REQ-CW-6 | General script structure | P0 | 1 scenario |
| REQ-CW-7 | Package definition update | P0 | 2 scenarios |
| REQ-CW-8 | Shell integration update | P1 | 3 scenarios |
| REQ-RM-1 | Obsolete scripts | P0 | 2 scenarios |

**Total**: 8 ADDED requirements, 1 REMOVED requirement, 23 scenarios
