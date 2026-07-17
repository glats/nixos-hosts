# Proposal: Separate Local Skills from Gentle AI Assets

## Intent

Local skills (nix-verify, opencode-session-recovery, git-feature-flow) are merged INTO `gentle-ai-assets`' `share/gentle-ai/skills/` alongside upstream skills from gentle-ai-src, caveman-src, and ponytail-src. This conflates upstream vendor assets with locally maintained user skills under one name. Separate into distinct derivations with clear ownership.

## Decisions

1. **Package name**: `local-ai-assets` — mirrors `gentle-ai-assets`/`engram-assets` convention. Confirmed.
2. **Param rename**: `extraAssetsShared` → `extraFiles`. After removing skills-dir handling, it only manages flat files (`review-gate.md`). Reflects narrowed scope.
3. **Sources model**: Two separate options — `home.gentle-ai.skillsSource` (upstream, unchanged) + new `home.gentle-ai.localSkillsSource` (local). Two copy passes + union-based orphan cleanup.

## Scope

### In Scope
- New `local-ai-assets` derivation: `shared/assets/skills/` → `$out/share/local-ai/skills/`
- Rename `extraAssetsShared` → `extraFiles` in `pkgs/gentle-ai-assets/default.nix` + `lib/packages.nix`
- Remove skills-dir merge from `extraFiles` loop; keep `review-gate.md` file copy
- Wire both derivations in `lib/packages.nix` for linux + darwin
- Add `home.gentle-ai.localSkillsSource` to `gentle-ai-common.nix`
- Update `opencode.nix` + `claude-code.nix`: dual-source deploy, union orphan cleanup
- Verify identical deployed files at `~/.config/opencode/skills/`, `~/.claude/skills/`

### Out of Scope
- Openfang sync, `review-gate.md` paths, `extraCommands`, `extraAssets`, `shared/opencode/assets/`
- No runtime change — same files land in same places

## Capabilities

### New
- `local-ai-assets-package`: Derivation for locally maintained skills

### Modified
- `gentle-ai-asset-overlay`: Param renamed `extraAssetsShared` → `extraFiles`; no dir merging
- `skill-deployment`: Dual-source merge + union cleanup; new `localSkillsSource` option

## Approach

1. Create `pkgs/local-ai-assets/default.nix` — copies skills → `$out/share/local-ai/skills/`
2. Rename param in `default.nix` + `lib/packages.nix`
3. Remove dir branch from `extraFiles` loop (lines 75-84); keep file copy for `review-gate.md`
4. Wire `local-ai-assets` into `linuxPackages` + `darwinPackages`
5. Add `localSkillsSource` option in `gentle-ai-common.nix`
6. Split skills dir_pair: two copy passes (no per-source cleanup) + union cleanup pass

## Affected Areas

| Area | Impact |
|------|--------|
| `pkgs/local-ai-assets/default.nix` | New |
| `pkgs/gentle-ai-assets/default.nix` | Modified — rename, remove skills merge |
| `lib/packages.nix` | Modified — add derivation, rename attr |
| `shared/gentle-ai-common.nix` | Modified — new option |
| `shared/opencode.nix` | Modified — dual-source deploy |
| `shared/claude-code.nix` | Modified — dual-source deploy |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Per-source orphan cleanup deletes other source's skills | High | Single union-based cleanup pass |
| `review-gate.md` regression | Low | Only dir handling removed |
| mact2 build breakage | Low | `stdenvNoCC` cross-platform; explicit darwin registration |

## Rollback

`git revert`. No data mutation. `nixos-build switch` restores previous behavior.

## Success Criteria

- [ ] `nix flake check --no-build` passes for all hosts
- [ ] `nix build .#packages.x86_64-linux.local-ai-assets` → 3 local skill dirs in output
- [ ] `nix build .#packages.x86_64-linux.gentle-ai-assets` → ONLY upstream skills
- [ ] Deployed skills dirs = union of upstream + local, identical to current state
