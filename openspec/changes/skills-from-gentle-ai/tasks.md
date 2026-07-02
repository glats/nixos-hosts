# Tasks: Remove SDD Skill Overrides — Use Upstream gentle-ai

## Review Workload Forecast

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: single-pr
400-line budget risk: Low

| Field | Value |
|-------|-------|
| Estimated changed lines | 0 added, 1650 deleted |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |

**Rationale**: Pure deletion — no code additions, no build changes, no cross-module integration. The 1650 deleted lines are 8 SKILL.md files; cognitive review load is trivial (reviewer confirms the file list is correct). A single commit suffices.

## Phase 1: Cleanup

- [x] 1.1 Run `format-nix` to ensure clean tree state before edits
- [x] 1.2 Delete 8 directories: `rm -rf shared/opencode/assets/skills/sdd-{apply,archive,design,explore,init,propose,spec,tasks}`

## Phase 2: Verification

- [x] 2.1 Verify `ls shared/opencode/assets/skills/` shows only `.gitkeep`
- [x] 2.2 Run `nix flake check --no-build` — must exit 0
- [x] 2.3 Build toplevel for one host (e.g. `nix build .#nixosConfigurations.rog.config.system.build.toplevel --no-link`) or run `nixos-build dry` to confirm the gentle-ai-assets derivation succeeds without the removed files
- [ ] 2.4 Stage and commit: ~~`git add -A && git commit -m "fix(assets): remove 8 redundant SDD skill overrides"`~~ **Deferred — user requested no commit before review**

## Verification Details

- **Task 2.3 rationale**: `gentle-ai-assets` derivation uses `cp -r` over `shared/opencode/assets/` — if any path reference broke, the build would fail. A toplevel build (or even `nix build .#gentle-ai-assets --no-link`) proves the package still composes correctly.
- **Acceptance criteria**: After deployment, `ls ~/.config/opencode/skills/sdd-*` must still show files (now served from upstream gentle-ai-src, not local overrides).
