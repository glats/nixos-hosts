# Tasks: t14 Waybar Keyboard Layout Indicator

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~10 (8 waybar + 2 flake.lock) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | 2 commits in 2 repos (cannot be one PR) |
| Delivery strategy | exception-ok (direct commits on main) |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Add `custom/language` module to omarchy-nix waybar config | Direct commit on main (owned repo) | Repo: `glats/omarchy-nix` |
| 2 | Bump `omarchy-nix` flake pin in nixos-hosts | Direct commit on main | Repo: `nixos-hosts`; depends on unit 1 merge |

## Phase 1: omarchy-nix Waybar Config (repo: glats/omarchy-nix)

- [x] 1.1 Open `~/repos/omarchy-nix/config/waybar/config` and add `"custom/language"` to `modules-right` array (line 15, before `"cpu"`)
- [x] 1.2 Add module config block to same file: `exec`, `interval: 5`, `on-click`, `format: "{} "`, `tooltip: true` (use design.md interface contract)
- [x] 1.3 Validate JSON syntax with `python3 -m json.tool < config/waybar/config` (or `jq .`); must round-trip without error
- [x] 1.4 Commit on `main`: `feat(waybar): add custom/language module for keyboard layout indicator`
- [x] 1.5 Push to `github:glats/omarchy-nix/main`

## Phase 2: nixos-hosts Flake Pin Bump (repo: nixos-hosts)

- [x] 2.1 Confirm Phase 1 commit is visible on `github:glats/omarchy-nix/main` (the `omarchy-nix` input tracks `main`)
- [x] 2.2 Run `nix flake lock --update-input omarchy-nix` in `/home/glats/.nixos`; verify `flake.lock` shows the new `omarchy-nix` revision
- [x] 2.3 Run `nix flake check --no-build` to validate the lock bump
- [x] 2.4 Commit on `main`: `flake.lock: bump omarchy-nix (add custom/language waybar module)`

## Phase 3: Verification on t14 (user-driven, manual)

- [ ] 3.1 User runs `nixos-build` on t14 (per AGENTS.md: ask before `switch`; builds take long)
- [ ] 3.2 Visual: confirm `custom/language` widget appears in waybar right group showing `es` or `latam`
- [ ] 3.3 Click widget: layout toggles, bar updates within 5s (spec: Click-to-Toggle scenarios)
- [ ] 3.4 Press Alt+Shift externally: bar updates within 5s (spec: Display updates after external layout change)
- [ ] 3.5 Hover widget: tooltip shows layout name (spec: Tooltip Display)
- [ ] 3.6 Verify no regression: cpu, battery, network, bluetooth, pulseaudio, clock, tray all render correctly (spec: No Regression)

## Rollback

- Revert Phase 1 commit in `omarchy-nix` + re-run Phase 2 lock bump
- Or revert Phase 2 commit to restore previous `omarchy-nix` pin
- Run `nixos-build` on t14 — waybar redeploys without module
