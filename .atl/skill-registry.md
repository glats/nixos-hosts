# Skill Registry — nixos-hosts

**Generated**: 2026-07-17
**Project**: nixos-hosts (NixOS multi-host Flakes configuration)
**Registry maintainer**: sdd-init (re-initialized)

## Convention Files

- AGENTS.md — primary project conventions (path: /home/glats/.nixos/AGENTS.md)
- flake.nix — flake structure single source of truth

## Skills (28 indexed)

| # | Name | Trigger | Scope | Path |
|---|------|---------|-------|------|
| 1 | audit-providers-models | revisar modelos, auditar providers, modelos opencode, update models, providers base, model fit, check models, model audit | project | /home/glats/.nixos/shared/assets/skills/audit-providers-models/SKILL.md |
| 2 | branch-pr | creating, opening, or preparing PRs for review | user | /home/glats/.config/opencode/skills/branch-pr/SKILL.md |
| 3 | caveman | caveman mode, talk like caveman, use caveman, less tokens, be brief, /caveman | user | /home/glats/.config/opencode/skills/caveman/SKILL.md |
| 4 | caveman-commit | write a commit, commit message, generate commit, /commit, /caveman-commit | user | /home/glats/.config/opencode/skills/caveman-commit/SKILL.md |
| 5 | caveman-compress | /caveman-compress FILEPATH, compress memory file | user | /home/glats/.config/opencode/skills/caveman-compress/SKILL.md |
| 6 | caveman-help | /caveman-help, caveman help, what caveman commands, how do I use caveman | user | /home/glats/.config/opencode/skills/caveman-help/SKILL.md |
| 7 | caveman-review | review this PR, code review, review the diff, /review, /caveman-review | user | /home/glats/.config/opencode/skills/caveman-review/SKILL.md |
| 8 | caveman-stats | /caveman-stats | user | /home/glats/.config/opencode/skills/caveman-stats/SKILL.md |
| 9 | cavecrew | delegate to subagent, use cavecrew, spawn investigator/builder/reviewer, save context, compressed agent output | user | /home/glats/.config/opencode/skills/cavecrew/SKILL.md |
| 10 | chained-pr | PRs over 400 lines, stacked PRs, review slices | user | /home/glats/.config/opencode/skills/chained-pr/SKILL.md |
| 11 | cognitive-doc-design | writing guides, READMEs, RFCs, onboarding, architecture, or review-facing docs | user | /home/glats/.config/opencode/skills/cognitive-doc-design/SKILL.md |
| 12 | comment-writer | PR feedback, issue replies, reviews, Slack messages, or GitHub comments | user | /home/glats/.config/opencode/skills/comment-writer/SKILL.md |
| 13 | git-feature-flow | PR conflict, conflicto en PR, merge conflict, conflicted GitHub pull request, git feature flow, feature branch, promote to develop/uat/main, integration branch | project | /home/glats/.nixos/shared/assets/skills/git-feature-flow/SKILL.md |
| 14 | go-testing | Go tests, go test coverage, Bubbletea teatest, golden files | user | /home/glats/.config/opencode/skills/go-testing/SKILL.md |
| 15 | hermes-ephemeral-delegation | broad exploration, multi-file reads, tests/builds, fresh review, or multi-step debug | user | /home/glats/.config/opencode/skills/hermes-ephemeral-delegation/SKILL.md |
| 16 | issue-creation | creating GitHub issues, bug reports, or feature requests | user | /home/glats/.config/opencode/skills/issue-creation/SKILL.md |
| 17 | judgment-day | judgment day, dual review, adversarial review, juzgar | user | /home/glats/.config/opencode/skills/judgment-day/SKILL.md |
| 18 | nix-verify | editing .nix files — adding packages, configuring services, searching options, looking up Nix lib functions | project | /home/glats/.nixos/shared/assets/skills/nix-verify/SKILL.md |
| 19 | opencode-session-recovery | sessions missing from opencode session list, project_id mismatch | project | /home/glats/.nixos/shared/assets/skills/opencode-session-recovery/SKILL.md |
| 20 | ponytail | be lazy, lazy mode, simplest solution, minimal solution, yagni, do less, shortest path, /ponytail | user | /home/glats/.config/opencode/skills/ponytail/SKILL.md |
| 21 | ponytail-audit | audit this codebase, audit for over-engineering, what can I delete, find bloat, /ponytail-audit | user | /home/glats/.config/opencode/skills/ponytail-audit/SKILL.md |
| 22 | ponytail-debt | ponytail debt, /ponytail-debt, what did ponytail defer, list the shortcuts, ponytail ledger | user | /home/glats/.config/opencode/skills/ponytail-debt/SKILL.md |
| 23 | ponytail-gain | /ponytail-gain, ponytail gain, what does ponytail save, show ponytail impact, ponytail scoreboard | user | /home/glats/.config/opencode/skills/ponytail-gain/SKILL.md |
| 24 | ponytail-help | /ponytail-help, ponytail help, what ponytail commands, how do I use ponytail | user | /home/glats/.config/opencode/skills/ponytail-help/SKILL.md |
| 25 | ponytail-review | review for over-engineering, what can we delete, is this over-engineered, simplify review, /ponytail-review | user | /home/glats/.config/opencode/skills/ponytail-review/SKILL.md |
| 26 | skill-creator | new skills, agent instructions, documenting AI usage patterns | user | /home/glats/.config/opencode/skills/skill-creator/SKILL.md |
| 27 | skill-improver | improve skills, audit skills, refactor skills, skill quality | user | /home/glats/.config/opencode/skills/skill-improver/SKILL.md |
| 28 | work-unit-commits | implementation, commit splitting, chained PRs, keeping tests and docs with code | user | /home/glats/.config/opencode/skills/work-unit-commits/SKILL.md |

## Excluded Skills

Skills from scan that are excluded by convention: `sdd-*` (9 skills), `_shared`, `skill-registry`.

## Notes

- Project-level skills (scope=project) shadow user-level skills with the same name
- `.atl/skill-registry.md` is the index — subagents read the actual SKILL.md for full instructions
- SDD skills (sdd-init, sdd-explore, sdd-propose, sdd-spec, sdd-design, sdd-tasks, sdd-apply, sdd-verify, sdd-archive) excluded per sdd-init convention
- `customize-opencode` skill is a built-in, not in user/project skills directory
