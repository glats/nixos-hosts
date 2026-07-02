# Proposal: t14-monitor-layout-perfection

## Intent

Eliminate the 420px dead zone on external monitors when eDP-1 is disabled, fix the dual-writer race between omarchy and T14 lid-switch handlers, and enable proper hotplug recovery. The implementation went through 16 iterations and fixed 9 bugs discovered mid-flight, converging on a three-layer architecture (parse-time conditionals + boot-time daemon + runtime bindl).

## Scope (as implemented)

### In Scope (delivered)

**omarchy-nix (generic, backward-compatible):**
- `monitoradded>>` / `monitoraddedv2>>` handler in `bin/omarchy-hyprland-monitor-watch` → `hyprctl reload`
- `omarchy.hyprland.lidSwitch.enable` option (bool, default true) wrapping lid-switch `bindl` in `lib.optionals`
- Both changes are generic — backward-compatible, benefit all omarchy users

**nixos-hosts (T14-specific):**
- Hyprlang conditionals for externals (`# hyprlang if ENABLE_LAPTOP` / `!ENABLE_LAPTOP`)
- `omarchy.hyprland.lidSwitch.enable = false` to eliminate dual-writer race
- Flake lock pin to updated omarchy-nix
- Regex case-sensitivity fix: `.*lid.*` → `.*[Ll]id.*`
- `home.activation.seedHyprSettings` (not `home.file` symlink) for writable settings.conf
- External repositioning in bindl for ALL 4 outputs (not just eDP-1)
- Standalone validator script (`~/.local/bin/monitor-lid-validator.sh`)
- Lid-state-only validator logic (removed DRM dependency)
- systemd daemon service (`monitor-lid-validator.service`, `Type=simple`)
- `HYPRLAND_INSTANCE_SIGNATURE` auto-detection
- 2s polling loop for dock/undock detection (replaced unreliable socat)
- `udevadm settle` ExecStartPre drop-in (belt-and-suspenders)
- Hyprlang truthiness fix: empty value for disabled, not `0`

### Out of Scope (confirmed)

- Fix omarchy toggle `source` directive (separate upstream PR)
- Greeter monitor config unification
- split-monitor-workspaces or hyprmoncfg adoption
- Hosts other than t14

## Capabilities (as delivered)

### Delivered Capabilities

1. **Parse-time correct layout** — hyprlang conditionals position externals correctly from the first frame, eliminating the dead zone without runtime fixup
2. **Single-owner lid-switch** — omarchy's lid-switch bindl disabled, T14's bindl is the sole runtime writer
3. **Boot-time daemon** — systemd service corrects any state mismatches at startup
4. **Auto dock detection** — polling daemon detects monitor changes and re-applies layout
5. **DRM probe synchronization** — `udevadm settle` ensures DRM devices are probed before Hyprland starts
6. **Standalone validator** — extracted to maintainable script with `--daemon` / `--apply-once` modes

### Notable Tradeoffs and Fixes

- **socat → polling**: socat not available in systemd service PATH; polling is simpler and has fewer failure modes
- **exec-once → systemd service**: exec-once execution was unreliable across 4 format variants; systemd service is deterministic
- **DRM check → lid-only**: removed DRM+external detection from validator; lid state is the single source of truth for which layout to apply
- **State-check → always-apply**: removed optimization that tracked previous state; `hyprctl keyword` is idempotent so always-applying is safe

## Affected Areas (final)

| Area | Impact | Description |
|------|--------|-------------|
| `omarchy-nix/bin/omarchy-hyprland-monitor-watch` | Modified | Added `monitoradded>>` case → `hyprctl reload` |
| `omarchy-nix/config.nix` | Modified | Declared `omarchy.hyprland.lidSwitch.enable` option |
| `omarchy-nix/modules/home-manager/hyprland/bindings.nix` | Modified | Wrapped switchBindings in `lib.optionals` |
| `hosts/t14/home/hypr/monitors.nix` | Modified | Hyprlang conditionals + bindl with regex fix + all-4-outputs repositioning |
| `hosts/t14/home/scripts/monitor-lid-validator.sh` | Created | Standalone validator daemon script (71 lines) |
| `hosts/t14/home/default.nix` | Modified | systemd service, udev-settle drop-in, activation script, validator deployment |
| `hosts/t14/default.nix` | Modified | Set `omarchy.hyprland.lidSwitch.enable = false` |
| `flake.lock` | Modified | Multiple omarchy-nix bumps |

## Risks (retrospective)

| Risk | Materialized? | Mitigation |
|------|---------------|------------|
| hyprlang truthiness: `0` is truthy | YES — Bug 5 | Used empty value instead |
| systemd PATH lacks socat/hyprctl | YES — Bugs 7, 9 | Auto-detect HIS + polling loop |
| exec-once not reliable | YES — Bug 8 | systemd service instead |
| settings.conf read-only (Nix symlink) | YES — Bug 2 | home.activation script |
| Multiple flake bumps needed | YES | Routine, each verified |

## Rollback Plan

**omarchy-nix**: Revert the two commits (option + monitoradded handler). Backward-compatible defaults.
**nixos-hosts**: Revert to commit before `759a6ed` (or revert individual commits for targeted rollback).

## Success Criteria (as met)

- [x] No dead zone at y<420 on externals when eDP-1 disabled (lid closed)
- [x] No transient flicker on lid open/close with externals (single bindl owner)
- [x] Mid-session dock/undock triggers layout re-apply via daemon polling
- [x] `nix flake check --no-build` passes
- [x] Workspace distribution (mod-3) unchanged
- [x] omarchy-nix changes backward-compatible (default `lidSwitch.enable = true`)
- [x] settings.conf is writable (not Nix store symlink)
- [x] `$ENABLE_LAPTOP =` empty correctly disables eDP-1
