# Exploration: t14-monitor-layout-perfection

> **Change**: `t14-monitor-layout-perfection` (t14 / Omarchy / Hyprland)
> **Repo**: `/home/glats/.nixos`
> **Date**: 2026-06-29 (v3 — final, complete implementation history)
> **SDD mode**: hybrid (Engram + filesystem)
> **Supersedes**: v2 (initial root cause mapping) which superseded v1 (incomplete)

## Goal

Eliminate remaining Hyprland monitor layout issues on t14 after docking/undocking and lid open/close cycles. The final implementation went far beyond the initial plan, iterating through 16 distinct changes and fixing 9 bugs discovered mid-flight.

## What Was Actually Implemented (Chronological)

### omarchy-nix PR — Generic Fixes (Phase 1)

1. **monitoradded handler** — Added `monitoradded>>|monitoraddedv2>>` case to `bin/omarchy-hyprland-monitor-watch` that calls `hyprctl reload`. This fixed a generic omarchy bug where the daemon only handled `monitorremoved`.

2. **lidSwitch.enable option** — Added `omarchy.hyprland.lidSwitch.enable` (bool, default true) in `config.nix` following the `omarchy.rotate_on_start` pattern. Wrapped `switchBindings` in `lib.optionals` in `bindings.nix` so when false, omarchy emits no lid-switch `bindl` lines.

### nixos-hosts — T14 Application (Phase 2, iterative bug fixes)

3. **Hyprlang conditionals for externals** — Removed static `lib.mkForce monitor = [...]` block. Added two `# hyprlang if ENABLE_LAPTOP` / `# hyprlang if !ENABLE_LAPTOP` conditional blocks in `extraConfig` positioning externals at y=420 vs y=0 (commit `759a6ed`).

4. **Disable omarchy lid-switch** — Set `omarchy.hyprland.lidSwitch.enable = false` in `hosts/t14/default.nix` (same commit).

5. **Flake lock update** — Pinned omarchy-nix to the commit with generic fixes (`50b1222`).

6. **BUG 1 FIX: Regex case-sensitivity** — Hyprland emits `switch:on:Lid Switch` (capital L), but the bindl regex was `.*lid.*`. Fixed to `.*[Ll]id.*` so the regex matches regardless of case (commit `9bd1a72`).

7. **BUG 2 FIX: Read-only settings.conf** — `home.file` creates Nix store symlinks that are read-only. The bindl's `printf` was silently failing because the symlink target was in the immutable store. Replaced with `home.activation.seedHyprSettings` which writes the file directly using shell (commits `9bd1a72` / `8cf3208`).

8. **BUG 3 FIX: Missing external repositioning** — Original bindl only called `hyprctl keyword monitor "eDP-1, disable"` (or `enable`). It never repositioned the three external monitors. Fixed by adding `hyprctl keyword monitor` calls for all three externals in both lid-open and lid-close bindl (commit `9bd1a72`).

9. **BUG 4 FIX: DRM probe race at boot** — The exec-once validator raced with DRM/EDID probing. Added 5×0.5s retry loop for `omarchy-hw-external-monitors` (commit `ca83c30`). Later replaced with `udevadm settle` drop-in (commit `f2951f2`).

10. **BUG 5 FIX: hyprlang truthiness** — `$ENABLE_LAPTOP = 0` is truthy in hyprlang parser (any non-empty value is truthy). Changed to `$ENABLE_LAPTOP =` (empty value) for the disabled state, and `$ENABLE_LAPTOP = 1` for enabled. Also updated bindl `printf` to emit the correct format (commit `a2705a6`).

11. **Extract validator to standalone script** — Moved the inline ~600-char bash validator from `exec-once` to `~/.local/bin/monitor-lid-validator.sh` with `home.file` for maintainability (commit `08fa3f3`).

12. **Simplify validator to lid-only logic** — Removed DRM dependency entirely. Validator now reads lid state from `/proc/acpi/button/lid/LID*/state` and applies the correct layout — only 2 branches (lid open / lid closed) instead of 3 (externals+open / externals+closed / no-externals). The `udevadm settle` drop-in ensures DRM is probed, and the lid-only approach is simpler and more robust (commit `3e80c7a`).

13. **Replace exec-once with systemd oneshot** — Moved from `exec-once` to a systemd oneshot service (`monitor-lid-validator.service` with `Type=simple`) that runs after `graphical-session.target`. This fixed exec-once not reliably executing the script (commit `b3c9798`).

14. **Auto-detect HYPRLAND_INSTANCE_SIGNATURE** — systemd services lack `HYPRLAND_INSTANCE_SIGNATURE` in their environment, causing `hyprctl` to fail silently. Added auto-detection via `ls -t "$XDG_RUNTIME_DIR/hypr/" | head -1` (commit `a15a724`).

15. **Remove state-check optimization** — The validator had a state-check that skipped `apply()` if the stored state matched. This was a no-op after the first failed run. Removed — always apply, since `hyprctl keyword` is idempotent (commit `6f25536`).

16. **Convert to daemon with polling** — Replaced the oneshot service with a `Type=simple` daemon that runs `--daemon` mode: applies once, then polls `hyprctl monitors -j` every 2s, re-applying on changes. Originally used `socat` for event-driven monitoring but socat was not in PATH in the systemd service. Polling is simpler and avoids PATH issues (commits `d464361`, `9ba7f02`).

## Key Bugs Discovered and Fixed

| # | Bug | Root Cause | Fix |
|---|-----|-----------|-----|
| 1 | bindl regex didn't match `Lid Switch` (capital L) | `.*lid.*` is case-sensitive | `.*[Ll]id.*` |
| 2 | settings.conf was a Nix store symlink → read-only | `home.file` creates immutable symlinks | `home.activation` shell script |
| 3 | bindl only disabled eDP-1, never repositioned externals | Originally designed for single-monitor toggle | Added `hyprctl keyword` for all 3 externals |
| 4 | Validator raced with DRM/EDID probing at boot | DRM subsystem async probe | udevadm settle + lid-state-only logic |
| 5 | `$ENABLE_LAPTOP = 0` is truthy in hyprlang | hyprlang treats any non-empty value as truthy | Use empty string for disabled |
| 6 | Validator state-check made it a no-op after first failed run | State variable tracking bug | Always apply (idempotent) |
| 7 | systemd service lacked HYPRLAND_INSTANCE_SIGNATURE | Environment not inherited from user session | Auto-detect via XDG_RUNTIME_DIR |
| 8 | exec-once didn't execute the script reliably | 4 format variants tried, all silently skipped in some cases | systemd service instead |
| 9 | socat not in systemd service PATH | socat not available in restricted systemd env | 2s polling loop instead |

## Final Architecture

### Three layers of monitor layout management

```
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 1: Parse-time (hyprlang conditionals)                     │
│                                                                 │
│ hyprland.conf (generated by Nix)                                │
│   ├── source = ~/.config/hypr/settings.conf                     │
│   │     → reads $ENABLE_LAPTOP = 1 | <empty>                   │
│   ├── # hyprlang if ENABLE_LAPTOP                                │
│   │   ├── monitor = eDP-1, preferred, 4920x420, 1              │
│   │   ├── workspace = 1, monitor:eDP-1, default:true           │
│   │   ├── workspace = 2, monitor:eDP-1                         │
│   │   ├── workspace = 3, monitor:eDP-1                         │
│   │   ├── externals at y=420 (below eDP-1 strip)               │
│   ├── # hyprlang if !ENABLE_LAPTOP                               │
│   │   ├── monitor = eDP-1, disable                             │
│   │   ├── externals at y=0 (full screen height)                │
│                                                                 │
│ → Correct layout from the first frame — no runtime fixup needed │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ LAYER 2: Boot-time (systemd daemon)                             │
│                                                                 │
│ monitor-lid-validator.service (Type=simple)                     │
│   After=graphical-session.target                                │
│   ├── Runs monitor-lid-validator.sh --daemon                    │
│   │   ├── Reads lid state from /proc/acpi/button/lid/LID*/state │
│   │   ├── Applies correct layout via hyprctl keyword           │
│   │   ├── Persists setting to settings.conf                    │
│   │   └── Enters 2s polling loop for monitor changes            │
│                                                                 │
│ → Corrects any mismatch between boot-time state and persisted   │
│   state (e.g. lid changed between sessions)                     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ LAYER 3: Runtime (lid-switch bindl + polling daemon)            │
│                                                                 │
│ Lid close: bindl fires → write settings.conf + hyprctl keyword  │
│   for all 4 outputs (eDP-1 disable + 3 externals at y=0)        │
│                                                                 │
│ Lid open:  bindl fires → write settings.conf + hyprctl keyword  │
│   for all 4 outputs (eDP-1 enable + 3 externals at y=420)       │
│                                                                 │
│ Daemon polling: every 2s, compares hyprctl monitors output.     │
│   On change (dock/undock), re-applies layout based on lid state. │
│                                                                 │
│ → Immediate response to lid events + automatic dock detection   │
└─────────────────────────────────────────────────────────────────┘
```

### State management

| Variable | Meaning | Used by |
|----------|---------|---------|
| `$ENABLE_LAPTOP = 1` | Lid open, eDP-1 should be enabled | hyprlang conditionals, bindl, validator |
| `$ENABLE_LAPTOP =` (empty) | Lid closed, eDP-1 should be disabled | hyprlang conditionals, bindl, validator |

Note: `$ENABLE_LAPTOP =` empty (NOT `0`) because hyprlang treats any non-empty value as truthy.

### Component ownership

| Component | File | Owns |
|-----------|------|------|
| hyprlang conditionals | `hosts/t14/home/hypr/monitors.nix` | Parse-time layout decisions |
| Lid-switch bindl | `monitors.nix:82-84` | Runtime lid event → immediate keyword + persist |
| Validator daemon script | `hosts/t14/home/scripts/monitor-lid-validator.sh` | Boot correction + dock/undock detection via polling |
| systemd service | `hosts/t14/home/default.nix:50-67` | Daemon lifecycle (After=graphical-session.target) |
| udevadm settle drop-in | `hosts/t14/home/default.nix:42-45` | Boot-time DRM probe synchronization |
| settings.conf seed | `hosts/t14/home/default.nix:33-38` | Initial file creation (not Nix store symlink) |
| omarchy-nix monitor-watch | omarchy-nix repo | `hyprctl reload` on monitoradded/removed (generic) |
| omarchy-nix lidSwitch opt-out | `hosts/t14/default.nix:158` | Disables omarchy's default bindl |

## Final State (at commit `9ba7f02`)

### Files changed in nixos-hosts

| File | Purpose |
|------|---------|
| `hosts/t14/home/hypr/monitors.nix` | Hyprlang conditionals + bindl + workspace rules |
| `hosts/t14/home/scripts/monitor-lid-validator.sh` | Standalone validator daemon script |
| `hosts/t14/home/default.nix` | systemd service, udev-settle drop-in, settings.conf activation, validator deployment |
| `hosts/t14/default.nix` | `omarchy.hyprland.lidSwitch.enable = false` |
| `flake.lock` | Pinned omarchy-nix (multiple bumps) |

### Files changed in omarchy-nix

| File | Purpose |
|------|---------|
| `bin/omarchy-hyprland-monitor-watch` | Added monitoradded>> handler |
| `config.nix` | Added `hyprland` submodule with `lidSwitch.enable` |
| `modules/home-manager/hyprland/bindings.nix` | Wrapped switchBindings in `lib.optionals` |

## Root Causes (as discovered during full implementation)

### RC1: Static external positioning regardless of lid state
The original `lib.mkForce monitor = [...]` pinned externals at y=420 always. When eDP-1 was disabled, externals stayed at y=420 leaving a 420px dead zone.

### RC2: Dual-writer race on lid-switch events
Two `bindl` entries (omarchy + T14) fire on the same `switch:on:Lid Switch` event. `bindl` is NOT "last wins" for switch events — both fire. When omarchy's `hyprctl reload` re-parses before T14's `hyprctl keyword`, stale state is visible for 5-50ms.

### RC3: monitoradded not handled by omarchy watch daemon
`omarchy-hyprland-monitor-watch` had no `monitoradded>>` case. Re-docking mid-session left new monitors at default positions.

### RC4: omarchy toggle flag never sourced
`omarchy-hyprland-monitor-internal disable()` writes a flag file that's never sourced by hyprland config. The toggle appears to work (notifies user) but does nothing.

### RC5: Nix store symlinks are read-only
`home.file` creates symlinks to the Nix store. Any `printf` / `>` write to a symlinked file fails silently (no error shown, file unchanged).

### RC6: hyprlang truthiness is counterintuitive
Hyprlang's preprocessor treats any non-empty value as truthy, including `0`. The disabled state must use an empty value (`$ENABLE_LAPTOP =`).

### RC7: systemd services lack Hyprland environment
`HYPRLAND_INSTANCE_SIGNATURE`, `PATH` with socat, and `XDG_RUNTIME_DIR` may all be missing in systemd user services. Must be explicitly set or auto-detected.

### RC8: exec-once execution is unreliable
Hyprland's `exec-once` silently skips some commands, especially multi-line bash. After 4 format variants (direct path, literal path, `$HOME` expansion, etc.), the reliable solution was a systemd service.
