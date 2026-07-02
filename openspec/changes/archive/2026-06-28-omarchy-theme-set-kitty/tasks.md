# Tasks: omarchy-theme-set-kitty

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~20-30 (1 code + ~12 comment + ~10 spec) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single direct commit on main (project convention: no PRs) |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Restore omarchy-theme-set recoloring on t14 | direct commit on main | 1 commit, no PR per repo convention |

## Phase 1: Code Change

- [x] 1.1 In `home-linux/kitty.nix` line 29, change `settings = lib.mkForce {` → `settings = lib.mkDefault {`. `lib` is already in scope (line 20).

## Phase 2: Comment Update

- [x] 2.1 Rewrite the header comment (lines 1-18) in `home-linux/kitty.nix` to describe the new `mkDefault` merge strategy: rog/thinkcentre unaffected (no omarchy), t14 merges omarchy's `include` + keybindings via attrset union.
- [x] 2.2 Update the inline comment at lines 37-38 (`# Omarchy defaults that must be re-declared inside mkForce or they get dropped on t14.`) to explain these keys are re-declared so nixos-hosts's values win on later-import priority.

## Phase 3: Spec Sync

- [x] 3.1 In `openspec/specs/kitty-consolidation/spec.md`, replace the "Host Uniformity" requirement body with the delta version (rog/thinkcentre byte-identical; t14 MAY merge omarchy defaults).
- [x] 3.2 In the same file, rename the "mkForce Override Pattern" requirement to "mkDefault Override Pattern" and replace its body with the delta text.
- [x] 3.3 In the same file, append the two ADDED requirements from the delta: "Runtime Theme Recoloring on t14" and "Omarchy Merge Acceptance on t14".

## Phase 4: Verification

- [x] 4.1 Run `nix flake check --no-build` from repo root — must exit 0 with no eval errors.
- [x] 4.2 Build t14 home config and grep generated `kitty.conf` for `include ~/.config/omarchy/current/theme/kitty.conf` to confirm omarchy's directive survives merge.
- [x] 4.3 Confirm `programs.kitty.enable` (line 27) and `font.name` (line 84) remain `lib.mkDefault` so t14's `omarchy.fonts.kitty` override path still works.

## Phase 5: Format & Commit

- [x] 5.1 Run `format-nix` (or `nix fmt -- home-linux/kitty.nix openspec/specs/kitty-consolidation/spec.md`) on the two changed files.
- [x] 5.2 Commit with conventional message: `fix(kitty): restore omarchy-theme-set runtime recoloring on t14` — body explains `mkForce` → `mkDefault` restores omarchy's `include` directive via attrset union. (Verified: commit f1714b1 exists)
