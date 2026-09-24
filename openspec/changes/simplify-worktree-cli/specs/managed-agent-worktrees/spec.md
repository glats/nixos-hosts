# Delta for Managed Agent Worktrees

## ADDED Requirements

### Requirement: Canonical Top-Level Command Surface

The managed lifecycle MUST be exposed through top-level `code-work` verbs `new <task>`, `check <check> [target]`, `ready`, `status`, `merge <task>`, and `clean <task>`, with no `managed` namespace. Worktree-context verbs MUST error "not inside a managed worktree" from the main checkout or a legacy worktree, not silently no-op.

#### Scenario: Dispatch the simplified surface [hosts: rog, thinkcentre, t14, macm5]
- GIVEN the CLI is installed
- WHEN a top-level verb is invoked in its correct context
- THEN it dispatches without a `managed` subcommand prefix

#### Scenario: Reject worktree-context verb outside a worktree [hosts: rog, thinkcentre, t14, macm5]
- GIVEN the cwd is the main checkout or a legacy worktree
- WHEN `check`, `ready`, or `status` runs without a task argument
- THEN the command errors "not inside a managed worktree" and mutates no state

### Requirement: Cwd Task Resolution

Worktree-context verbs MUST resolve the task identifier from cwd by matching `record.Path == cwd` exactly. Resolution MUST NOT use prefix matching, nor resolve from the main checkout, a legacy worktree, or a worktree named `managed`/`managed-*`.

#### Scenario: Resolve task from worktree cwd [hosts: rog, thinkcentre, t14, macm5]
- GIVEN a managed worktree whose record path equals cwd
- WHEN `check fmt` is invoked with no task argument
- THEN it resolves that task identifier and admits the check

#### Scenario: Refuse resolution outside a managed worktree [hosts: rog, thinkcentre, t14, macm5]
- GIVEN the cwd is a legacy worktree named `managed` or `managed-demo`
- WHEN a worktree-context verb is invoked
- THEN it MUST NOT resolve to a managed task and errors "not inside a managed worktree"

### Requirement: Shell Wrapper Verb Forwarding

The Linux `code-work()` wrapper MUST route the canonical verbs (`new`, `check`, `ready`, `status`, `merge`, `clean`, `abandon`, `recover-lock`) to the binary, bypassing the legacy create-name branch.

#### Scenario: Route canonical verbs past the legacy create branch [hosts: rog, thinkcentre, t14]
- GIVEN the Linux shell wrapper is active
- WHEN `code-work new demo` is invoked
- THEN it dispatches `new` with argument `demo` and does NOT create a legacy worktree named `new`

### Requirement: Compatibility Forwarding Shim

A hidden `managed` forwarding shim MUST accept the legacy verb forms for one release, forwarding to the canonical handler with one stderr deprecation hint. It MUST preserve exit codes, stay absent from `--help`, and be removed next release.

#### Scenario: Forward a legacy managed invocation [hosts: rog, thinkcentre, t14, macm5]
- GIVEN the shim is present during the migration window
- WHEN `code-work managed start demo` is invoked
- THEN it forwards to `new`, prints a stderr hint, exits with the canonical code

#### Scenario: Keep the shim out of help [hosts: rog, thinkcentre, t14, macm5]
- GIVEN the CLI is invoked with `--help`
- THEN the `managed` adapter MUST NOT appear in usage output

## MODIFIED Requirements

### Requirement: Managed Agent Capability Boundary

The managed writing agent MUST allow edits in its assigned worktree, branch-local Git status/diff/commit, tests, and only the named `fmt`, `eval`, `flake-check`, and scoped `build` checks via the canonical `code-work check` command. The agent and dispatch surface MUST deny activation, generation or profile mutation, flake input or lock updates, garbage collection, daemon configuration, `sudo`, host-service mutation, integration, cleanup, push, and arbitrary Nix arguments.
(Previously: allowlisted checks were named without binding them to the canonical command surface.)

#### Scenario: Run an allowlisted local check [hosts: rog, thinkcentre, t14, macm5]
- GIVEN an active assigned worktree under a default-deny Bash policy
- WHEN the agent requests `code-work check fmt` rooted in that worktree
- THEN the allowlist admits the request without host activation or shared-profile mutation

#### Scenario: Deny a host-mutating request [hosts: rog, thinkcentre, t14, macm5]
- GIVEN an active managed writing task
- WHEN it requests any denied operation
- THEN the request MUST be rejected before the operation executes
