# POSTMORTEM: t14-black-screen-undock (FAILED)

**Archived**: 2026-06-30
**Status**: SUPERSEDED — approach replaced by `hyprdynamicmonitors-migration-v1`
**Sessions**: 1 session, ~8 hours of debugging across 40+ commits

---

## What We Were Trying To Fix

T14 laptop: open lid + disconnect from dock → built-in screen (eDP-1) goes completely black.
Root cause: eDP-1 is hardcoded to `(4920, 420)` — the rightmost slot of a 3-external
virtual desktop. When undocked, Wayland origin (0,0) is outside the eDP-1 viewport.

## Why It Failed

The fix was small (~15 lines, 2 files) but we tried a 2D-branch polling daemon approach
that got tangled with pre-existing Hyprland 0.55 bugs:

1. **hyprctl keyword workspace is a no-op in Hyprland 0.55** — says "ok" but doesn't change
   active workspace rules. Only config file reload applies new rules.

2. **hyprctl reload causes visual reset** — the validator daemon polls every 2s and calls
   `apply()` on any snapshot change. The `hyprctl reload` at end of `apply()` (added in
   commit `c047442`) causes the compositor to flicker on every cycle.

3. **Workspace rule merging in Hyprland 0.55** — `mkWorkspaceRules` binds workspaces 1-3
   to external monitors (desc:AOC, desc:Lenovo, desc:AOC2470W) AND `extraConfig` binds
   the same workspaces to eDP-1. Hyprland 0.55 merges rather than overrides — two
   `default:true` for the same workspace breaks workspace switching.

4. **Polling false positives** — `monitor_snapshot()` uses `grep '"name"'` on JSON output.
   Minor JSON variations between polls trigger unnecessary `apply()` calls.

## What We Tried (and Discarded)

- `move_to_alone()` to reposition eDP-1 at (0,0) when undocked
- `has_externals()` via `hyprctl monitors -j | jq` to detect dock state
- `moveworkspacetomonitor` dispatcher to rebind workspaces (wrong syntax: comma vs space)
- `hyprctl keyword workspace` to rebind workspace rules (no-op in 0.55)
- `$DOCKED` variable in settings.conf with hyprlang conditionals (needed reload)
- State tracking to avoid redundant reloads (still flickered)

## Key Lessons for v2

1. **DO NOT use hyprctl reload** — it causes flicker and interacts badly with polling.
   `hyprctl keyword monitor` applies positions immediately.

2. **DO NOT bind the same workspace to two monitors** — Hyprland 0.55 merges, not overrides.
   Filter workspaces 1-3 from `mkWorkspaceRules` and let `extraConfig` handle them.

3. **The custom bash daemon is too fragile** — 71 lines with polling, /proc/acpi, jq,
   settings.conf, hyprlang conditionals, and 300-char bindls. Too many failure modes.
   Migrate to HyprDynamicMonitors (Go daemon with native IPC).

4. **TEST hyprctl commands on the T14 before writing code** — syntax varies by version.

## Relevant Files

- `hosts/t14/home/scripts/monitor-lid-validator.sh` — the daemon that needs replacing
- `hosts/t14/home/hypr/monitors.nix` — workspace rules + static monitor blocks
- `hosts/t14/home/default.nix` — systemd service, seed activation, udev drop-in
- `docs/t14-monitor-layout.md` — dead-zone layout documentation (y=420)
