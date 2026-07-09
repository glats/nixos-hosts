# Archive Report: gentle-ai-opencode-skill-separation

**Archived**: 2026-07-09
**Artifact Store**: Hybrid (Engram + openspec)
**Observation IDs**: 1733 (explore), 1734 (proposal), 1735 (spec), 1736 (design), 1737 (tasks), 1738 (apply), 1741 (verify), 1740 (review)

## Change Summary

Brought the unmanaged `sdd-review-policy.md` (115 lines) into the Nix pipeline via the existing extraAssets overlay mechanism, documented the complete upstream/local asset boundary in `AGENTS.md`, and added a sed no-op warning to detect upstream format changes.

## What Was Done

| Phase | Artifact | Status |
|-------|----------|--------|
| Explore | Pipeline diagram, inventory (11 assets), 6 risks, 42-line local additions documented | Complete |
| Propose | 4 changes: extraAssets, home.file+activation, boundary docs, sed validation | Complete |
| Spec | 4 delta specs (gentle-ai-asset-overlay, skill-deployment, review-gates, sed-validation), 5 requirements, 14 scenarios | Complete |
| Design | 3 arch decisions, exact code insertions for all 3 files, deployment order, testing strategy | Complete |
| Tasks | 6 tasks, sequential apply order, ~148 estimated lines | Complete |
| Apply | All 6 tasks implemented: 3 files changed (~146 lines) | Complete |
| Verify | All 14 scenarios PASS, format-nix clean, nix flake check OK | PASS WITH WARNINGS (W1: unstaged, W2: not deployed on verify host) |
| Review | Single slice review: verdict "done", rework level "none" | Complete |
| Deploy | Built and switched on rog host | Complete |

## Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Source file transport | extraAssets overlay (mirrors sdd-orchestrator.md pattern) | Single transport mechanism for both root `opencode/` overrides |
| Boundary docs location | Repo `AGENTS.md` (new section) | Agent-facing project doc; inventory belongs with structure docs |
| Sed warning mechanism | `elif [ -f ... ]` branch emitting to stderr | Distinguishes file-missing from marker-missing (two distinct conditions) |

## Risks Resolved

| Risk | Resolution |
|------|------------|
| sdd-review-policy.md unmanaged | Now Nix-managed via extraAssets + home.file + activation loop |
| Sed patch silent no-op | `elif` branch emits warning to stderr when marker missing but file exists |
| Asset boundary opaque | New "Gentle AI Asset Boundary" section in AGENTS.md documents all 10+ assets with origin/transport |

## Files Changed

| File | Action | Lines | Purpose |
|------|--------|-------|---------|
| `shared/opencode/assets/opencode/sdd-review-policy.md` | Create | +115 | Source file in extraAssets tree |
| `shared/opencode.nix` | Modify | +8/-1 | home.file entry, activation loop, sed elif warning |
| `AGENTS.md` | Modify | +23 | Asset boundary documentation (inventory, override mechanism, policy/mechanism pair) |

## Specs Synced

| Domain | Action | Details |
|--------|--------|---------|
| gentle-ai-asset-overlay | Updated | +2 requirements (Asset Registration, Inventory Completeness) |
| skill-deployment | Updated | +1 requirement (sdd-review-policy.md Deployment) |
| review-gates | Updated | +1 requirement (RP-007: Policy File Source) |
| sed-validation | Created | New main spec (35 lines, 4 scenarios) |

## Deployment Status

- **Built and switched**: rog host (`nixos-build switch`)
- **nix flake check**: All hosts pass
- **Staged**: Files exist on disk but not git-committed (requires `git add` + commit)

## SDD Cycle Complete

The change has been fully planned, implemented, verified, deployed, and archived.
Ready for the next change.
