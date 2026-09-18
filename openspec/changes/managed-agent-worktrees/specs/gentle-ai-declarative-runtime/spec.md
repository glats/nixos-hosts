# Delta for Gentle AI Declarative Runtime

## ADDED Requirements

### Requirement: Managed Writing-Agent Profile

Generated OpenCode configuration MUST include a named managed-writing-task profile with the managed-worktree capability boundary. It MUST allow only assigned-worktree editing, branch-local Git operations, tests, and allowlisted local checks, and MUST deny host mutation and lifecycle authority. Declarative Home Manager ownership MUST remain unchanged.

#### Scenario: Emit the restricted agent profile [hosts: rog, thinkcentre, t14, macm5]
- GIVEN a host configuration that enables the managed-worktree feature
- WHEN its generated OpenCode configuration is inspected
- THEN the managed-writing-task profile contains the required grants and denials
- AND Home Manager remains the configuration deployment authority
