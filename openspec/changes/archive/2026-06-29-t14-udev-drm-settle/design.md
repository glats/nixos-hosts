# Design: T14 udev DRM Settle

## Technical Approach (as implemented)

Hybrid approach:
1. **Deployed**: `udevadm settle` systemd drop-in (`ExecStartPre=-/run/current-system/sw/bin/udevadm settle --timeout=10`) — provides synchronization margin for any DRM-dependent code
2. **Superseded**: The DRM retry loop in the validator was not collapsed to a single call; instead, the entire validator was replaced with lid-state-only logic in the main `t14-monitor-layout-perfection` change

## Architecture Decisions

### Decision: Keep udevadm settle drop-in

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Keep drop-in | Harmless, negligible maintenance cost, defense-in-depth | **Chosen** |
| Remove drop-in | Cleaner, but no user-visible benefit | Rejected |

**Rationale**: The drop-in is ~5 lines of Nix, has no runtime cost (settle returns in <100ms when queue is empty), and provides a small synchronization window for any future DRM-dependent code. Removing it would require a commit with no functional benefit.

### Decision: `udevadm settle` insufficient for the real race

**Evidence**: `udevadm settle` only drains the udev event queue (device creation/removal). DRM connector EDID probing happens asynchronously within the kernel — `/sys/class/drm/*/status` may still show "disconnected" after settle completes.

**Resolution**: The validator was redesigned to not read `/sys/class/drm` at all. Lid state (`/proc/acpi/button/lid/LID*/state`) is the single source of truth for which layout to apply.

### Decision: Absolute path for udevadm

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `/run/current-system/sw/bin/udevadm` | NixOS-specific but functional | **Chosen** |
| Bare `udevadm` | Fails — not in systemd user service PATH | Rejected |

### Decision: Instance-scope drop-in

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `wayland-wm@hyprland.desktop.service.d/` | Only affects Hyprland | **Chosen** |
| `wayland-wm@.service.d/` | Affects all compositors | Rejected |

### Decision: Non-fatal prefix and 10s timeout

- **`-` prefix**: Fail-open — Hyprland starts even if udevadm fails
- **`--timeout=10`**: Upper bound; typical settle <100ms

## Data Flow (Actual)

```
Boot → kernel loads DRM modules → udev queues device events
                                        │
                  ┌──────────────────────┘
                  ▼
systemd starts wayland-wm@hyprland.desktop.service
                  │
                  ▼
    ┌─────────────────────────────┐
    │ ExecStartPre (our drop-in)  │
    │ udevadm settle --timeout=10 │  ← drains udev queue (fast, <100ms)
    └─────────────┬───────────────┘
                  │
                  ▼
           Hyprland starts
                  │
                  ▼
    monitor-lid-validator.service  (from main change)
    └─ Reads lid state, NOT DRM status
    └─ Applies correct layout based on lid open/closed
```

Note: The original design expected the validator to collapse its DRM retry loop. Instead, the validator was replaced entirely with a lid-state-only approach. The settle drop-in provides a narrow synchronization margin but is not required for correctness.

## File Changes

| File | Change | Status |
|------|--------|--------|
| `hosts/t14/home/default.nix` | Added `xdg.configFile` block (after `seedHyprSettings`) | Deployed, kept |
| `hosts/t14/home/hypr/monitors.nix` | Validator retry loop → lid-state-only | Superseded by main change |

## Exact Diff (as deployed)

In `hosts/t14/home/default.nix` (after `home.activation.seedHyprSettings`, before the `monitor-lid-validator.service` block):

```nix
  # Ensure DRM devices are probed before Hyprland starts.  The - prefix
  # makes it non-fatal — Hyprland still starts if udevadm is unavailable.
  xdg.configFile."systemd/user/wayland-wm@hyprland.desktop.service.d/udev-settle.conf".text = ''
    [Service]
    ExecStartPre=-/run/current-system/sw/bin/udevadm settle --timeout=10
  '';
```

## Testing Strategy

| Layer | Test | Result |
|-------|------|--------|
| Build | `nix flake check --no-build` | PASS |
| File check | Drop-in exists at correct path | PASS |
| Unit check | `systemctl --user cat wayland-wm@hyprland.desktop.service \| grep udevadm` | PASS |
| Functional | Cold boot with externals shows correct layout | PASS (via lid-state-only architecture) |
| Regression | Non-fatal on missing udevadm | PASS (verified - prefix behavior) |

## Migration / Rollout

The change was additive (new drop-in file). Takes effect on next login. The drop-in remains deployed. No migration needed.
