# Proposal: Remove SDD Skill Overrides — Use Upstream gentle-ai

## Intent

Remove 8 local SDD skill overrides from `shared/opencode/assets/skills/` that duplicate upstream gentle-ai. Commit 562e36f added these files, but the project philosophy is **everything from upstream, no local drift**. Keeping them risks regression: when PR [#988](https://github.com/Gentleman-Programming/gentle-ai/pull/988) merges (compressed SDD skills, ~70% smaller), the local verbose copies would **overwrite** the newer compressed upstream versions via the `cp -r` layering in `pkgs/gentle-ai-assets/default.nix:68`.

## Scope

### In Scope
- Delete all 8 skill directories: `sdd-apply`, `sdd-archive`, `sdd-design`, `sdd-explore`, `sdd-init`, `sdd-propose`, `sdd-spec`, `sdd-tasks`
- Keep `shared/opencode/assets/opencode/sdd-orchestrator.md` (intentional user override)
- Keep `shared/opencode/assets/skills/.gitkeep`

### Out of Scope
- Changes to `pkgs/gentle-ai-assets/default.nix`, `lib/packages.nix`, or `flake.nix` (the `extraAssets` mechanism stays for sdd-orchestrator.md)
- Flake lock update (PR #988 merge + `nix flake update` — separate change)
- Updating `shared/opencode/assets/opencode/sdd-orchestrator.md` to merge upstream improvements from PR #988

## Capabilities

### New Capabilities
None — pure cleanup, no new behavior.

### Modified Capabilities
None — no spec-level behavior changes.

## Approach

1. Run `format-nix` to ensure clean state
2. Delete `shared/opencode/assets/skills/sdd-*/` directories (8 total) via `rm -rf`
3. Verify `shared/opencode/assets/skills/` contains only `.gitkeep`
4. Run `nix flake check --no-build` to confirm no breakage
5. Commit with message: `fix(assets): remove 8 redundant SDD skill overrides`

The `extraAssets` layering at `pkgs/gentle-ai-assets/default.nix:62-73` copies whatever exists under `shared/opencode/assets/` on top of vanilla skills. After removal, only `opencode/sdd-orchestrator.md` gets layered — SDD skills come solely from upstream gentle-ai-src.

## Files Changed

| File | Action | Est. Δ |
|------|--------|--------|
| `shared/opencode/assets/skills/sdd-apply/SKILL.md` | Delete | -313 lines |
| `shared/opencode/assets/skills/sdd-archive/SKILL.md` | Delete | -207 lines |
| `shared/opencode/assets/skills/sdd-design/SKILL.md` | Delete | -185 lines |
| `shared/opencode/assets/skills/sdd-explore/SKILL.md` | Delete | -151 lines |
| `shared/opencode/assets/skills/sdd-init/SKILL.md` | Delete | -78 lines |
| `shared/opencode/assets/skills/sdd-propose/SKILL.md` | Delete | -206 lines |
| `shared/opencode/assets/skills/sdd-spec/SKILL.md` | Delete | -255 lines |
| `shared/opencode/assets/skills/sdd-tasks/SKILL.md` | Delete | -255 lines |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Temporary loss of path convention fix in `sdd-explore`/`sdd-init` (filesystem disambiguation note for Engram `sdd/` topic keys) — gone until PR #988 merges | Low | Upstream files work correctly without the note; impact is cosmetic and rare |
| `sdd-orchestrator.md` overwrites upstream improvements when PR #988 merges + flake update | Med | Manual merge needed later — add comment in orchestrator file noting the override |
| Extra files inadvertently deleted with wildcard | Low | Use explicit `rm -rf` per directory, not glob, and verify afterward |

## Rollback Plan

`git revert` the removal commit. The 8 skill directories and their SKILL.md files are tracked in git — reverting restores them exactly.

## Dependencies

None. PR #988 merge and flake lock update are a separate follow-up change, not a prerequisite.

## Success Criteria

- [ ] `ls shared/opencode/assets/skills/` shows only `.gitkeep`
- [ ] `nix flake check --no-build` passes with zero errors
- [ ] `ls ~/.config/opencode/skills/sdd-*` still exists (served from gentle-ai-assets package, not local overrides)
- [ ] `git log -1 --stat` shows 8 deletions, no added files, no modified nix files
