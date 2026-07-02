# Delta Spec: t14-udev-drm-settle

> **Change**: `t14-udev-drm-settle`
> **Date**: 2026-06-29 (v2 — final, reflects actual outcome)
> **Status**: Partially deployed, superseded by `t14-monitor-layout-perfection`

## Purpose

Ensure DRM devices are probed before Hyprland starts by injecting `udevadm settle` into the compositor's startup sequence. The drop-in was deployed but proved insufficient for the EDID race; the DRM dependency was ultimately removed from the validator in the parent change.

## ADDED Requirements

### Requirement: DRM Settle Before Hyprland (CAP-DRM-SETTLE)

The system MUST deploy a systemd drop-in at `~/.config/systemd/user/wayland-wm@hyprland.desktop.service.d/udev-settle.conf` containing `ExecStartPre=-/run/current-system/sw/bin/udevadm settle --timeout=10`.

The drop-in MUST be instance-scoped to `hyprland.desktop` only. The `-` prefix MUST make the directive non-fatal — Hyprland SHALL start even if `udevadm settle` fails or times out.

#### Scenario: Cold boot with externals

- GIVEN `udevadm settle` drop-in is active
- WHEN system boots
- THEN `udevadm settle` runs before Hyprland
- AND udev event queue is drained before compositor starts

#### Scenario: udevadm settle fails or times out

- GIVEN `udevadm settle` exits non-zero or hits 10s timeout
- WHEN the systemd unit continues to ExecStart
- THEN Hyprland starts normally (non-fatal due to `-` prefix)

## MODIFIED Requirements (outcome)

### Requirement: Validator External Monitor Detection (superseded)

(Outcome: The validator was redesigned to not rely on DRM status at all. The retry loop was not collapsed — it was replaced entirely by lid-state-only logic in the parent change `t14-monitor-layout-perfection`. The `udevadm settle` drop-in provides a narrow synchronization margin but is not required for validator correctness.)

## ADDED Knowledge

### Limitation: `udevadm settle` does not wait for EDID probing

The `udevadm settle` command only synchronizes the udev event queue (device creation/removal). DRM connector EDID probing is asynchronous within the kernel DRM subsystem and continues after udev events are dispatched. `/sys/class/drm/*/status` may still show "disconnected" for connected monitors after `udevadm settle` returns.

This limitation was documented during implementation and informed the architectural decision to remove DRM dependency from the monitor layout validator.

## Out of Scope (confirmed)

- Other hosts (rog, thinkcentre, mact2)
- omarchy-nix upstream changes
- Runtime hotplug handling
- Changes to bindls, hyprlang conditionals, monitor-watch daemon, or settings.conf
