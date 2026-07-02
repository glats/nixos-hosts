# Design: HyprDynamicMonitors Migration (t14)

## Technical Approach

Replace t14's 3-layer monitor stack (hyprlang conditionals + polling daemon + lid bindl) with HyprDynamicMonitors (HDM v1.4.0). HDM is an event-driven Go daemon that subscribes to Hyprland socket2 + UPower D-Bus, then swaps Hyprland monitor config from TOML profiles. We use HDM's Home Manager module (writes to `~/.config/`, creates user systemd services) with 4 static profiles encoding exact coordinates from the current config. Workspace rules and GDK_SCALE remain in Nix.

## Architecture Decisions

### Decision: HM module over NixOS module

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `services.hyprdynamicmonitors` (NixOS) | Config in `/etc/xdg/`, system-level | ❌ |
| `home.hyprdynamicmonitors` (HM) | Config in `~/.config/`, user-level, natural for per-user tool | ✅ |

**Rationale**: HDM is a user-session daemon. The HM module writes TOML to `~/.config/hyprdynamicmonitors/config.toml` via `home.file` and creates user systemd services. The NixOS module writes to `/etc/xdg/` which works but is less conventional. t14 already uses NixOS-integrated HM, so the HM module is imported via `home-manager.users.glats.imports`.

### Decision: Static profiles over Go templates

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `config_file_type = "static"` | Plain Hyprland config files, simple symlink | ✅ |
| `config_file_type = "template"` | Go templates with dynamic vars, more complex | ❌ |

**Rationale**: All 4 profiles have known, fixed coordinates. No runtime variables needed. Static profiles are plain text files that HDM symlinks — trivial to debug and review.

### Decision: eDP-1 park off-screen instead of disable

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `monitor=eDP-1,disable` | Clean disable, but triggers Hyprland#1274 (black screen on re-enable) | ❌ |
| `monitor=eDP-1,preferred,-30000x0,1` | Parked off-screen, stays "enabled", avoids bug | ✅ |

**Rationale**: Hyprland issue #1274 causes black screens when re-enabling a previously disabled monitor. Parking at -30000x0 keeps eDP-1 active but invisible. Workspaces don't land there because the docked profiles assign workspaces to externals via `monitor:desc:` rules.

### Decision: Lid events via UPower, not /proc/acpi

| Option | Tradeoff | Decision |
|--------|----------|----------|
| HDM `--enable-lid-events` + UPower D-Bus | Event-driven, no polling, integrated with HDM scoring | ✅ |
| Keep `monitor-lid-validator.sh` polling `/proc/acpi` | 2s lag, custom code, redundant | ❌ |

**Rationale**: UPower is already enabled on t14 (`modules/hardware/amd-laptop.nix:25`). HDM subscribes to UPower D-Bus signals natively. The `--enable-lid-events` flag activates lid condition matching in profiles.

### Decision: Workspace rules stay in Nix

**Rationale**: HDM generates `monitor=` lines only. Workspace distribution (cyclic mod-3 across 20 workspaces) is a Nix-evaluated list that stays in `monitors.nix`. HDM's output is sourced alongside the Nix-generated workspace rules.

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        BUILD TIME                                │
│                                                                  │
│  flake.nix                                                       │
│    └─ inputs.hyprdynamicmonitors (GitHub flake)                  │
│         ├─ nixosModules.default (NOT used)                       │
│         └─ homeManagerModules.default                            │
│              └─ imported in hosts/t14/home/omarchy.nix           │
│                                                                  │
│  hosts/t14/hdm/                                                  │
│    ├─ config.toml ──────────→ ~/.config/hyprdynamicmonitors/    │
│    └─ hyprconfigs/           → ~/.config/hyprdynamicmonitors/   │
│         ├─ docked-lid-open.conf                                  │
│         ├─ docked-lid-closed.conf                                │
│         ├─ undocked-lid-open.conf                                │
│         └─ fallback.conf                                         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        BOOT TIME                                 │
│                                                                  │
│  graphical-session-pre.target                                    │
│    └─ hyprdynamicmonitors-prepare.service (oneshot)              │
│         └─ strips stale "monitor=...,disable" from output        │
│                                                                  │
│  graphical-session.target                                        │
│    ├─ hyprland.service                                           │
│    │    └─ sources ~/.config/hypr/config.d/                     │
│    │         ├─ monitors.nix → workspace rules + GDK_SCALE      │
│    │         └─ 99_autogenerated-monitors.conf (from HDM)       │
│    │                                                             │
│    └─ hyprdynamicmonitors.service (After=graphical-session)      │
│         └─ hyprdynamicmonitors run --enable-lid-events           │
│              ├─ Reads current state (monitors + lid + power)     │
│              ├─ Scores profiles → selects best match             │
│              ├─ Symlinks selected .conf → output destination     │
│              └─ Listens for events (socket2 + UPower D-Bus)      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        RUNTIME EVENTS                            │
│                                                                  │
│  Lid close → UPower D-Bus → HDM lid_events handler              │
│    → Re-score: docked-lid-closed wins → symlink swap            │
│    → hyprctl reload (or direct keyword) → externals at y=0      │
│                                                                  │
│  Monitor plug/unplug → Hyprland socket2 → HDM monitor handler   │
│    → Re-score: undocked-lid-open wins → symlink swap            │
│    → eDP-1 only at 0x0                                          │
│                                                                  │
│  Debounce: 1500ms (prevents thrashing on rapid dock/undock)     │
└─────────────────────────────────────────────────────────────────┘
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `flake.nix` | Modify | Add `hyprdynamicmonitors` input (GitHub flake, follows nixpkgs) |
| `hosts/t14/home/omarchy.nix` | Modify | Import `inputs.hyprdynamicmonitors.homeManagerModules.default`; add `home.hyprdynamicmonitors` config block |
| `hosts/t14/hdm/config.toml` | Create | Main HDM config: `[general]`, `[lid_events]`, `[scoring]`, 4 profile blocks, `[fallback_profile]` |
| `hosts/t14/hdm/hyprconfigs/docked-lid-open.conf` | Create | Static: eDP-1 at `preferred,4920x420,1`, externals at y=420 |
| `hosts/t14/hdm/hyprconfigs/docked-lid-closed.conf` | Create | Static: eDP-1 at `preferred,-30000x0,1`, externals at y=0 |
| `hosts/t14/hdm/hyprconfigs/undocked-lid-open.conf` | Create | Static: eDP-1 at `preferred,0x0,1` |
| `hosts/t14/hdm/hyprconfigs/fallback.conf` | Create | Static: `monitor=,preferred,auto,1` |
| `hosts/t14/home/hypr/monitors.nix` | Modify | Strip all `monitor=` lines, `source`, `bindl`, `if` blocks. Keep `mkWorkspaceRules` + `env=["GDK_SCALE,1"]` |
| `hosts/t14/home/default.nix` | Modify | Remove `home.activation.seedHyprSettings`, `xdg.configFile.".../udev-settle.conf"`, `systemd.user.services.monitor-lid-validator`, `home.file.".../monitor-lid-validator.sh"` |
| `hosts/t14/home/scripts/monitor-lid-validator.sh` | Delete | Replaced by HDM daemon |

## Interfaces / Contracts

### HDM TOML Config Structure

```toml
[general]
destination = "$HOME/.config/hypr/config.d/99_autogenerated-monitors.conf"
debounce_time_ms = 1500

[lid_events]
# UPower D-Bus query for lid state (default values, omitted for brevity)
# HDM provides sensible defaults for standard UPower installations

[scoring]
name_match = 10
description_match = 5
lid_state_match = 2

# Profile: Docked + Lid Open (3 externals + eDP-1, lid open)
[profiles.docked_lid_open]
config_file = "hyprconfigs/docked-lid-open.conf"
config_file_type = "static"

[profiles.docked_lid_open.conditions]
lid_state = "Opened"

[[profiles.docked_lid_open.conditions.required_monitors]]
name = "eDP-1"
monitor_tag = "laptop"

[[profiles.docked_lid_open.conditions.required_monitors]]
description = "AOC 24P1W1 OTNQ4HA000101"
monitor_tag = "external"

[[profiles.docked_lid_open.conditions.required_monitors]]
description = "Lenovo Group Limited LEN G24-10 U5B4GWF1"
monitor_tag = "external"

[[profiles.docked_lid_open.conditions.required_monitors]]
description = "AOC 2470W GGZM3HA438259"
monitor_tag = "external"

# Profile: Docked + Lid Closed (3 externals, lid closed)
[profiles.docked_lid_closed]
config_file = "hyprconfigs/docked-lid-closed.conf"
config_file_type = "static"

[profiles.docked_lid_closed.conditions]
lid_state = "Closed"

[[profiles.docked_lid_closed.conditions.required_monitors]]
name = "eDP-1"

[[profiles.docked_lid_closed.conditions.required_monitors]]
description = "AOC 24P1W1 OTNQ4HA000101"

[[profiles.docked_lid_closed.conditions.required_monitors]]
description = "Lenovo Group Limited LEN G24-10 U5B4GWF1"

[[profiles.docked_lid_closed.conditions.required_monitors]]
description = "AOC 2470W GGZM3HA438259"

# Profile: Undocked + Lid Open (eDP-1 only)
[profiles.undocked_lid_open]
config_file = "hyprconfigs/undocked-lid-open.conf"
config_file_type = "static"

[profiles.undocked_lid_open.conditions]
lid_state = "Opened"

[[profiles.undocked_lid_open.conditions.required_monitors]]
name = "eDP-1"

# Fallback: unmatched states (e.g., undocked + lid closed → suspend)
[fallback_profile]
config_file = "hyprconfigs/fallback.conf"
config_file_type = "static"
```

### Static Profile: docked-lid-closed.conf

```
monitor=desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x0,1,transform,1
monitor=desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x0,1
monitor=desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x0,1
monitor=eDP-1,preferred,-30000x0,1
```

### Nix Wiring (hosts/t14/home/omarchy.nix)

```nix
imports = [
  inputs.hyprdynamicmonitors.homeManagerModules.default
  # ... existing imports
];

home.hyprdynamicmonitors = {
  enable = true;
  configFile = ./hdm/config.toml;
  extraFiles = {
    "hyprdynamicmonitors/hyprconfigs" = ./hdm/hyprconfigs;
  };
  extraFlags = [ "--enable-lid-events" ];
};
```

### Flake Input (flake.nix)

```nix
hyprdynamicmonitors = {
  url = "github:fiffeek/hyprdynamicmonitors";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | `nix flake check --no-build` passes | Automated — verifies all 4 host toplevels build |
| Manual | Boot docked+lid-open → all monitors positioned | Physical test on t14 |
| Manual | Close lid while docked → externals reposition, eDP-1 parks | Physical test |
| Manual | Undock with lid open → eDP-1 only | Physical test |
| Manual | `systemctl --user status hyprdynamicmonitors` → active | Verify service running |
| Manual | `hyprdynamicmonitors run --dry-run` → correct profile selected | Verify scoring |

## Migration / Rollout

1. Add flake input + HM module import (no behavior change yet)
2. Create HDM config files (not yet enabled)
3. Enable `home.hyprdynamicmonitors.enable = true`
4. Strip `monitors.nix` (HDM now owns monitor positioning)
5. Remove daemon script + systemd service + seed activation
6. `nix flake check --no-build` → manual test matrix
7. Archive superseded `abri-el-lid-...` open design

## Rollback Plan

1. `git revert` the migration commit (all changes in t14-specific paths)
2. Old `monitor-lid-validator.sh` and systemd service remain in git history
3. HDM flake input removal is clean (no other host references it)
4. No database, secrets, or cross-host dependencies

## Open Questions

- [ ] None — all technical questions resolved during exploration
