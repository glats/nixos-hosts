# waybar-systemd-service Specification

## Purpose

Define the systemd user service that manages waybar lifecycle: startup binding to graphical-session.target, automatic crash restart, stderr journaling, toggle script integration, and autostart from Hyprland.

## Requirements

### Requirement: SYS-SERVICE — Waybar as systemd user service

The system SHALL define waybar as a `systemd.user.services.waybar` unit via Home Manager.

| Req | Requirement |
|-----|-------------|
| SYS-SERVICE-1 | Unit Description MUST be "Waybar status bar" |
| SYS-SERVICE-2 | Unit MUST bind to graphical-session.target via PartOf, After, and WantedBy |
| SYS-SERVICE-3 | Service Type MUST be simple; ExecStart MUST be `${pkgs.waybar}/bin/waybar` |
| SYS-SERVICE-4 | The service SHALL replace the `uwsm-app -- waybar` launch in autostart.nix |

#### Scenario: Waybar starts with graphical session
- GIVEN graphical-session.target becomes active
- WHEN systemd processes the waybar service
- THEN waybar starts as a user service
- AND waybar PID is tracked by systemd

#### Scenario: Waybar stops with graphical session
- GIVEN waybar is running as systemd service
- WHEN graphical-session.target stops (logout)
- THEN the waybar service stops cleanly

### Requirement: SYS-RESTART — Automatic restart policy

The waybar service SHALL restart automatically on any exit with rate-limiting.

| Req | Requirement |
|-----|-------------|
| SYS-RESTART-1 | Restart MUST be "always" |
| SYS-RESTART-2 | RestartSec MUST be 100ms |
| SYS-RESTART-3 | StartLimitBurst MUST be 20 |
| SYS-RESTART-4 | StartLimitIntervalSec MUST be 5s |

#### Scenario: Recovery from crash
- GIVEN waybar process terminates abnormally
- WHEN systemd detects the exit
- THEN waybar restarts within 100ms

#### Scenario: Rate limit protects against rapid failures
- GIVEN waybar crashes 21 times within 5 seconds
- WHEN the 21st crash occurs
- THEN systemd stops restarting and marks the unit as failed

### Requirement: SYS-JOURNAL — Stderr capture to journal

The waybar service SHALL capture all module output to the systemd journal.

| Req | Requirement |
|-----|-------------|
| SYS-JOURNAL-1 | StandardOutput MUST be "null" (suppress stdout) |
| SYS-JOURNAL-2 | StandardError MUST be "journal" |
| SYS-JOURNAL-3 | Output SHALL be viewable via `journalctl --user -u waybar` |

#### Scenario: Module stderr visible in journal
- GIVEN waybar is running as systemd service
- WHEN any waybar module writes to stderr
- THEN output appears in `journalctl --user -u waybar`
- AND stdout is suppressed (not visible in terminal)

### Requirement: SYS-TOGGLE — Integration with omarchy-toggle-waybar

The toggle keybinding SHALL use systemctl for waybar start/stop.

#### Scenario: Toggle starts waybar when inactive
- GIVEN waybar service is not running
- WHEN user presses Super+Shift+Space
- THEN `systemctl --user start waybar` launches the service

#### Scenario: Toggle stops waybar when active
- GIVEN waybar service is running
- WHEN user presses Super+Shift+Space
- THEN `systemctl --user stop waybar` stops the service

#### Scenario: Toggle does not use pkill
- GIVEN waybar service is managed by systemd
- WHEN toggle is invoked
- THEN `pkill -f waybar` is NOT used
- AND `uwsm-app -- waybar` is NOT used

### Requirement: SYS-AUTOSTART — Launch from Hyprland autostart

Hyprland SHALL start waybar via systemctl on session startup.

#### Scenario: Hyprland exec-once starts waybar
- GIVEN Hyprland is starting
- WHEN exec-once is processed
- THEN `systemctl --user restart waybar` is executed
- AND waybar appears on all monitors

#### Scenario: Autostart does not use uwsm-app
- GIVEN waybar is managed by systemd
- WHEN Hyprland autostart runs
- THEN `uwsm-app -- waybar` is NOT called
- AND `pkill -x waybar` is NOT called
