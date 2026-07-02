# Proposal: T14 udev DRM Settle

## Intent (as implemented)

Eliminate the boot-time DRM probe race on T14. The approach was partially deployed: the `udevadm settle` drop-in was added, but proved insufficient because it only covers device creation, not EDID/connector probing. The DRM dependency was ultimately removed from the validator (lid-state-only logic in the main `t14-monitor-layout-perfection` change). The `udevadm settle` drop-in was kept as a belt-and-suspenders measure.

## Scope (as implemented)

### Delivered
- `xdg.configFile` drop-in for `wayland-wm@hyprland.desktop.service.d/udev-settle.conf` — deployed and kept
- `ExecStartPre=-/run/current-system/sw/bin/udevadm settle --timeout=10` — active

### Superseded by `t14-monitor-layout-perfection`
- Collapsing the retry loop to a single call — no longer meaningful because the validator was replaced with lid-state-only logic
- The DRM probe race is now handled by architecture change, not synchronization

### Out of Scope (confirmed)
- Other hosts (rog, thinkcentre, mact2)
- omarchy-nix upstream changes
- Runtime hotplug handling

## Capabilities

### Deployed Capability
- **CAP-DRM-SETTLE**: `udevadm settle` runs before Hyprland starts (non-fatal, belt-and-suspenders)

### Superseded Capability
- **CAP-DRM-READY** (original): DRM devices guaranteed probed before exec-once validator — superseded by lid-state-only architecture

## Approach

The final approach is a hybrid: the `udevadm settle` drop-in provides a small synchronization margin for any DRM-dependent code, while the main architectural change (lid-state-only validator) eliminates the DRM dependency entirely.

## Affected Areas

| Area | Impact | Status |
|------|--------|--------|
| `hosts/t14/home/default.nix` | Added `xdg.configFile` for drop-in | Deployed, kept |
| `hosts/t14/home/hypr/monitors.nix` | Validator logic | Superseded by main change |

## Risks (retrospective)

| Risk | Outcome |
|------|---------|
| `udevadm settle` insufficient for EDID race | Confirmed — settle only covers device creation, not connector probing |
| Architecture dependency on DRM probed state | Eliminated — lid-state-only validator doesn't read DRM |
| 10s timeout delays compositor | Never observed — settle completes in <100ms when queue is empty |

## Rollback Plan

Remove the `xdg.configFile` block from `hosts/t14/home/default.nix`. The file is deleted on next HM activation. No state to clean up. However, there's no reason to remove it — it's harmless and provides defense-in-depth.

## Success Criteria

- [x] `systemctl --user cat wayland-wm@hyprland.desktop.service` shows `ExecStartPre` with `udevadm settle` — CONFIRMED
- [x] Cold boot with externals: `hyprctl monitors` shows correct layout — CONFIRMED (via lid-state-only architecture)
- [x] `nix flake check --no-build` passes — CONFIRMED
