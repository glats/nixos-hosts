# Skill Registry

Project: nixos-hosts
Source: scanned user + project skill directories
Mode: registry index only

## Contract

- This file is an index, not a summary.
- `SKILL.md` is the source of truth.
- Skips `sdd-*`, `_shared`, and `skill-registry`.
- Deduplicates by skill name and prefers project-level skills.

## Indexed Skills

| Name | Scope | Trigger / Description | Path |
|---|---|---|---|
| branch-pr | user | Create Gentle AI pull requests with issue-first checks. Trigger: creating, opening, or preparing PRs for review. | /home/glats/.config/opencode/skills/branch-pr/SKILL.md |
| cavecrew | user | Decision guide for delegating to caveman-style subagents. Tells the main thread WHEN to spawn investigator/builder/reviewer instead of doing work inline. Trigger: delegate to subagent, use cavecrew, spawn investigator/builder/reviewer, save context, compressed agent output. | /home/glats/.config/opencode/skills/cavecrew/SKILL.md |
| caveman | user | Ultra-compressed communication mode. Cuts token usage ~75% by speaking like caveman while keeping full technical accuracy. Supports intensity levels: lite, full (default), ultra. Use when user says caveman mode, talk like caveman, less tokens, be brief, or invokes /caveman. | /home/glats/.config/opencode/skills/caveman/SKILL.md |
| caveman-commit | user | Ultra-compressed commit message generator. Cuts noise from commit messages while preserving intent and reasoning. Conventional Commits format. Use when user says write a commit, commit message, generate commit, /commit. | /home/glats/.config/opencode/skills/caveman-commit/SKILL.md |
| caveman-compress | user | Compress natural language memory files (CLAUDE.md, todos, preferences) into caveman format to save input tokens. Preserves all technical substance, code, URLs, and structure. Trigger: /caveman-compress FILEPATH or compress memory file. | /home/glats/.config/opencode/skills/caveman-compress/SKILL.md |
| caveman-help | user | Quick-reference card for all caveman modes, skills, and commands. One-shot display, not a persistent mode. Trigger: /caveman-help, caveman help, what caveman commands, how do I use caveman. | /home/glats/.config/opencode/skills/caveman-help/SKILL.md |
| caveman-review | user | Ultra-compressed code review comments. Cuts noise from PR feedback while preserving the actionable signal. Each comment is one line: location, problem, fix. Use when user says review this PR, code review, /review. | /home/glats/.config/opencode/skills/caveman-review/SKILL.md |
| caveman-stats | user | Show real token usage and estimated savings for the current session. Reads directly from session log — no AI estimation. Trigger: /caveman-stats. | /home/glats/.config/opencode/skills/caveman-stats/SKILL.md |
| chained-pr | user | Split oversized changes into chained PRs that protect review focus. Trigger: PRs over 400 lines, stacked PRs, review slices. | /home/glats/.config/opencode/skills/chained-pr/SKILL.md |
| cognitive-doc-design | user | Design docs that reduce cognitive load. Trigger: writing guides, READMEs, RFCs, onboarding, architecture, or review-facing docs. | /home/glats/.config/opencode/skills/cognitive-doc-design/SKILL.md |
| comment-writer | user | Write warm, direct collaboration comments. Trigger: PR feedback, issue replies, reviews, Slack messages, or GitHub comments. | /home/glats/.config/opencode/skills/comment-writer/SKILL.md |
| go-testing | user | Apply focused Go testing patterns. Trigger: Go tests, go test coverage, Bubbletea teatest, golden files. | /home/glats/.config/opencode/skills/go-testing/SKILL.md |
| hermes-ephemeral-delegation | user | Orchestrate complex work via delegate_task to protect context. Trigger: broad exploration, multi-file reads, tests/builds, fresh review, or multi-step debug. | /home/glats/.config/opencode/skills/hermes-ephemeral-delegation/SKILL.md |
| issue-creation | user | Create Gentle AI issues with issue-first checks. Trigger: creating GitHub issues, bug reports, or feature requests. | /home/glats/.config/opencode/skills/issue-creation/SKILL.md |
| judgment-day | user | Run blind dual review, fix confirmed issues, then re-judge. Trigger: judgment day, dual review, adversarial review, juzgar. | /home/glats/.config/opencode/skills/judgment-day/SKILL.md |
| nix-verify | project | Use the nixos MCP to verify packages, options, and Nix functions before writing NixOS/Home Manager configuration. Trigger: editing .nix files — adding packages, configuring services, searching for options. | /home/glats/.nixos/shared/opencode/skills/nix-verify/SKILL.md |
| opencode-session-recovery | project | Recover lost opencode sessions from SQLite when project_id drift makes sessions invisible to `opencode session list`. | /home/glats/.nixos/shared/opencode/skills/opencode-session-recovery/SKILL.md |
| skill-creator | user | Create LLM-first skills with valid frontmatter. Trigger: new skills, agent instructions, documenting AI usage patterns. | /home/glats/.config/opencode/skills/skill-creator/SKILL.md |
| skill-improver | user | Audit and upgrade existing LLM-first skills. Trigger: improve skills, audit skills, refactor skills, skill quality. | /home/glats/.config/opencode/skills/skill-improver/SKILL.md |
| work-unit-commits | user | Plan commits as reviewable work units. Trigger: implementation, commit splitting, chained PRs, or keeping tests and docs with code. | /home/glats/.config/opencode/skills/work-unit-commits/SKILL.md |

## Referenced Convention Files

| File | Type | Referenced Paths |
|---|---|---|
| /home/glats/.nixos/AGENTS.md | Index | hosts/{hostname}/default.nix, modules/profiles/, modules/base/, modules/desktop/, modules/features/, modules/hardware/, modules/networking/, modules/virtualisation/, home-linux/, home-darwin/, shared/, darwin/, lib/, overlays/, pkgs/, bin/, secrets/ |

## Count

20 indexed skills
1 referenced convention file
