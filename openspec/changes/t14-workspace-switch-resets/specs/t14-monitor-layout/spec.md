# Delta for t14-monitor-layout

## MODIFIED Requirements

### Requirement: CAP-HOTPLUG — Waybar Must Survive Monitor Hotplug and Workspace Switches

Waybar SHALL survive monitor hotplug AND workspace switches. Hotplug SHALL use T14 daemon polling only (no `hyprctl reload`). Workspace switches SHALL use ext-workspace-v1 protocol with systemd Restart=always.

(Previously: Hotplug only, with omarchy `hyprctl reload`.)

| Req | Requirement |
|-----|-------------|
| REQ-HOTPLUG-1 | `omarchy-hyprland-monitor-watch` SHALL NOT call `hyprctl reload` on `monitoradded>>` events |
| REQ-HOTPLUG-2 | T14 daemon polling loop MUST detect monitor changes within 2 seconds |
| REQ-HOTPLUG-3 | On detected change, daemon MUST re-apply layout for current lid state |
| REQ-HOTPLUG-4 | Waybar SHALL use `ext/workspaces` module (ext-workspace-v1 Wayland protocol, no socket2 IPC) |
| REQ-HOTPLUG-5 | Waybar SHALL run as systemd user service with Restart=always |
| REQ-HOTPLUG-6 | Waybar PID SHALL remain unchanged across workspace switches |

#### Scenario: Dock connected mid-session
- GIVEN laptop undocked, daemon polling
- WHEN dock with 3 externals connects
- THEN daemon detects change within 2s and re-applies layout

#### Scenario: Undock mid-session
- GIVEN laptop docked, daemon polling
- WHEN dock disconnects
- THEN daemon detects removal within 2s and applies correct layout

#### Scenario: Workspace switch with docked + lid closed
- GIVEN 3 external monitors docked + lid closed
- WHEN Super+1 is pressed
- THEN waybar PID is unchanged

#### Scenario: Rapid workspace cycling
- GIVEN docked configuration
- WHEN cycling Super+1/2/3/4/5 30 times
- THEN waybar has NOT restarted

#### Scenario: Workspace indicator updates without flicker
- GIVEN ext/workspaces module active
- WHEN workspace switch occurs
- THEN workspace indicator updates correctly
- AND no visual bar disappearance

## ADDED Requirements

### Requirement: SYS-WAYBAR — Waybar Managed by Systemd User Service

Waybar SHALL run as a systemd user service with automatic restart.

#### Scenario: Automatic restart on crash
- GIVEN waybar is running as systemd user service
- WHEN waybar crashes (SIGSEGV, unhandled exception, OOM)
- THEN systemd restarts waybar within 100ms
- AND user sees at most 500ms of blank bar

#### Scenario: Service lifecycle tied to graphical session
- GIVEN the graphical session is active
- WHEN the session ends (logout, crash, restart)
- THEN the waybar service stops cleanly and no orphaned process remains

#### Scenario: Stderr captured to journal
- GIVEN waybar is running as systemd service
- WHEN waybar emits output to stderr
- THEN output is captured in the systemd journal
- AND viewable via `journalctl --user -u waybar`

### Requirement: WS-MODULE — Workspace Display Uses ext-workspace-v1 Protocol

The waybar workspace indicator SHALL use ext-workspace-v1 Wayland protocol.

#### Scenario: ext/workspaces module active
- GIVEN waybar is configured with the ext/workspaces module
- WHEN waybar starts
- THEN it connects to the compositor's ext_workspace_manager_v1 global
- AND does NOT open a socket2 IPC connection for workspace data

#### Scenario: Workspace indicator on multi-monitor
- GIVEN 3 external monitors + eDP-1 are active
- WHEN ext/workspaces module is configured with all-outputs: true
- THEN workspaces from all monitors are visible in the bar
- AND workspace activation via click works correctly

#### Scenario: No crash on rapid workspace switch
- GIVEN ext/workspaces module is active
- WHEN user rapidly switches workspaces (Super+1/2/3/4/5 in sequence)
- THEN waybar PID remains stable
- AND no SIGSEGV or abnormal termination occurs

### Requirement: CLEANUP — Repository Cleanup After Waybar Fix

After the fix, the repository SHALL be cleaned of dead code.

#### Scenario: Flake input cleanup
- GIVEN the waybar-git overlay was reverted
- WHEN the waybar fix is complete
- THEN the unused waybar-src flake input is removed from flake.nix
- AND flake.lock is updated to reflect the removal

#### Scenario: Omarchy-nix reload fix durability
- GIVEN omarchy-nix origin/main has re-added monitoradded>> reload
- WHEN the waybar fix is deployed
- THEN the reload handler is removed from omarchy-hyprland-monitor-watch
- AND future omarchy-nix bumps do not re-introduce hyprctl reload churn
