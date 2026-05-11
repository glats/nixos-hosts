# OpenCode Skill Registry

Index of local skills for the nixos project. These override or extend upstream
gentle-ai skills. All paths relative to `modules/home/opencode/skills/`.

## Skills

| Name | Path | Description |
|------|------|-------------|
| `branch-pr` | `branch-pr/SKILL.md` | PR creation workflow following issue-first enforcement |
| `caveman` | `caveman/SKILL.md` | Ultra-compressed communication mode |
| `caveman-commit` | `caveman-commit/SKILL.md` | Compressed conventional commit generator |
| `caveman-review` | `caveman-review/SKILL.md` | Compressed code review comments |
| `go-testing` | `go-testing/SKILL.md` | Go testing patterns for Gentleman.Dots, Bubbletea TUI |
| `issue-creation` | `issue-creation/SKILL.md` | Issue creation workflow following issue-first system |
| `judgment-day` | `judgment-day/SKILL.md` | Parallel adversarial review with two blind judges |
| `nix-verify` | `nix-verify/SKILL.md` | Use nixos MCP to verify packages/options in .nix files |
| `sdd-apply` | `sdd-apply/SKILL.md` | Implement tasks from SDD change |
| `sdd-archive` | `sdd-archive/SKILL.md` | Sync delta specs and archive completed change |
| `sdd-design` | `sdd-design/SKILL.md` | Create technical design with architecture decisions |
| `sdd-explore` | `sdd-explore/SKILL.md` | Explore and investigate ideas before committing |
| `sdd-init` | `sdd-init/SKILL.md` | Bootstrap SDD context, detect stack and conventions |
| `sdd-onboard` | `sdd-onboard/SKILL.md` | Guided end-to-end SDD workflow walkthrough |
| `sdd-propose` | `sdd-propose/SKILL.md` | Create change proposal with intent and scope |
| `sdd-spec` | `sdd-spec/SKILL.md` | Write specs with requirements and scenarios |
| `sdd-tasks` | `sdd-tasks/SKILL.md` | Break change into implementation task checklist |
| `sdd-verify` | `sdd-verify/SKILL.md` | Validate implementation matches specs and design |
| `skill-creator` | `skill-creator/SKILL.md` | Create new AI agent skills following spec |
| `skill-registry` | `skill-registry/SKILL.md` | Create or update the skill registry for project |

## Compact Rules

- **nix-verify**: Always verify Nix packages/options via MCP before writing .nix files. Never guess option paths.
- **sdd-*** skills: Follow `skills/_shared/sdd-phase-common.md` protocol. Persist artifacts to Engram via topic_key.
- **caveman*** skills: Use when user says "caveman", "brief", or "less tokens".
- **branch-pr / issue-creation**: Follow issue-first enforcement — issue must exist before PR/branch.