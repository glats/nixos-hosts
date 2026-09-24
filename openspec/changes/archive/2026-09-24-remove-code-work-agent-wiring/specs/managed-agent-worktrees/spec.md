# Delta for Managed Agent Worktrees

## MODIFIED Requirements

### Requirement: Managed Agent Capability Boundary

The managed writing agent MUST allow edits in its assigned worktree, branch-local Git status/diff/commit, and tests. The agent MUST NOT be granted any repository-provided `code-work` or Nix check command, and its prompt MUST NOT contain any `code-work` instruction. The agent and dispatch surface MUST deny activation, generation or profile mutation, flake input or lock updates, garbage collection, daemon configuration, `sudo`, host-service mutation, integration, cleanup, push, and arbitrary Nix arguments.

(Previously: allowed named `fmt`, `eval`, `flake-check`, and scoped `build` checks via `code-work check`.)

#### Scenario: Agent has no repository check command [hosts: rog, thinkcentre, t14, macm5]
- GIVEN an active managed writing task under a default-deny Bash policy
- WHEN its prompt and Bash allowlist are inspected
- THEN no `code-work` or Nix check command is granted
- AND the prompt contains no `code-work` instruction

#### Scenario: Deny a host-mutating request [hosts: rog, thinkcentre, t14, macm5]
- GIVEN an active managed writing task
- WHEN it requests any denied operation
- THEN the request MUST be rejected before the operation executes
