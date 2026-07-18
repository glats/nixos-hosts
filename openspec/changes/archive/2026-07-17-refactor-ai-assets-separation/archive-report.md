# Archive Report: Refactor AI assets separation — independent skill sources

**Change**: `refactor-ai-assets-separation`
**Archived at**: 2026-07-17
**Artifact store**: hybrid (engram + openspec)
**Archive path**: `openspec/changes/archive/2026-07-17-refactor-ai-assets-separation/`
**Archive type**: standard (no warnings, all tasks complete)

## SDD Cycle Summary

| Phase | Status | Engram Obs ID |
|-------|--------|---------------|
| Explore | done | #1839 |
| Propose | done | #1840 |
| Design | done | #1841 |
| Tasks | done | #1842 |
| Apply | done | #1843 |
| Verify | done | #1844 |
| Archive | done | (this report) |

## Intent

Split the monolithic `gentle-ai-assets-vanilla` → `gentle-ai-assets` derivation chain into independent per-source derivations. Each upstream source (gentle-ai, caveman, ponytail) now produces its own build artifact. Activation scripts consume N-way source lists for skills, commands, and AGENTS.md/CLAUDE.md concatenation.

## Task Completion

| Metric | Value |
|--------|-------|
| Tasks total | 18 |
| Tasks complete | 18 |
| Tasks incomplete | 0 |
| Completion rate | 100% |

All 18 tasks verified complete with no unchecked items.

## Verdict

**PASS WITH WARNINGS**

- **CRITICAL**: None
- **WARNING**: DESIGN-DEV-01 — `commandSources` implemented as per-tool local let-bindings instead of shared mkOption. Functionally correct, structurally deviated from design.
- All builds pass (`nix flake check --no-build`, 3 package builds, 1 host build)
- Both activation scripts execute successfully
- All stale references cleaned (`grep -r 'gentle-ai-assets-vanilla\|home\.gentle-ai'` returns empty)

## Specs Synced

No delta specs existed for this change, and no `openspec/specs/` directory exists. No spec merge was performed. The design document served as the specification.

## Archive Contents

| Artifact | Path |
|----------|------|
| Exploration | `openspec/changes/archive/2026-07-17-refactor-ai-assets-separation/exploration.md` |
| Proposal | `openspec/changes/archive/2026-07-17-refactor-ai-assets-separation/proposal.md` |
| Design | `openspec/changes/archive/2026-07-17-refactor-ai-assets-separation/design.md` |
| Tasks | `openspec/changes/archive/2026-07-17-refactor-ai-assets-separation/tasks.md` |
| Verify Report | `openspec/changes/archive/2026-07-17-refactor-ai-assets-separation/verify-report.md` |
| Archive Report | `openspec/changes/archive/2026-07-17-refactor-ai-assets-separation/archive-report.md` |

## Changes Delivered

The following structural changes were implemented:

1. **New derivations**: `pkgs/caveman-assets/default.nix` and `pkgs/ponytail-assets/default.nix` created
2. **Rewritten derivation**: `pkgs/gentle-ai-assets/default.nix` now pure gentle-ai-src only
3. **Deleted**: `pkgs/gentle-ai-assets/vanilla.nix` (no more layered chain)
4. **Renamed**: `shared/gentle-ai-common.nix` → `shared/ai-assets.nix` with namespace `home.gentle-ai` → `home.ai-assets`
5. **New HM options**: `skillSources` (list of paths), `commandSources` (list of strings), `agentsMdSources` (list of paths)
6. **N-way activation**: Both opencode.nix and claude-code.nix use N-way bash loops for skills/commands union and AGENTS.md/CLAUDE.md concat
7. **Cleanup**: Deleted `shared/assets/review-gate.md` (18-line redundant), `shared/opencode/assets/skills/.gitkeep`, removed `extraAssets`/`extraFiles` plumbing
8. **Local overrides**: review-gate.md now referenced directly via `./shared/opencode/assets/opencode/review-gate.md` in `home.file`

## Known Design Deviation

- **DESIGN-DEV-01**: The design specified `commandSources` as a shared `mkOption` in `shared/ai-assets.nix`. Implementation uses per-tool local let-bindings instead to avoid cross-tool option priority conflicts. Functionally equivalent, structurally simpler. No action required.

## SDD Cycle Complete

This change has been fully planned, implemented, verified, and archived. Ready for the next change.
