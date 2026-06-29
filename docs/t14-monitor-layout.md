# T14 Monitor Layout

## Quick Reference

| Label | Connector | Description | WS-Alias |
|-------|-----------|-------------|----------|
| AOC 24P1W1 (rotated) | DP-5 | `desc:AOC 24P1W1 OTNQ4HA000101` | 1,4,7,10,13,16,19 |
| Lenovo G24-10 | DP-4 | `desc:Lenovo Group Limited LEN G24-10 U5B4GWF1` | 2,5,8,11,14,17,20 |
| AOC 2470W | DP-3 | `desc:AOC 2470W GGZM3HA438259` | 3,6,9,12,15,18 |
| T14 built-in | eDP-1 | `Lenovo Group Limited 0x40A9` | none (free) |

## Positions

```
y=0     ╔══════════════════╗
        ║   DP-5 (rotated) ║  AOC 24P1W1 (1080×1920, transform 1)
        ║   ws 1,4,7...    ║  x=0, y=0
y=420   ║   ┌──────────┐ ┌──────────┐ ┌──────────┐
        ║   │ DP-4     │ │ DP-3     │ │ eDP-1    │
        ║   │ ws 2,5.. │ │ ws 3,6.. │ │ (free)   │
y=1499  ║   └──────────┘ └──────────┘ └──────────┘
        ║                  ║
y=1919  ╚══════════════════╝
        x=0      x=1080     x=3000     x=4920
```

- DP-5 (rotated portrait): 1080px wide effective → y=[0,1919]
- DP-4, DP-3, eDP-1: 1920×1080, y=420 (centered vertically with rotated DP-5)
- y=420 eliminates cursor dead zone when crossing between monitors

## eDP-1 Behavior

State driven by `~/.config/hypr/settings.conf` (`$ENABLE_LAPTOP`):

| Condition | State |
|-----------|-------|
| Lid open (any monitors) | enabled at 4920x420 |
| Lid closed + externals | disabled |
| No external monitors | always enabled |

Persisted across sessions — if lid was closed at logout, eDP-1 starts disabled
at config parse time (no orphan workspaces).

## Desc Identifiers (for waybar, window rules, etc.)

```bash
# Get current connector names
hyprctl monitors -j | jq '.[] | {name, desc: .description}'

# Full monitor info
hyprctl monitors -j | jq '.[] | {name, desc, x, y, transform, activeWorkspace}'
```
