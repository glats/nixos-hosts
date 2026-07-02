# Proposal: anti-hallucination-sdd-paths

## Intent

SDD sub-agents hallucinate `.sdd/`, `sdd/`, `sdds/` as filesystem paths when the canonical path is `openspec/`. Root cause: Engram topic keys use `sdd/{change-name}/{artifact}` and the model conflates the key prefix with filesystem globs. Prior fix (local patches to `~/.config/opencode/skills/sdd-{explore,init}/SKILL.md`) is fragile — it regresses on every `nixos-build switch` because the activation script overwrites from vanilla nix store. `sdd-orchestrator.md` (the primary trigger, containing the Engram-key table at lines 384-391) is unpatched and unreachable by the current overlay mechanism.

## Scope

### In Scope
- **Track 1 (Local)**: Add `extraAssets` parameter to `pkgs/gentle-ai-assets/default.nix`; wire it in `lib/packages.nix`; create 3 override files in `shared/opencode/assets/`; switch `shared/opencode.nix:100` to source from layered asset
- **Track 2 (Upstream)**: PR the same 3 file patches + optional `_shared/sdd-phase-common.md` and Windsurf workflow fix to `Gentleman-Programming/gentle-ai`; bump `gentle-ai-src` flake input after merge

### Out of Scope
- Renaming Engram topic prefix `sdd/` (too invasive, deferred)
- Windsurf `.sdd/` references in local override (Windsurf not used locally; mention in upstream PR only)
- Deprecating `extraCommands` (keep separate from `extraAssets` for clarity)

## Capabilities

### New Capabilities
- `gentle-ai-asset-overlay`: Generic `extraAssets` mechanism in `gentle-ai-assets` derivation that layers arbitrary file overrides on top of vanilla assets (generalises beyond `extraSkills`/`extraCommands`)

### Modified Capabilities
None

## Approach

**Track 1 — Local Nix override:**
1. Add `extraAssets ? null` to `pkgs/gentle-ai-assets/default.nix`; recursive copy `${extraAssets}/. $out/share/gentle-ai/` after vanilla copy
2. Add `extraAssets = ./../shared/opencode/assets` to `sharedOpencodePaths` in `lib/packages.nix`; pass to both linux/darwin `gentle-ai-assets`
3. Create `shared/opencode/assets/opencode/sdd-orchestrator.md` (vanilla + anti-hallucination note in "Artifact Store Policy" section)
4. Create `shared/opencode/assets/skills/sdd-{explore,init}/SKILL.md` (vanilla + anti-hallucination note)
5. Change `shared/opencode.nix:100` from `gentle-ai-assets-vanilla` to `gentle-ai-assets`
6. Validate: `nix flake check --no-build`, `nixos-build dry`

**Track 2 — Upstream PR:**
1. Patch `internal/assets/opencode/sdd-orchestrator.md`, `skills/sdd-{explore,init}/SKILL.md`, optionally `_shared/sdd-phase-common.md` and `windsurf/workflows/sdd-new.md`
2. Bump `gentle-ai-src` flake input after merge

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `pkgs/gentle-ai-assets/default.nix` | Modified | Add `extraAssets` parameter and recursive overlay logic |
| `lib/packages.nix` | Modified | Wire `extraAssets` in `sharedOpencodePaths`, pass to both platforms |
| `shared/opencode/assets/` | New | Directory with 3 override files (orchestrator + 2 skills) |
| `shared/opencode.nix:100` | Modified | Source `sdd-orchestrator.md` from layered asset, not vanilla |
| Upstream `Gentleman-Programming/gentle-ai` | Modified (PR) | Same anti-hallucination notes in 3-5 files |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Vanilla drift on `nix flake update` — local overrides carry stale logic | Medium | Document regeneration procedure; diff against `gentle-ai-assets-vanilla` |
| `extraAssets` recursive copy overwrites unintended files | Low | Convention: `shared/opencode/assets/` mirrors `$out/share/gentle-ai/` structure exactly |
| Upstream PR rejected or stalled | Medium | Local override is self-contained and durable; upstream is parallel track |

## Rollback Plan

1. Remove `extraAssets` from `sharedOpencodePaths` in `lib/packages.nix`
2. Revert `shared/opencode.nix:100` to source from `gentle-ai-assets-vanilla`
3. Delete `shared/opencode/assets/` directory
4. Revert `pkgs/gentle-ai-assets/default.nix` to remove `extraAssets` parameter
5. `nixos-build switch` restores vanilla behavior

## Dependencies

- Upstream PR to `Gentleman-Programming/gentle-ai` (parallel, not blocking)
- After upstream merge: bump `gentle-ai-src` flake input and drop local overrides

## Success Criteria

- [ ] `nix flake check --no-build` passes
- [ ] `nixos-build dry` succeeds
- [ ] After switch, `grep -c "Filesystem path convention" ~/.config/opencode/{sdd-orchestrator.md,skills/sdd-explore/SKILL.md,skills/sdd-init/SKILL.md}` returns ≥1 for each
- [ ] Filesystem path convention notes survive `nixos-build switch` (no regression from vanilla)
- [ ] Upstream PR opened with same patches
