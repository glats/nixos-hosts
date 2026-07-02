# Apply: t14 Waybar Keyboard Layout Indicator

**Change**: t14-waybar-keyboard-layout-indicator
**Mode**: hybrid (Engram + openspec)
**Delivery**: direct-commits-on-main (size-exception)
**Date**: 2026-06-28
**Agent**: sdd-apply (model: opencode-go/minimax-m3)

## Goal

Add a `custom/language` waybar module to the omarchy-nix waybar config that
displays the current XKB layout (`es` / `latam`) and toggles on click. Then
bump the `omarchy-nix` flake pin in nixos-hosts so t14 deploys the new config.

## Completed Tasks

### Phase 1 — omarchy-nix waybar config (repo: `glats/omarchy-nix`)

- [x] 1.1 Inserted `"custom/language"` in `modules-right` array, before `"cpu"`
- [x] 1.2 Added module config block with `exec`, `interval: 5`, `on-click`,
      `format: "{} "`, `tooltip: true`
- [x] 1.3 Validated JSON with `python3 -m json.tool` → round-trips cleanly
- [x] 1.4 Committed on `main`:
      `feat(waybar): add keyboard layout indicator module` (SHA `aef7528`)
- [x] 1.5 Pushed to `github:glats/omarchy-nix/main`

### Phase 2 — nixos-hosts flake pin (repo: `nixos-hosts`)

- [x] 2.1 Confirmed Phase 1 commit visible on remote
- [x] 2.2 Ran `nix flake lock --update-input omarchy-nix` → flake.lock now
      pins `omarchy-nix` to `aef75282a0623ee46a1c553e7e355f93d8e9dc82`
- [x] 2.3 `nix flake check --no-build` → **all checks passed**
      (rog, thinkcentre, t14, darwinConfigurations, homeConfigurations, formatter)
- [x] 2.4 Ran `format-nix` → 0 files reformatted
- [x] 2.5 Committed on `master`:
      `chore(flake): update omarchy-nix pin for waybar layout indicator`
      (SHA `d1de8d7`)
- [x] 2.6 Pushed to `github:glats/nixos-hosts/master`

## Files Changed

| File | Repo | Action | What Was Done |
|------|------|--------|---------------|
| `config/waybar/config` | `glats/omarchy-nix` | Modified | Added `"custom/language"` to `modules-right` (before `cpu`) + module config block (~8 lines) |
| `flake.lock` | `nixos-hosts` | Auto-updated | Bumped `omarchy-nix` input from `3c58881` → `aef7528` (3 lines changed) |

## Deviations from Design

None. Implementation matches the design.md interface contract exactly.

Minor note: the design document says "Commit on `main`" for nixos-hosts, but
the actual default branch in that repo is `master`. Used `master` as the
target branch since that is the repository's default branch and "main" was
clearly shorthand for "the default branch".

## Issues Found

### Pre-existing remote divergence during Phase 2 push

The remote `master` had 2 new commits (`refactor(flameshot)`,
`fix(flameshot)`) that were not in the local clone. Had to:

1. Stash the pre-existing unstaged WIP files (webcam-related changes that
   were not part of this change)
2. `git pull --rebase origin master`
3. Push (success)
4. `git stash pop` to restore the WIP files

This avoided `git push --force` (which is forbidden by AGENTS.md) and kept
my commit (`d1de8d7`) focused on only the flake.lock change. The user's
unrelated webcam WIP is preserved in the working tree, untouched.

### Nix flake lock deprecation warning (informational)

`nix flake lock --update-input omarchy-nix` printed:
```
warning: '--update-input' is a deprecated alias for 'flake update' and will be removed in a future version.
```

This is informational only. Used the explicit flag as the spec/tasks
required, rather than `nix flake update` (which would update all inputs).

## Commits Summary

| Repo | Commit SHA | Branch | Message |
|------|------------|--------|---------|
| `glats/omarchy-nix` | `aef75282a0623ee46a1c553e7e355f93d8e9dc82` | `main` | `feat(waybar): add keyboard layout indicator module` |
| `nixos-hosts` | `d1de8d7` (post-rebase) | `master` | `chore(flake): update omarchy-nix pin for waybar layout indicator` |

## Verification

- [x] `nix flake check --no-build` — all checks passed
- [x] `python3 -m json.tool` — waybar config JSON valid
- [x] `format-nix` — 0 files reformatted
- [x] `git push` succeeded on both repos (no force)
- [ ] **Phase 3 (user-driven, manual on t14)**:
  - [ ] User runs `nixos-build` on t14
  - [ ] Visual: `custom/language` widget visible in waybar right group
  - [ ] Click → layout toggles, bar updates within 5s
  - [ ] Alt+Shift → bar updates within 5s
  - [ ] Hover → tooltip shows layout name
  - [ ] No regression in cpu/battery/network/bluetooth/pulseaudio/clock/tray

## Status

**2/2 implementation phases complete. Ready for Phase 3 (user-driven manual
verification on t14).** No blockers. No further apply batches required.

## Workload / PR Boundary

- Delivery: direct-commits-on-main (size-exception)
- Phases 1-2 both complete; no follow-up apply batches planned
- Review budget: 8 lines in omarchy-nix + 3 lines in flake.lock = ~11 lines total
