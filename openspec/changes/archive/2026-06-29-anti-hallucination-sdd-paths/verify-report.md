# Verification Report: anti-hallucination-sdd-paths

**Status**: PASS
**Date**: 2026-06-29
**Verification mode**: Full (specs + tasks + runtime evidence)
**Persistence**: hybrid (Engram + openspec)

## Executive Summary

All 5 requirements and 8 scenarios PASS. The `extraAssets` derivation parameter is correctly implemented with `lib.optionalString` guarding (matching the `extraCommands` pattern). Both linux and darwin platforms receive the same `extraAssets` path via `sharedOpencodePaths`. Three override files exist in `shared/opencode/assets/` with `Filesystem path convention` notes in the correct insertion points. The orchestrator source has been switched from vanilla to layered assets. Non-overridden files pass through unchanged — confirmed on `sdd-tasks`, `sdd-design`, and `sdd-apply`. `nix flake check --no-build` passes. Deployment to `~/.config/opencode/` is confirmed with `grep -c` returning 1 for all 3 overridden files and 0 for non-overridden files.

## Verification Results

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| R1 | `extraAssets` derivation parameter | PASS | `pkgs/gentle-ai-assets/default.nix:6`: `extraAssets ? null`; lines 62-73: `lib.optionalString (extraAssets != null)` conditional block with `cp -r ${extraAssets}/. $TEMP_DIR/` |
| R2 | `sharedOpencodePaths` wiring | PASS | `lib/packages.nix:27`: `extraAssets = ./../shared/opencode/assets`; line 42: `inherit (sharedOpencodePaths) extraSkills extraAssets` (linux); line 72: same for darwin |
| R3 | Anti-hallucination override files (3 files) | PASS | `shared/opencode/assets/opencode/sdd-orchestrator.md` (32137B), `skills/sdd-explore/SKILL.md` (5648B), `skills/sdd-init/SKILL.md` (4413B) — all contain `Filesystem path convention` note |
| R4 | Orchestrator source switch | PASS | `shared/opencode.nix:99`: `${pkgs.gentle-ai-assets}` (was `-vanilla`); `grep -c` returns 1 for all 3 deployed files |
| R5 | Vanilla drift safety | PASS | Non-overridden files (`sdd-tasks`, `sdd-design`, `sdd-apply`) have 0 `Filesystem path convention` matches — pass through from vanilla unchanged |

## Scenario Compliance Matrix

| Scenario | Status | Evidence |
|----------|--------|----------|
| extraAssets provided with override files | PASS | Deployed `sdd-orchestrator.md` has convention note; build picks up `extraAssets` via `cp -r` |
| extraAssets is null (no-op) | PASS | `lib.optionalString` guard: null → no copy block executed; default is `null` |
| extraAssets contains nested skill overrides | PASS | `skills/sdd-explore/SKILL.md` deployed with note; all other skill files vanilla (confirmed on 3 non-overridden skills) |
| Both platforms receive extraAssets | PASS | Same `inherit (sharedOpencodePaths) extraSkills extraAssets` in both `linuxPackages` and `darwinPackages` |
| Override files contain anti-hallucination note | PASS | All 3 files contain "Filesystem path convention" mentioning `sdd/` = Engram keys, `openspec/` = canonical FS path |
| Activated system uses layered asset | PASS | `grep -c` returns 1 for all 3 deployed files at `~/.config/opencode/` |
| Flake update does not regress overrides | PASS | Override files are independent copies in `shared/opencode/assets/`; upstream changes don't touch them |
| Upstream changes non-overridden file | PASS | Non-overridden skills have 0 convention matches; `cp -r vanilla` runs first, then overlay applies — non-overridden files reflect vanilla |

## Build & Test Evidence

| Check | Result |
|-------|--------|
| `nix flake check --no-build` | PASS — all checks passed (rog, thinkcentre, t14) |
| `grep -c "Filesystem path convention" ~/.config/opencode/sdd-orchestrator.md` | 1 |
| `grep -c "Filesystem path convention" ~/.config/opencode/skills/sdd-explore/SKILL.md` | 1 |
| `grep -c "Filesystem path convention" ~/.config/opencode/skills/sdd-init/SKILL.md` | 1 |
| `grep -c "Filesystem path convention" ~/.config/opencode/skills/sdd-tasks/SKILL.md` | 0 (vanilla pass-through) |
| `grep -c "Filesystem path convention" ~/.config/opencode/skills/sdd-design/SKILL.md` | 0 (vanilla pass-through) |
| `grep -c "Filesystem path convention" ~/.config/opencode/skills/sdd-apply/SKILL.md` | 0 (vanilla pass-through) |
| Git commits | 3 commits: `ed71fed` (format), `61f2a41` (Phase 1: foundation), `41e99fa` (Phase 2: overrides + source switch) |

## Tasks Completion

| Phase/Task | Status |
|------------|--------|
| **Phase 1: Packaging Foundation** | |
| 1.1 `extraAssets` param + copy block | ✅ Implemented |
| 1.2 `sharedOpencodePaths` wiring | ✅ Implemented |
| 1.3 Validate `nix flake check` + build | ✅ Passed |
| 1.4 `format-nix` | ✅ Done (commit `ed71fed`) |
| **Phase 2: Override + Source Switch** | |
| 2.1 Copy 3 vanilla files from nix store | ✅ Done |
| 2.2 Append convention note to sdd-orchestrator.md | ✅ Done (after Artifact Store Policy) |
| 2.3 Append convention note to sdd-explore/SKILL.md | ✅ Done (after Retrieving Context) |
| 2.4 Append convention note to sdd-init/SKILL.md | ✅ Done (after Hard Rules) |
| 2.5 Switch orchestrator source to layered | ✅ Done (`shared/opencode.nix:99`) |
| 2.6 Validate build + grep check | ✅ Passed |
| 2.7 `nixos-build dry` + switch | ✅ Done (user executed switch) |
| 2.8 Post-switch grep check | ✅ 1,1,1 matches |
| **Phase 3: Upstream PR** | 🔲 Not yet (non-blocking for this change) |

## Design Coherence

No design deviations detected. Implementation follows the design exactly:
- `extraAssets` uses same `lib.optionalString` pattern as `extraCommands` (design rationale: consistency)
- Override files are full vanilla copies + appended note (design rationale: diffable, reviewable)
- Directory structure mirrors `$out/share/gentle-ai/` (design rationale: predictable overlay behavior)
- Wording uses "Filesystem path convention" per user feedback (not "Anti-hallucination")

## Risks & Notes

- **None critical**. All requirements pass with runtime evidence.
- **Phase 3** (upstream PR to `Gentleman-Programming/gentle-ai`) is non-blocking and tracked separately.
- **Flake update regeneration**: On `nix flake update`, if upstream vanilla files change, the override files in `shared/opencode/assets/` will need manual re-generation (copy new vanilla + re-apply convention note). The git commit message on `41e99fa` documents the procedure.

## Skill Resolution

The `nix-verify` skill was loaded and used for reading Nix files. No MCP Nix queries were needed — this is a local derivation addition with no external package lookups. All verification was done via source inspection + runtime grep evidence + `nix flake check`.

## Verdict

**PASS** — Ready for archive.
