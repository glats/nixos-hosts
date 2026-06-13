# OpenCode Skill Registry

Index of local skills for the nixos-hosts project. All paths are absolute to
`~/.config/opencode/skills/`. Subagents read the full SKILL.md source of truth.

## User-Level Skills

| Name | Path | Description |
|------|------|-------------|
| `branch-pr` | `~/.config/opencode/skills/branch-pr/SKILL.md` | Create Gentle AI pull requests with issue-first checks. Trigger: creating, opening, or preparing PRs for review. |
| `cavecrew` | `~/.config/opencode/skills/cavecrew/SKILL.md` | Decision guide for delegating to caveman-style subagents. Spawn investigator/builder/reviewer subagents instead of inline work. |
| `caveman` | `~/.config/opencode/skills/caveman/SKILL.md` | Ultra-compressed communication mode. Cuts token usage ~75% speaking like caveman. Supports lite/full/ultra/wenyan intensities. |
| `caveman-commit` | `~/.config/opencode/skills/caveman-commit/SKILL.md` | Ultra-compressed conventional commit generator. Subject <=50 chars, body only when "why" isnt obvious. |
| `caveman-compress` | `~/.config/opencode/skills/caveman-compress/SKILL.md` | Compress memory files (CLAUDE.md, todos) into caveman format. Backup saved as FILE.original.md. |
| `caveman-help` | `~/.config/opencode/skills/caveman-help/SKILL.md` | Quick-reference card for all caveman modes, skills, and commands. |
| `caveman-review` | `~/.config/opencode/skills/caveman-review/SKILL.md` | Ultra-compressed code review comments. One line per comment: location, problem, fix. |
| `caveman-stats` | `~/.config/opencode/skills/caveman-stats/SKILL.md` | Show real token usage and estimated savings from session log. |
| `chained-pr` | `~/.config/opencode/skills/chained-pr/SKILL.md` | Split oversized changes (400+ lines) into chained PRs protecting review focus. |
| `cognitive-doc-design` | `~/.config/opencode/skills/cognitive-doc-design/SKILL.md` | Design docs that reduce cognitive load for readers and reviewers. |
| `comment-writer` | `~/.config/opencode/skills/comment-writer/SKILL.md` | Write warm, direct collaboration comments for PRs, issues, reviews. |
| `go-testing` | `~/.config/opencode/skills/go-testing/SKILL.md` | Go testing patterns: go test coverage, Bubbletea teatest, golden files. |
| `issue-creation` | `~/.config/opencode/skills/issue-creation/SKILL.md` | Create GitHub issues with issue-first enforcement checks. |
| `judgment-day` | `~/.config/opencode/skills/judgment-day/SKILL.md` | Run blind dual review, fix confirmed issues, then re-judge. |
| `nix-verify` | `~/.config/opencode/skills/nix-verify/SKILL.md` | Verify Nix packages/options via MCP before writing .nix files. Never guess option paths. |
| `skill-creator` | `~/.config/opencode/skills/skill-creator/SKILL.md` | Create new AI agent skills following LLM-first spec with valid frontmatter. |
| `skill-improver` | `~/.config/opencode/skills/skill-improver/SKILL.md` | Audit and upgrade existing LLM-first skills. |
| `work-unit-commits` | `~/.config/opencode/skills/work-unit-commits/SKILL.md` | Plan commits as reviewable work units. Keep tests and docs with code. |

## Project Convention Files

| File | Path |
|------|------|
| AGENTS.md | `~/.nixos/AGENTS.md` |

## Compact Rules

- **nix-verify**: Always verify Nix packages/options via MCP before writing .nix files. Never guess option paths.
- **caveman*** skills: Use when user says "caveman", "brief", or "less tokens".
- **branch-pr / issue-creation**: Follow issue-first enforcement — issue must exist before PR/branch.
- **SDD phase skills**: Follow `_shared/sdd-phase-common.md` protocol. Persist artifacts to Engram via topic_key.
