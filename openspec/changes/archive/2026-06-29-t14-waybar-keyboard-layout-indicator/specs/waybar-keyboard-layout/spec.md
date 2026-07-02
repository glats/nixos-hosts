# Delta Spec: Waybar Keyboard Layout Indicator

> This delta reflects fixes applied after the initial archive (2026-06-28).
> All deviations are documented in the verify report as intentional improvements.

## MODIFIED Requirements

### Requirement: Layout Display

The system SHALL display the current keyboard layout name in the waybar right module group. The display MUST update within 2 seconds of layout changes (improved from 5s for faster feedback).

The module SHALL be named `custom/language` and positioned in `modules-right` before the `cpu` module.

#### Scenario: Display current layout on startup

- GIVEN waybar is starting
- WHEN the custom/language module initializes
- THEN it SHALL execute `~/.local/share/omarchy/bin/kb-layout.sh`
- AND display the output ("es" or "latam") in the waybar
- AND update the display every 2 seconds
- AND use `exec-on-event: true` for instant refresh on waybar events

#### Scenario: Display updates after external layout change

- GIVEN the layout is currently "es"
- WHEN the user changes layout via Alt+Shift (external to waybar)
- THEN within 2 seconds the waybar display SHALL update to show "latam"

### Requirement: Click-to-Toggle

The system SHALL toggle between es and latam layouts when the user clicks the waybar module.

#### Scenario: Toggle from es to latam

- GIVEN the current layout is "es"
- WHEN the user clicks the custom/language waybar module
- THEN the system SHALL execute `/home/glats/.local/share/omarchy/bin/kb-toggle.sh` (absolute path)
- AND the layout SHALL change to "latam"
- AND the waybar display SHALL update to show "latam" within 2 seconds

#### Scenario: Toggle from latam to es

- GIVEN the current layout is "latam"
- WHEN the user clicks the custom/language waybar module
- THEN the system SHALL execute `/home/glats/.local/share/omarchy/bin/kb-toggle.sh` (absolute path)
- AND the layout SHALL change to "es"
- AND the waybar display SHALL update to show "es" within 2 seconds

#### Scenario: Debounce prevents double-fire

- GIVEN the user clicks the module rapidly
- THEN `kb-toggle.sh` SHALL debounce consecutive runs within a 500ms window
- AND only one toggle SHALL occur per rapid-click burst

### Requirement: Module Configuration

The waybar configuration SHALL include the custom/language module with the following properties:
- `exec`: `~/.local/share/omarchy/bin/kb-layout.sh`
- `interval`: 2
- `exec-on-event`: true
- `on-click`: `/home/glats/.local/share/omarchy/bin/kb-toggle.sh`
- `format`: `"{} "`
- `tooltip`: true

#### Scenario: Module config is valid

- GIVEN the waybar config file
- WHEN waybar loads the configuration
- THEN the custom/language module SHALL be present in `modules-right`
- AND all required properties SHALL be defined
- AND waybar SHALL start without configuration errors

## MODIFIED Dependencies

- `kb-layout.sh` and `kb-toggle.sh` MUST be deployed to `~/.local/share/omarchy/bin/` on the t14 host
- Hyprland 0.54.3+ MUST be configured with xkb layout groups for es and latam
- `kb-layout.sh` and `kb-toggle.sh` MUST use the Hyprland 0.54.3 device API (`hyprctl devices` + `switchxkblayout <device> <index>`)
- Waybar MUST be running on the t14 host

## MODIFIED Constraints

- This module is specific to the t14 host
- The module uses polling (2-second interval) combined with `exec-on-event: true` for instant refresh on waybar events
- The `on-click` path MUST be an absolute path (Waybar resolves `on-click` relative to CWD, not `$HOME`)
- The `kb-toggle.sh` script MUST include 500ms debounce to prevent double-fire from waybar
- Layout names MUST match the XKB layout identifiers configured in Hyprland (es, latam)
