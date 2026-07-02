# Tasks: T14 udev DRM Settle

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~10 net (one xdg.configFile block) |
| Delivery strategy | Single PR, deployed iteratively with main change |

## Phase 1: Implementation

- [x] 1.1 In `hosts/t14/home/default.nix`, add `xdg.configFile` block (after `seedHyprSettings`, before `home.file`) that writes `systemd/user/wayland-wm@hyprland.desktop.service.d/udev-settle.conf` with `ExecStartPre=-/run/current-system/sw/bin/udevadm settle --timeout=10`
- [x] 1.2 Verify: `nix flake check --no-build` passes
- [x] 1.3 Verify: `format-nix` passes

## Phase 2: Deployment

- [x] 2.1 Deployed via `nixos-build switch` as part of the main change iteration
- [x] 2.2 Verify drop-in is loaded: `systemctl --user cat wayland-wm@hyprland.desktop.service | grep udevadm` shows the ExecStartPre line

## Phase 3: Verification — Proved Insufficient

- [x] 3.1 `udevadm settle` runs before Hyprland (confirmed via `systemctl cat`)
- [x] 3.2 DRM probe NOT guaranteed after settle alone (confirmed limitation — settle only covers udev queue, not EDID probing)
- [x] 3.3 Retry loop in validator NOT collapsed (validator was replaced by lid-state-only logic in parent change instead)

## Outcome

The core insight of this change (synchronize DRM probe before Hyprland) was correct in intent but insufficient in mechanism. `udevadm settle` only synchronizes udev device events, not the kernel DRM subsystem's EDID probing. The DRM dependency was ultimately eliminated by architectural change (lid-state-only validator).

The `udevadm settle` drop-in remains deployed as belt-and-suspenders.

All 3 implementation tasks and 3 verification tasks complete.
