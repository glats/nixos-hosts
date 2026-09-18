# Managed Agent Worktrees

`code-work managed` gives each dispatched writing task a branch-attached worktree under `.worktrees/managed/<task-id>`. The task identifier is lowercase alphanumeric text with hyphens, one to 63 characters. Its branch is `managed/<task-id>`.

## Lifecycle

Run `managed start <task-id> [--base <branch>]` from a clean attached main checkout. The command records state in the Git common directory, locks the worktree, and launches `opencode --agent managed-writing-task <worktree>`. Repeating the command reuses only matching active metadata.

The states are `active`, `ready-for-integration`, `integrated`, and `abandoned`. From the assigned worktree, `managed ready <task-id>` requires a clean committed branch. `managed inspect [<task-id>]` reports records; `managed abandon <task-id>` preserves the branch and worktree for diagnosis. `managed cleanup <task-id>` is human-controlled and removes only integrated or explicitly abandoned work. `managed recover-lock` is an explicit recovery action for an operator who has confirmed that no lifecycle operation is running.

## Capability boundary

The named `managed-writing-task` agent is default-deny for Bash and external directories. It can edit its assigned worktree, inspect and commit branch-local Git changes, run tests, and request four scoped checks: `fmt`, `eval <flake-target>`, `flake-check`, and `build <flake-target>`. Builds are capped at one job and one core.

Activation, generation/profile mutation, input updates, garbage collection, daemon changes, `sudo`, service control, push, integration, cleanup, arbitrary Nix arguments, and external paths are denied. This is a permissions boundary, not OS sandboxing or credential/network/port isolation.

## Human integration gate

Only a clean expected main checkout may run `managed integrate <task-id> --validate <check|build>`. The gate takes the repository lock, verifies the ready record and branch, performs a non-fast-forward merge, and validates without activation. A failed validation resets the merge where possible and retains the task record and worktree. `--activate system` or `--activate home` is an additional explicit human request; nothing pushes or cleans up automatically.

The contract is portable across Linux and Darwin and does not change Nix daemon concurrency. Home Manager remains the declarative owner of the generated OpenCode configuration and named agent.

## Rollback

Revert the Go command, OpenCode policy, shell wrapper, and this document. Existing non-managed `code-work` lifecycle commands remain available. Leave task records, branches, and worktrees in place until an operator explicitly abandons or cleans them.
