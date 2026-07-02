# Delta Spec: t14-hyprctl-reload-causes-resets-on-workspace-switch

> **Base**: `openspec/specs/t14-monitor-layout/spec.md`
> **Scope**: nixos-hosts (T14) + omarchy-nix (monitor-watch, autostart)
> **Summary**: Eliminate all `hyprctl reload` calls from the monitor layout path; isolate workspaces 1-3 to eDP-1; capture waybar stderr for crash diagnosis.

---

## MODIFIED Requirements

### REQ-DAEMON-6 (CAP-DAEMON)

On start, the daemon MUST read lid state from `/proc/acpi/button/lid/LID*/state`, apply correct layout via `hyprctl keyword`, and persist to settings.conf. MUST NOT call `hyprctl reload`.

(Previously: …persist to settings.conf, and call `hyprctl reload`.)

#### Scenario: Boot with stale settings.conf
- GIVEN settings.conf has `$ENABLE_LAPTOP = 1` from last session
- AND lid is currently closed
- WHEN the daemon starts
- THEN it reads lid state ("closed") and applies y=0 layout via `hyprctl keyword`
- AND settings.conf is updated to `$ENABLE_LAPTOP =` empty
- AND no `hyprctl reload` is invoked

### REQ-HOTPLUG-1 (CAP-HOTPLUG)

On `monitoradded>>` or `monitoraddedv2>>` socket2 event, `omarchy-hyprland-monitor-watch` MUST NOT execute `hyprctl reload`. Monitor discovery is handled exclusively by the T14 daemon polling loop.

(Previously: …MUST execute `hyprctl reload`.)

#### Scenario: Dock connected mid-session
- GIVEN laptop is undocked, daemon is polling
- WHEN dock with 3 externals is connected
- THEN `omarchy-hyprland-monitor-watch` does NOT trigger `hyprctl reload`
- AND daemon detects monitor change within 2s via polling
- AND daemon re-applies layout for current lid state

### REQ-HOTPLUG-4 (CAP-HOTPLUG)

The daemon polling loop is the sole runtime monitor-change recovery mechanism. No `hyprctl reload` SHALL be triggered by any monitor hotplug event handler.

(Previously: The two layers (omarchy reload + daemon apply) are independent and idempotent.)

### REQ-COND-5 (CAP-CONDITIONAL)

Workspace rules for the 3 externals (mod-3 distribution) MUST be identical in both conditional branches. Workspaces 1-3 MUST be excluded from external monitor distribution (bound only via REQ-COND-6 for eDP-1 when enabled, or auto-assigned by Hyprland when eDP-1 is disabled).

(Previously: …MUST be identical in both conditional branches. No workspace exclusion.)

#### Scenario: Boot undocked, lid open
- GIVEN `$ENABLE_LAPTOP = 1` in settings.conf
- WHEN Hyprland starts
- THEN eDP-1 is active at `preferred, 4920x420, 1`
- AND workspaces 1-3 bind to eDP-1
- AND workspaces 4-20 distribute across 3 externals via mod-3

---

## ADDED Requirements

### REQ-DIAG-1 (CAP-DIAGNOSTICS — new)

Waybar launch in `autostart.nix` MUST redirect stderr to `$HOME/.cache/waybar-stderr.log` for crash diagnosis.

#### Scenario: Waybar crash captured
- GIVEN waybar is launched via autostart.nix
- WHEN waybar crashes during workspace switch
- AND systemd restarts waybar
- THEN stderr is appended to `$HOME/.cache/waybar-stderr.log`
- AND the log is available for post-crash analysis
