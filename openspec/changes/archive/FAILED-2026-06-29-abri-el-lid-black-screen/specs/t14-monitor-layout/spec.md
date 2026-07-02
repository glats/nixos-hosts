# Delta for T14 Monitor Layout — Black Screen Fix

> **Modifies**: `t14-monitor-layout-perfection` (CAP-DEADZONE, CAP-OWNER)
> **Root cause**: eDP-1 at (4920, 420) places Wayland origin outside viewport when undocked → black screen.

## ADDED Requirements

### Requirement: Undocked Single-Monitor Layout

When no externals are connected and lid is open, the system MUST position eDP-1 at (0, 0) via a new `move_to_alone` function.

#### Scenario: Undock after lid-open

- GIVEN docked, lid open (eDP-1 at 4920x420, 3 externals active)
- WHEN dock disconnected (all externals removed)
- THEN daemon detects zero externals, applies `move_to_alone` (eDP-1 at `preferred, 0x0, 1`)
- AND display is visible (no black screen)

#### Scenario: Boot undocked

- GIVEN no externals at boot, lid open
- WHEN daemon starts
- THEN eDP-1 positioned at `preferred, 0x0, 1`

### Requirement: External Monitor Detection

The daemon MUST query active monitor count via `hyprctl monitors -j` (excluding eDP-1) before selecting a layout.

#### Scenario: Partial dock

- GIVEN lid open, 1 of 3 externals connected
- WHEN daemon evaluates layout
- THEN daemon detects externals present → applies `move_to_y420`

### Requirement: Lid Events in Daemon Event Loop

The daemon's socket2 loop MUST subscribe to `switch:on`/`switch:off` lid events alongside existing `monitoradded`/`monitorremoved`.

#### Scenario: Lid open while undocked

- GIVEN lid closed, undocked (eDP-1 disabled)
- WHEN lid opens
- THEN daemon applies `move_to_alone` (eDP-1 at 0x0), persists `$ENABLE_LAPTOP = 1`

#### Scenario: Lid close while docked

- GIVEN docked, lid open
- WHEN lid closes
- THEN daemon applies `move_to_y0` (eDP-1 disabled, externals at y=0), persists `$ENABLE_LAPTOP =`

---

## MODIFIED Requirements

### Requirement: Daemon as Single Runtime Authority

The daemon MUST branch on lid state AND external presence. MUST NOT call `hyprctl reload` — `hyprctl keyword` applies immediately.

| Lid | Externals | Layout | eDP-1 | Externals Y |
|-----|-----------|--------|-------|-------------|
| open | connected | `move_to_y420` | 4920x420 | y=420 |
| open | none | `move_to_alone` | 0x0 | n/a |
| closed | any | `move_to_y0` | disabled | y=0 |

(Previously: branched only on lid state. No external detection. Called `hyprctl reload` unconditionally.)

#### Scenario: Dock after lid-open

- GIVEN undocked, lid open (eDP-1 at 0x0)
- WHEN dock connected (3 externals appear)
- THEN daemon applies `move_to_y420` — dead-zone layout preserved

### Requirement: Bindls Write settings.conf Only

Lid-switch `bindl` entries MUST ONLY write `settings.conf`. MUST NOT execute `hyprctl keyword monitor`.

(Previously: bindls wrote settings.conf AND executed `hyprctl keyword` for all 4 monitors.)

#### Scenario: Lid close triggers bindl

- GIVEN lid open, `$ENABLE_LAPTOP = 1`
- WHEN lid closes
- THEN bindl writes `$ENABLE_LAPTOP =` only — daemon handles positioning

### Requirement: Static Config Safe Default

The `if ENABLE_LAPTOP` block MUST position eDP-1 at `preferred, 0x0, 1` (not 4920x420). Daemon corrects to y=420 when docked.

(Previously: eDP-1 hardcoded at `preferred, 4920x420, 1`.)

#### Scenario: Boot undocked before daemon starts

- GIVEN no externals, lid open
- WHEN Hyprland parses config (daemon not yet started)
- THEN eDP-1 at `preferred, 0x0, 1` — display visible

---

## Edge Cases

**Daemon not running**: Falls back to static config + bindls. Without daemon, undock+lid-open → black screen (eDP-1 at 4920x420 from static block). Systemd service MUST have `restartTriggers`.

**hyprctl reload**: Daemon MUST NOT reload after positioning. `hyprctl keyword` applies immediately; reload causes flicker.
