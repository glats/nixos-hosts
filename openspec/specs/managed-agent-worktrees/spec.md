# Managed Agent Worktrees Specification

## Purpose

Provide a portable, controlled workspace for each dispatched writing task while reserving repository integration and host mutation for a human operator.

## Requirements

### Requirement: Unique Task Workspace

Each dispatched writing task MUST receive one unique task identifier, attached branch, and worktree at `.worktrees/managed/<task-id>`. The task workspace MUST be based on an approved revision and MUST NOT be shared by another task. Re-dispatching the same active task MAY reuse only its matching recorded workspace.

#### Scenario: Dispatch independent writing tasks [hosts: rog, thinkcentre, t14, macm5]
- GIVEN two valid, distinct task identifiers and a clean approved base
- WHEN both tasks are dispatched
- THEN each has a different branch and worktree under `.worktrees/managed/`
- AND each worktree is attached to its own task branch

#### Scenario: Reject conflicting task identity [hosts: rog, thinkcentre, t14, macm5]
- GIVEN a task identifier whose recorded branch, path, or base differs from the request
- WHEN that task is dispatched
- THEN dispatch MUST fail without altering the recorded workspace

### Requirement: Portable Lifecycle Control

Lifecycle creation, state transitions, cleanup, and pruning MUST serialize through a repository-scoped lock that works on Linux and Darwin. Active worktrees MUST be protected from accidental removal. Cleanup MUST require successful integration or explicit abandonment and MUST preserve unfinished branches, worktrees, and diagnostic state.

#### Scenario: Serialize concurrent lifecycle operations [hosts: rog, thinkcentre, t14, macm5]
- GIVEN a lifecycle operation holds the repository lock
- WHEN another lifecycle operation is requested
- THEN the second operation MUST not change lifecycle state until the lock is available

#### Scenario: Preserve interrupted task work [hosts: rog, thinkcentre, t14, macm5]
- GIVEN a task is active or ready for integration and integration or cleanup fails
- WHEN recovery is inspected
- THEN its branch and worktree remain available for diagnosis

### Requirement: Managed Agent Capability Boundary

The managed writing agent MUST allow edits in its assigned worktree, branch-local Git status/diff/commit, tests, and only the named `fmt`, `eval`, `flake-check`, and scoped `build` checks. The agent and dispatch surface MUST deny activation, generation or profile mutation, flake input or lock updates, garbage collection, daemon configuration, `sudo`, host-service mutation, integration, cleanup, push, and arbitrary Nix arguments.

#### Scenario: Run an allowlisted local check [hosts: rog, thinkcentre, t14, macm5]
- GIVEN an active assigned worktree
- WHEN the agent requests an allowlisted check rooted in that worktree
- THEN the check is admitted without host activation or shared-profile mutation

#### Scenario: Deny a host-mutating request [hosts: rog, thinkcentre, t14, macm5]
- GIVEN an active managed writing task
- WHEN it requests any denied operation
- THEN the request MUST be rejected before the operation executes

### Requirement: Human Serialized Integration Gate

Only an explicit human operation from a clean expected main checkout MAY integrate a ready task branch. The gate MUST serialize one integration at a time, validate branch and lifecycle state, run the selected non-activating validation or build, and be the sole path that MAY create or activate NixOS, nix-darwin, or Home Manager generations. On failure it MUST release its lock and preserve task work.

#### Scenario: Integrate a ready task [hosts: rog, thinkcentre, t14, macm5]
- GIVEN a clean expected main checkout and one ready matching task branch
- WHEN a human invokes the integration gate with validation
- THEN exactly that branch is integrated and validation runs serially
- AND activation occurs only when the human explicitly requests it

#### Scenario: Reject unsafe integration [hosts: rog, thinkcentre, t14, macm5]
- GIVEN a dirty or non-main checkout, non-ready task, or mismatched branch
- WHEN integration is requested
- THEN integration MUST fail without merging or cleaning task work

### Requirement: Portable Baseline Scope

The managed-worktree contract MUST behave equivalently on Linux and Darwin. It MUST NOT require container or Bubblewrap containment, global runtime isolation, port isolation, credential isolation, network restriction, or increased Nix daemon concurrency.

#### Scenario: Evaluate the portable policy [hosts: rog, thinkcentre, t14, macm5]
- GIVEN Linux and Darwin host configurations with the managed agent enabled
- WHEN each configuration is evaluated
- THEN each exposes the same managed capability boundary and lifecycle contract
