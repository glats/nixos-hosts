# Greeter Layout Indicator Specification

## Purpose

Display active keyboard layout (es/latam) at the t14 greetd login screen via a waybar layer-shell bar. Users know layout state before typing password.

## Requirements

### Requirement: Layout Indicator Display

The greeter compositor SHALL display a waybar-based layout indicator showing "ES" or "LATAM" via `custom/kb-layout` module polling `hyprctl devices` at 1s intervals.

#### Scenario: Indicator visible on greeter startup

- GIVEN `omarchy.greeter.layoutIndicator.enable = true`
- WHEN greetd starts the greeter session
- THEN waybar SHALL display a 24px bottom bar with the active keyboard layout name
- AND the bar SHALL use layer-shell `dock` mode at the bottom of the screen

#### Scenario: Indicator updates after layout toggle

- GIVEN the indicator shows "ES"
- WHEN the user presses Alt+Shift
- THEN the indicator SHALL update to "LATAM" within 2 seconds

### Requirement: Non-Interference with ReGreet

The layout indicator SHALL NOT steal focus from or overlap the ReGreet login form.

#### Scenario: Login form unaffected by indicator

- GIVEN the layout indicator is displayed
- WHEN the greeter session is active
- THEN ReGreet SHALL appear centered on screen
- AND keyboard input SHALL focus on the ReGreet username field by default
- AND the 24px bottom bar SHALL NOT obscure the login form

### Requirement: Submodule Configuration

The `omarchy.greeter.layoutIndicator` submodule SHALL expose:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable layout indicator in greeter |

#### Scenario: Submodule disabled by default

- GIVEN a host using omarchy-nix
- WHEN `layoutIndicator.enable` is not set
- THEN no waybar SHALL launch in the greeter
- AND no `/etc/greetd/waybar-config` SHALL be generated

#### Scenario: Submodule enabled on t14

- GIVEN `layoutIndicator.enable = true` on t14
- WHEN the system is built
- THEN `/etc/greetd/waybar-config` SHALL exist with `custom/kb-layout` module
- AND the greeter Hyprland config SHALL include `GTK_USE_PORTAL=0`
- AND the greeter Hyprland config SHALL include `exec-once = waybar -c /etc/greetd/waybar-config`

### Requirement: Startup Ordering

When the layout indicator is enabled, waybar SHALL start before ReGreet to avoid a race condition.

#### Scenario: waybar starts before ReGreet

- GIVEN `layoutIndicator.enable = true`
- WHEN the greeter script executes
- THEN `exec-once` for waybar SHALL appear before `exec-once` for regreet in Hyprland config
- AND the greetd-regreet-start script SHALL delay 0.5s before launching regreet

### Requirement: Keyboard Layout Consistency

The layout toggle shortcut in the greeter (Alt+Shift, `grp:alt_shift_toggle`) SHALL match the user session shortcut. Both contexts use `grp:alt_shift_toggle`.

#### Scenario: Identical toggle in greeter and session

- GIVEN the t14 greeter uses `input { kb_options = grp:alt_shift_toggle }`
- WHEN the user logs in to their Hyprland session
- THEN the user session SHALL also use `grp:alt_shift_toggle`
- AND layout toggling SHALL behave identically in both contexts

## Constraints

- Host-specific: t14 only (rog=SDDM, thinkcentre=headless, mact2=macOS)
- Requires `pkgs.waybar` and `pkgs.jq` in greetd session PATH
- Polling interval: 1s (different from user session's 2s for faster greeter feedback)
- Layout names SHALL match XKB identifiers: "es" and "latam"
