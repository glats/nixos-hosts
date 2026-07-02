# Proposal: Waybar Workspace Switch Crash Fix

## Intent

Waybar crashes (disappear/reappear) on every workspace switch (Super+1-9) on t14/Hyprland 0.55. Root cause: `hyprland/workspaces` module uses socket2 IPC with threading bugs (IPC thread blocks on socket1 while holding mutex; GTK widget teardown races). Crash rate: 5-30/hour during normal use. Prior SDD removed `hyprctl reload` churn but the IPC crash surface remains.

## Scope

### In Scope
- Switch waybar module: `hyprland/workspaces` → `ext/workspaces` (Wayland ext-workspace-v1 protocol, zero IPC)
- Wrap waybar in systemd user service with `Restart=always` + `RestartSec=100ms` (belt-and-braces)
- Remove dead `waybar-src` flake input from `flake.nix` (lines 113-117)
- Apply missing prior-SDD Phase 2: remove `monitoradded>>` reload from `omarchy-hyprland-monitor-watch`; fix stderr capture in `autostart.nix`
- Fix `omarchy-toggle-waybar` stderr (log to `$XDG_RUNTIME_DIR`) and switch to `systemctl`

### Out of Scope
- HDM migration (separate change)
- Building waybar from git (`master` HEAD = regression, no crash fix exists upstream)
- `sway/workspaces` (Hyprland lacks i3 IPC), `wlr/workspaces` (not compiled in nixpkgs), `custom` polling (1s lag, no click targets)
- T14 workspace 1-3 persistence rework (Hyprland `persistent:true` rules already cover this)

## Capabilities

### New Capabilities
- `waybar-systemd-service`: waybar launched as `systemd --user` service (`Type=simple`, `WantedBy=graphical-session.target`) with `Restart=always`, `RestartSec=100ms`, `StartLimitBurst=20`. Replaces `uwsm-app` launch in `autostart.nix`. `omarchy-toggle-waybar` uses `systemctl --user stop/start`. `StandardError=journal` captures all waybar module stderr.

### Modified Capabilities
- `t14-monitor-layout` CAP-HOTPLUG: REQ-HOTPLUG-1 removed — `omarchy-hyprland-monitor-watch` no longer SHALL call `hyprctl reload` on `monitoradded>>` events. T14 daemon polling (REQ-HOTPLUG-2/3) already covers hotplug recovery within 2s. The reload was redundant AND caused waybar workspace-destroy crashes (original root cause from prior SDD session).

## Approach

1. **Config migration** (`omarchy-nix/config/waybar/config`): Replace `hyprland/workspaces` with `ext/workspaces`, add `"all-outputs": true`, keep `format-icons` (20 icons) and `"on-click": "activate"`. Drop `persistent-workspaces` — Hyprland `persistent:true` rules in `monitors.nix` already persist workspaces 1-20.
2. **Systemd service** (`hosts/t14/home/default.nix`): Add `systemd.user.services.waybar`. Update `autostart.nix` to `systemctl --user restart waybar`. Update `omarchy-toggle-waybar` to `systemctl --user is-active/stop/start`.
3. **Cleanup**: Remove `waybar-src` input from `flake.nix`. Remove `monitoradded>>` reload handler (lines 9-11) from `omarchy-hyprland-monitor-watch`. Fix stderr capture in both `autostart.nix` and `omarchy-toggle-waybar`.
4. **Flake lock bump**: Update omarchy-nix pin in `flake.lock` after omarchy-nix pushes.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `omarchy-nix/config/waybar/config` | Modified | hyprland/workspaces → ext/workspaces |
| `omarchy-nix/modules/home-manager/hyprland/autostart.nix` | Modified | uwsm-app → systemctl restart waybar |
| `omarchy-nix/bin/omarchy-hyprland-monitor-watch` | Modified | Remove monitoradded>> reload handler |
| `omarchy-nix/bin/omarchy-toggle-waybar` | Modified | systemctl + stderr to XDG_RUNTIME_DIR |
| `flake.nix` | Modified | Remove waybar-src input (lines 113-117) |
| `hosts/t14/home/default.nix` | Modified | Add systemd.user.services.waybar |
| `flake.lock` | Modified | Bump omarchy-nix pin |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| ext/workspaces fails on 3-monitor + eDP-1 layout | Med | Test on T14 hardware before merge. `all-outputs: true` is the key flag. |
| Workspaces 1-3 disappear when empty (docked) | Low | Hyprland `persistent:true` rules in monitors.nix keep them alive. ext/workspaces reflects Hyprland state. |
| Systemd service conflicts with UWSM lifecycle | Low | Both target `graphical-session.target` — same lifecycle, tested NixOS community pattern. |
| Omarchy-nix bump breaks rog/thinkcentre waybar | Low | `ext/workspaces` uses ext-workspace-v1 (Hyprland ≥ 0.52.1). Verify Hyprland version on rog before merge. |

## Rollback Plan

1. Revert omarchy-nix commit → restore hyprland/workspaces config + uwsm-app launch
2. Revert flake.nix → restore waybar-src input
3. Revert flake.lock bump → previous omarchy-nix pin
4. Rebuild: `nixos-build` on t14

## Dependencies

- Hyprland ≥ 0.52.1 (t14: 0.55 ✅)
- nixpkgs waybar v0.15.0 with `-Dexperimental=true` (compiled ✅)
- omarchy-nix push access (`glats/omarchy-nix` ✅ per AGENTS.md)
- ext-workspace-v1 protocol (Hyprland PR #10818, 2025-06-26 ✅)

## Success Criteria

- [ ] `pgrep waybar` shows stable PID across 30+ workspace switches (Super+1/2/3/4/5 cycling)
- [ ] `journalctl --user -u waybar -f` shows no crash/restart entries
- [ ] Workspace indicator shows all workspaces correctly on 3 externals + eDP-1
- [ ] Click on workspace button activates correct workspace
- [ ] `nix flake check --no-build` passes
- [ ] `format-nix` passes
- [ ] `git log --oneline` shows clean, well-described commits (no experiment noise)
