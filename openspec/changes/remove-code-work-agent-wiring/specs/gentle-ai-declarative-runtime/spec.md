# Delta for Gentle AI Declarative Runtime

## MODIFIED Requirements

### Requirement: Managed Writing-Agent Profile

Generated OpenCode configuration MUST include a named managed-writing-task profile with the managed-worktree capability boundary. It MUST allow only assigned-worktree editing, branch-local Git operations, and tests, and MUST deny host mutation and lifecycle authority. The profile MUST NOT be granted any repository-provided `code-work` or Nix check command, and its prompt MUST NOT contain any `code-work` instruction. Declarative Home Manager ownership MUST remain unchanged.

(Previously: allowed allowlisted local checks.)

#### Scenario: Emit the restricted agent profile [hosts: rog, thinkcentre, t14, macm5]
- GIVEN a host configuration that enables the managed-worktree feature
- WHEN its generated OpenCode configuration is inspected
- THEN the managed-writing-task profile contains the required grants and denials
- AND no `code-work` or Nix check command is granted
- AND Home Manager remains the configuration deployment authority
