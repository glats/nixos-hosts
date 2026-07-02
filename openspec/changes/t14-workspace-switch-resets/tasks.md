# Tasks: Waybar Workspace Switch Crash Fix

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~40 across 5 files |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR per repo (or direct commit) |
| Delivery strategy | no-pr (direct commits) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | omarchy-nix: waybar config + systemd | direct commit | push to main |
| 2 | nixos-hosts: systemd service + flake cleanup | direct commit | push to master |

## Phase 1: omarchy-nix (push to origin/main)

- [x] 1.1 Read current `config/waybar/config`, verify `hyprland/workspaces` block
- [x] 1.2 Replace `hyprland/workspaces` → `ext/workspaces` in `config/waybar/config` (add `all-outputs: true`, `on-click: activate`, drop `persistent-workspaces`)
- [x] 1.3 Update `modules/home-manager/hyprland/autostart.nix`: uwsm-app → `systemctl --user restart waybar`
- [x] 1.4 Update `bin/omarchy-toggle-waybar`: pkill+uwsm-app → `systemctl --user is-active/stop/start`
- [x] 1.5 Verify `bin/omarchy-hyprland-monitor-watch` is clean (no `hyprctl reload`) — REMOVED (file had `monitoradded>>` reload, not NO-OP as design claimed)
- [x] 1.6 Commit & push omarchy-nix commits to origin/main

## Phase 2: nixos-hosts (commit to master)

- [x] 2.1 Add `systemd.user.services.waybar` block to `hosts/t14/home/default.nix`
- [x] 2.2 Remove `waybar-src` input from `flake.nix`
- [x] 2.3 Bump omarchy-nix pin in `flake.lock` (after omarchy-nix commits pushed)
- [x] 2.4 Run `nix flake check --no-build`
- [x] 2.5 Run `format-nix`
- [x] 2.6 Commit & push to origin/master

## Phase 3: Verification (on T14 hardware)

- [ ] 3.1 Run `nixos-build` on t14 (build + switch)
- [ ] 3.2 `pgrep waybar` — PID stable across 30 workspace switches
- [ ] 3.3 `journalctl --user -u waybar` — no crash/restart entries
- [ ] 3.4 Workspace indicator displays correctly on all monitors
- [ ] 3.5 `omarchy-toggle-waybar` (Super+Shift+Space) works via systemctl
- [ ] 3.6 Grep gate: no `hyprctl reload` in monitor-watch, no `waybar-src` in flake.nix
