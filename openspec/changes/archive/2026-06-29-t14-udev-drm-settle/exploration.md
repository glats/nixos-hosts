# Exploration: t14-udev-drm-settle

> **Change**: `t14-udev-drm-settle` (t14 / Omarchy / Hyprland / uwsm)
> **Repo**: `/home/glats/.nixos`
> **Date**: 2026-06-29 (v2 — final, outcome documentation)
> **SDD mode**: hybrid (Engram + filesystem)
> **Status**: Partially deployed — approach proved insufficient, merged into main `t14-monitor-layout-perfection` change

## Goal (Original)

Replace the fragile 5-attempt/0.5s retry loop in the Hyprland `exec-once` validator with a deterministic `udevadm settle` synchronization injected as a systemd `ExecStartPre` on the `wayland-wm@hyprland.desktop.service` unit.

## What Actually Happened

### Phase 1: Deploy (Completed)

The `udevadm settle` drop-in was deployed as designed:

- Added `xdg.configFile."systemd/user/wayland-wm@hyprland.desktop.service.d/udev-settle.conf"` in `hosts/t14/home/default.nix`
- Content: `ExecStartPre=-/run/current-system/sw/bin/udevadm settle --timeout=10`
- Instance-scoped to `hyprland.desktop` only
- Non-fatal (`-` prefix) with 10s timeout

### Phase 2: Proved Insufficient

The `udevadm settle` approach has a fundamental limitation:

1. **`udevadm settle` only drains the udev event queue** — it waits for device creation/removal events to be processed. It does NOT wait for DRM connectors to finish EDID probing.
2. **DRM/EDID probing is asynchronous** within the kernel DRM subsystem. Even after udev says "device is ready", the connector's EDID may still be being read via I2C.
3. **`omarchy-hw-external-monitors` reads `/sys/class/drm/card*-*/status`** — these status files may show "disconnected" even after `udevadm settle` if EDID hasn't been read yet.
4. **The retry loop was workable for a reason** — it retries up to 2.5 seconds, which gives enough time for EDID to complete on this hardware. The settle only covers part of the race.

### Phase 3: Approach Revised

The T14 monitor layout fix (`t14-monitor-layout-perfection`) took a different approach:

1. **Removed DRM dependency from validator entirely** — the validator now reads lid state only from `/proc/acpi/button/lid/LID*/state`. It doesn't need to know about external monitors at all.
2. **Two branches instead of three**: lid open → enable eDP-1 and position at y=420; lid closed → disable eDP-1 and position externals at y=0. No DRM status check needed.
3. **The `udevadm settle` drop-in was kept** as a belt-and-suspenders measure — it's harmless, still deployed, and provides a tiny extra margin for any future DRM-dependent scripts.

## Current State

### What still exists (kept)

- `xdg.configFile."systemd/user/wayland-wm@hyprland.desktop.service.d/udev-settle.conf"` — still deployed in `hosts/t14/home/default.nix`, unchanged
- `ExecStartPre=-/run/current-system/sw/bin/udevadm settle --timeout=10` — still active

### What was removed/superseded

- The DRM retry loop in the validator was replaced by lid-state-only logic
- The exec-once validator was replaced by a systemd daemon (in the main change)
- The retry loop was never collapsed to a single call (because the validator was replaced entirely)

### Relationship to main change

The `t14-udev-drm-settle` change addressed a symptom (DRM race) that was eliminated by the architectural change in `t14-monitor-layout-perfection` (lid-state-only validator). The drop-in was kept because:
- It's a negligible maintenance cost
- It provides defense-in-depth for any future DRM-dependent scripts
- Removing it would be a user-visible change with no benefit

## Key Learnings

1. `udevadm settle` only covers device creation events, not driver-level probing (EDID, connector status)
2. Lid state is a more reliable signal than DRM probe status for monitor layout decisions
3. A belt-and-suspenders approach (keep harmless infrastructure even when superseded) is appropriate when maintenance cost is near-zero
4. The DRM probe race was ultimately solved by changing the architecture to not depend on DRM at all, not by adding synchronization

## Files Changed

| File | Change | Status |
|------|--------|--------|
| `hosts/t14/home/default.nix` | Added `xdg.configFile` for udev-settle drop-in | Deployed, kept |
| `hosts/t14/home/hypr/monitors.nix` | Validator retry loop → lid-state-only (in main change) | Superseded by main change |

## Related Changes

- `openspec/changes/t14-monitor-layout-perfection/` — parent change that subsumed this work
