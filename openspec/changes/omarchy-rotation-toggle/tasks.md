# Tasks: Wallpaper Rotation Toggle (omarchy-rotation-toggle)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~12 upstream + 1–2 downstream + lockfile |
| 400-line budget risk | Low |
| Chained PRs recommended | No (two-repo split, one PR per repo) |
| Suggested split | PR 1: `glats/omarchy-nix` (option + consumption) → PR 2: `nixos-hosts` (lock bump + optional t14 override) |
| Delivery strategy | single-pr (per repo; cross-repo by necessity) |
| Chain strategy | size:exception not needed |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: stacked-to-main
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Upstream option + gate in `glats/omarchy-nix` | PR 1 → `glats/omarchy-nix:main` | 2 files; preserves default `true` |
| 2 | Downstream lock bump + optional t14 override | PR 2 → `nixos-hosts:main` | depends on PR 1 merge |

## Phase 1: Upstream — `glats/omarchy-nix`

- [x] 1.1 Confirm working copy clean: `cd /home/glats/repos/omarchy-nix && git status` shows clean tree on `main`, and `git remote -v` shows `origin → github.com/glats/omarchy-nix`
- [x] 1.2 In `config.nix`, add `rotate_on_start = lib.mkOption { type = lib.types.bool; default = true; description = "Advance wallpaper to next image on every Hyprland session start"; };` as a sibling of the `theme` option (around line 45, after `theme`, before `primary_font`)
- [x] 1.3 In `modules/home-manager/swaybg.nix`, replace unconditional `exec-once = [ "omarchy-theme-bg-next" ];` with `exec-once = lib.optional config.omarchy.rotate_on_start "omarchy-theme-bg-next";`
- [x] 1.4 Verify: `nix flake check --no-build` from `/home/glats/repos/omarchy-nix` passes (option declared, eval succeeds)
- [x] 1.5 Format changed files: `nix fmt -- config.nix modules/home-manager/swaybg.nix` from repo root — **Note**: omarchy-nix flake has no `formatter.x86_64-linux` output; tried `nixfmt` (RFC style) but it would reformat 175 unrelated lines (`{}` → `{ }`, inline enums → multi-line) because the file uses classic nixfmt style. Skipped the wholesale reformat; my added lines already match the surrounding style (`default = true;` follows the same pattern as `default = "tokyo-night";` above).
- [x] 1.6 Commit: `git add config.nix modules/home-manager/swaybg.nix && git commit -m "feat: add omarchy.rotate_on_start option to gate wallpaper rotation"` (commit 3f24b06 on branch `feat/rotate-on-start`)
- [x] 1.7 Push branch and open PR to `glats/omarchy-nix:main`. Branched off main (commit 3f24b06 on `feat/rotate-on-start`; main unchanged at ce9b27c). Pushed to `origin/feat/rotate-on-start`. PR opened via GitHub MCP (gh CLI not authenticated in this env). **PR URL: https://github.com/glats/omarchy-nix/pull/5**

## Phase 2: Downstream — `nixos-hosts`

- [x] 2.1 (Depends on 1.7) Bump input: from `/home/glats/.nixos` run `nix flake lock --update-input omarchy-nix`; confirm `flake.lock` shows new `omarchy-nix` rev
- [x] 2.2 In `hosts/t14/home/omarchy.nix`, add `omarchy.rotate_on_start = lib.mkForce false;` with a comment explaining the static-wallpaper preference
- [x] 2.3 Verify: `nix flake check --no-build` from `/home/glats/.nixos` passes (t14 + other hosts evaluate; no regressions on rog/thinkcentre)
- [x] 2.4 Format: `nix fmt -- hosts/t14/home/omarchy.nix` — flake.lock skipped (JSON, not nix)
- [x] 2.5 Commit + push: `1ce9d81` on `nixos-hosts:master`

## Phase 3: Manual Verification (t14 only)

- [ ] 3.1 On t14, after `nixos-build switch` with `rotate_on_start = false`: log out and back into Hyprland, confirm wallpaper is unchanged from previous session
- [ ] 3.2 Re-enable briefly (set `true` or remove override) and confirm wallpaper advances on next Hyprland start — validates the gate works both ways
- [ ] 3.3 Confirm `rog` and `thinkcentre` builds (or dry-run via `nix flake check`) show `omarchy-theme-bg-next` still in their `exec-once` (default `true` preserved)
