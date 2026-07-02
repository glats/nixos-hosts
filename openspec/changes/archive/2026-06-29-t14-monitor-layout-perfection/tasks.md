# Tasks: t14-monitor-layout-perfection

## Review Workload Forecast (final)

| Field | Value |
|-------|-------|
| Total commits | ~25 across two repos (omarchy-nix: 1 PR, nixos-hosts: 20+ commits) |
| Estimated changed lines | ~200 net (omarchy-nix: +25, nixos-hosts: +162 over 5 files) |
| Bugs discovered mid-flight | 9 |
| Delivery strategy | 2 PRs (omarchy-nix → nixos-hosts), iterative on nixos-hosts side |

## Phase 1: omarchy-nix Generic Foundation (PR 1)

PR branch: `feat/monitor-hotplug-and-lidswitch-optout` in `~/repos/omarchy-nix`.

- [x] 1.1 **WU1**: in `bin/omarchy-hyprland-monitor-watch`, add `monitoradded>>|monitoraddedv2>>)` case branch before existing `monitorremoved>>` case; action is `hyprctl reload`; preserve existing `monitorremoved>>` block unchanged
- [x] 1.2 **WU2**: in `config.nix`, declare `omarchy.hyprland` submodule with `lidSwitch.enable` (bool, default true)
- [x] 1.3 **WU2**: in `bindings.nix`, change `switchBindings = [ ... ]` to `switchBindings = lib.optionals cfg.hyprland.lidSwitch.enable [...]`
- [x] 1.4 verify: `nix flake check --no-build` in omarchy-nix; `bash -n bin/omarchy-hyprland-monitor-watch`
- [x] 1.5 verify: build sample home with `lidSwitch.enable = false`; grep generated config for no omarchy bindl
- [x] 1.6 commit + push PR 1 to `omarchy-nix/main` at commit `f771f94`

## Phase 2: nixos-hosts T14 Application (iterative, 20+ commits)

This phase evolved through many iterations as bugs were discovered and fixed. The final state encompasses all the following completed work.

### WU3: Hyprlang Conditionals (milestone commit `759a6ed`)
- [x] 2.1 Remove `lib.mkForce monitor = [...]` block from `monitors.nix`
- [x] 2.2 Add `# hyprlang if ENABLE_LAPTOP` block for externals at y=420
- [x] 2.3 Add `# hyprlang if !ENABLE_LAPTOP` block for externals at y=0

### WU4: Disable Omarchy Lid-Switch (same commit)
- [x] 2.4 Add `omarchy.hyprland.lidSwitch.enable = false` in `hosts/t14/default.nix`

### WU5: Flake Pin (multiple bumps across iterations)
- [x] 2.5 Pin omarchy-nix to commit with generic fixes (initial: `50b1222`, multiple bumps thereafter)

### Bug Fixes (discovered mid-flight, chronological order)
- [x] 2.6 **BUG 1**: Fix regex case-sensitivity — `.*lid.*` → `.*[Ll]id.*` (commit `9bd1a72`)
- [x] 2.7 **BUG 2**: Fix read-only settings.conf — replace `home.file` with `home.activation.seedHyprSettings` (commit `9bd1a72` / `8cf3208`)
- [x] 2.8 **BUG 3**: Fix missing external repositioning — add `hyprctl keyword` for all 3 externals in bindl (commit `9bd1a72`)
- [x] 2.9 **BUG 4**: Add DRM retry loop — 5×0.5s retry for `omarchy-hw-external-monitors` (commit `ca83c30`)
- [x] 2.10 Replace DRM retry loop with `udevadm settle` drop-in (commit `f2951f2`)
- [x] 2.11 Simplify validator to lid-only, remove DRM dependency (commit `3e80c7a`)
- [x] 2.12 Extract validator to standalone script `~/.local/bin/monitor-lid-validator.sh` (commit `08fa3f3`)
- [x] 2.13 **BUG 8**: Replace exec-once with systemd oneshot service (commit `b3c9798`)
- [x] 2.14 **BUG 7**: Auto-detect `HYPRLAND_INSTANCE_SIGNATURE` (commit `a15a724`)
- [x] 2.15 Fix direct path for validator exec-once (commit `a0abd77`)
- [x] 2.16 Fix literal path — Hyprland does not expand `$HOME` in exec-once (commit `0f44699`)
- [x] 2.17 **BUG 6**: Remove state-check optimization — always apply (commit `6f25536`)
- [x] 2.18 **BUG 5**: Fix hyprlang truthiness — use empty value, not `0` (commit `a2705a6`)
- [x] 2.19 Add `XDG_RUNTIME_DIR` to validator service env (commit `52a74de`)
- [x] 2.20 Convert validator daemon to systemd daemon + polling (commit `d464361`)
- [x] 2.21 **BUG 9**: Replace socat with 2s polling loop (commit `9ba7f02`)

### Verification (iterative)
- [x] 2.22 `nix flake check --no-build` after each commit
- [x] 2.23 `format-nix` after each Nix file change
- [x] 2.24 Generated config grep: conditionals present, no omarchy bindl

## Phase 3: Manual Verification (post-merge on t14)

- [x] 3.1 **CAP-CONDITIONAL**: boot docked + lid closed; `hyprctl monitors` shows externals at y=0 (no dead zone)
- [x] 3.2 **CAP-CONDITIONAL**: boot docked + lid open; externals at y=420, eDP-1 active
- [x] 3.3 **CAP-LIDSWITCH**: close lid with externals; verify no flicker; settings.conf shows `$ENABLE_LAPTOP =` empty
- [x] 3.4 **CAP-DAEMON**: daemon starts, polls, re-applies on monitor change
- [x] 3.5 **CAP-SETTINGS**: settings.conf is regular file, writable by bindl
- [x] 3.6 **CAP-DRM**: `udevadm settle` ExecStartPre present and non-fatal

All 24 implementation tasks and 6 verification tasks complete. 9 bugs fixed mid-flight.

## Bugs Fixed (summary)

| # | Bug | Fixed In |
|---|-----|----------|
| 1 | Regex `.*lid.*` doesn't match `Lid Switch` | Commit `9bd1a72` |
| 2 | settings.conf is Nix store symlink (read-only) | Commit `9bd1a72` |
| 3 | bindl only disables eDP-1, ignores externals | Commit `9bd1a72` |
| 4 | DRM/EDID races validator at boot | Commits `ca83c30` → `f2951f2` → `3e80c7a` |
| 5 | `$ENABLE_LAPTOP = 0` is truthy in hyprlang | Commit `a2705a6` |
| 6 | State-check makes validator no-op after first run | Commit `6f25536` |
| 7 | HYPRLAND_INSTANCE_SIGNATURE missing in systemd | Commit `a15a724` |
| 8 | exec-once silently skips the script | Commits `b3c9798`, `a0abd77`, `0f44699` |
| 9 | socat not in systemd service PATH | Commit `9ba7f02` |
