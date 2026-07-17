# Tasks: Separate Local Skills from Gentle AI Assets

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~100 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Delivery strategy | ask-on-risk |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

## Phase 1: Package Creation

- [x] 1.1 Create `pkgs/local-ai-assets/default.nix` — `stdenvNoCC.mkDerivation` copying `shared/assets/skills/` → `$out/share/local-ai/skills/`; `dontUnpack = true`, `installPhase` with `cp -r`
- [x] 1.2 Verify: `nix build .#packages.x86_64-linux.local-ai-assets` → output contains `nix-verify/`, `git-feature-flow/`, `opencode-session-recovery/` with `SKILL.md` files

## Phase 2: Gentle AI Assets Refactor

- [x] 2.1 Rename param `extraAssetsShared` → `extraFiles` in `pkgs/gentle-ai-assets/default.nix` (line 6, `optionalString` guard at 71, loop variable at 73, comments at 33-35)
- [x] 2.2 Remove directory branch (lines 75-84) from `extraFiles` loop; keep flat-file branch (lines 86-88) for `review-gate.md` only
- [x] 2.3 Verify: `nix build .#packages.x86_64-linux.gentle-ai-assets` → output has ONLY upstream skills (36 dirs), no local skills leaked; `review-gate.md` present

## Phase 3: Package Wiring

- [x] 3.1 In `lib/packages.nix`: add `local-ai-assets = linuxPkgs.callPackage ../pkgs/local-ai-assets { };` to `linuxPackages`, and same for `darwinPackages`
- [x] 3.2 In `lib/packages.nix`: rename `extraAssetsShared` → `extraFiles` in `sharedOpencodePaths` (line 29), both `inherit` lines (49, 88), and update comment (21)
- [x] 3.3 Verify: `nix flake check --no-build` passes; both `linuxPackages.local-ai-assets` and `darwinPackages.local-ai-assets` resolve

## Phase 4: Consumer Integration

- [x] 4.1 Add `localSkillsSource` option to `shared/gentle-ai-common.nix` — `types.path`, default `"${pkgs.local-ai-assets}/share/local-ai/skills"`, below existing `skillsSource`
- [x] 4.2 Update `shared/opencode.nix` line 152: split skills `dir_pair` into two independent cmp-guarded copy passes (`skillsSource` + `localSkillsSource`), then one union-based orphan cleanup pass that deletes only files absent from BOTH sources
- [x] 4.3 Update `shared/claude-code.nix` line 207: same dual-source + union cleanup pattern for the `skills` dir_pair in the activation script
- [x] 4.4 `git add` all new files (`pkgs/local-ai-assets/`), run `format-nix`, verify `nix flake check --no-build` passes

## Phase 5: End-to-End Verification

- [x] 5.1 Build both packages: `nix build .#packages.x86_64-linux.local-ai-assets` and `nix build .#packages.x86_64-linux.gentle-ai-assets`
- [x] 5.2 Verify `nix flake check --no-build` passes for all hosts
- [x] 5.3 User runs `nixos-build safe` and verifies deployed `~/.config/opencode/skills/` + `~/.claude/skills/` are identical to pre-change state (same union of upstream + local skills)

## Phase 5: End-to-End Verification

- [ ] 5.1 Build both packages: `nix build .#packages.x86_64-linux.local-ai-assets` and `nix build .#packages.x86_64-linux.gentle-ai-assets`
- [ ] 5.2 Verify `nix flake check --no-build` passes for all hosts
- [ ] 5.3 User runs `nixos-build safe` and verifies deployed `~/.config/opencode/skills/` + `~/.claude/skills/` are identical to pre-change state (same union of upstream + local skills)
