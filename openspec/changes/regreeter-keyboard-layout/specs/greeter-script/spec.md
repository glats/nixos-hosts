# Delta for greeter-script

## MODIFIED Requirements

### Requirement: REQ-GS-004 — Preserve keyboard layout switching at login screen

The Hyprland-as-greeter-compositor architecture SHALL provide keyboard layout switching (Alt+Shift between es and latam) at the login screen. When `omarchy.greeter.layoutIndicator.enable = true`, a waybar-based indicator SHALL display the active layout name ("ES" or "LATAM") in the greeter compositor within 2 seconds of a toggle.

(Previously: keyboard layout toggle at login screen had zero visual feedback — layout changed silently with no indicator.)

#### Scenario: es/latam toggle works at greetd login screen

- GIVEN the greeter Hyprland config includes `input { kb_layout = es,latam; kb_options = grp:alt_shift_toggle }`
- WHEN a user presses Alt+Shift at the ReGreet login screen
- THEN the keyboard layout SHALL toggle between es and latam

#### Scenario: ReGreet session behavior is unchanged

- GIVEN the greeter script includes layout indicator support
- WHEN greetd starts the greeter session
- THEN ReGreet SHALL render as a GTK application inside the Hyprland compositor
- AND the greeter SHALL accept username/password input
- AND the session SHALL launch `uwsm start hyprland-uwsm.desktop` upon successful authentication

#### Scenario: Layout indicator displays when enabled (NEW)

- GIVEN `omarchy.greeter.layoutIndicator.enable = true`
- WHEN the greeter session starts
- THEN waybar SHALL launch via `exec-once` before regreet
- AND waybar SHALL display "ES" or "LATAM" on a 24px bottom bar using layer-shell `dock` mode
- AND the indicator SHALL update within 2 seconds of an Alt+Shift layout toggle
