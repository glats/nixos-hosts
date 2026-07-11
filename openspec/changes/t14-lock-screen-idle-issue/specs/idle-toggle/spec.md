# idle-toggle Specification

## Purpose

Flag-based idle disarm mechanism replacing hypridle process kill/start. A toggle script writes/removes an `idle-off` flag file; hypridle listeners check this flag before firing, providing "caffeine" behavior without stopping the idle daemon.

## Requirements

### Requirement: Toggle script creates and removes idle-off flag

The `omarchy-toggle-idle` script SHALL toggle the flag file `~/.local/state/omarchy/toggles/idle-off` on each invocation. It MUST NOT interact with systemctl (no hypridle stop/start). It MUST NOT manage the `screensaver-off` flag.

#### Scenario: Enable idle (arm caffeine mode)

- GIVEN the `idle-off` flag does not exist
- WHEN the user invokes `omarchy-toggle-idle`
- THEN the flag file is created
- AND a notification "Stop locking computer when idle" is shown
- AND any running screensaver is killed
- AND waybar is refreshed (SIGRTMIN+9)

#### Scenario: Disable idle (disarm caffeine mode)

- GIVEN the `idle-off` flag exists
- WHEN the user invokes `omarchy-toggle-idle`
- THEN the flag file is removed
- AND a notification "Now locking computer when idle" is shown
- AND waybar is refreshed (SIGRTMIN+9)

### Requirement: Hypridle listeners check idle-off flag before firing

Each hypridle listener `on-timeout` command SHALL be wrapped with `omarchy-toggle-enabled idle-off` guard. When the flag exists, no listener action (screensaver, lock, DPMS) SHALL execute.

#### Scenario: Idle-off flag present — no listener fires

- GIVEN the `idle-off` flag exists
- WHEN hypridle reaches any timeout (screensaver, lock, DPMS)
- THEN the `on-timeout` command SHALL NOT execute

#### Scenario: Idle-off flag absent — listeners fire normally

- GIVEN the `idle-off` flag does not exist
- WHEN hypridle reaches screensaver timeout (150s)
- THEN the screensaver launches
- WHEN hypridle reaches lock timeout (151s)
- THEN lock activates via `omarchy-system-lock`
- WHEN hypridle reaches DPMS timeout (330s)
- THEN display turns off

### Requirement: ExecStartPre preserves idle-off flag across hypridle restarts

The hypridle ExecStartPre SHALL clear `screensaver-off` but MUST NOT clear `idle-off`. The idle-off flag SHALL persist across daemon restarts (e.g., NixOS rebuilds).

#### Scenario: Idle-off survives rebuild

- GIVEN the `idle-off` flag exists
- WHEN hypridle restarts during a NixOS rebuild
- THEN the `idle-off` flag still exists
- AND listeners continue checking it

#### Scenario: Screensaver-off still cleared on restart

- GIVEN the `screensaver-off` flag exists
- WHEN hypridle restarts
- THEN the `screensaver-off` flag is removed (existing behavior preserved)
