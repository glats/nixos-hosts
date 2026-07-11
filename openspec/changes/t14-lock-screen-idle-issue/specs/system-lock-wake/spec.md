# system-lock-wake Specification

## Purpose

Unified lock/wake lifecycle for Hyprland idle lock, manual lock, and sleep-triggered lock. The `omarchy-system-lock` script gains `OMARCHY_LOCK_ONLY` mode for sleep paths; a new `omarchy-system-wake` script restores display and keyboard brightness after unlock.

## Requirements

### Requirement: omarchy-system-lock supports OMARCHY_LOCK_ONLY environment variable

The `omarchy-system-lock` script SHALL accept an `OMARCHY_LOCK_ONLY` environment variable. When set to `true`, the script SHALL lock the session (hyprlock, keyboard reset, 1password lock) but MUST NOT modify display power or keyboard backlight state. When unset or any other value, the script SHALL execute with full side effects (current behavior).

#### Scenario: Sleep-triggered lock (OMARCHY_LOCK_ONLY=true)

- GIVEN the system is about to suspend
- WHEN `OMARCHY_LOCK_ONLY=true omarchy-system-lock` executes
- THEN the session is locked (hyprlock + keyboard reset + 1password lock)
- AND display power state is NOT modified
- AND keyboard backlight is NOT modified

#### Scenario: Idle or manual lock (OMARCHY_LOCK_ONLY unset)

- GIVEN the system is idle or the user manually locks
- WHEN `omarchy-system-lock` executes (OMARCHY_LOCK_ONLY unset or absent)
- THEN the session is locked with all side effects (current behavior preserved)

### Requirement: before_sleep_cmd uses OMARCHY_LOCK_ONLY

The hypridle `before_sleep_cmd` SHALL invoke `OMARCHY_LOCK_ONLY=true omarchy-system-lock`. It MUST NOT use `loginctl lock-session`.

#### Scenario: Before sleep uses unified lock path

- GIVEN the system is about to sleep
- WHEN hypridle triggers `before_sleep_cmd`
- THEN lock uses `omarchy-system-lock` (with 1password locking + keyboard reset)
- AND OMARCHY_LOCK_ONLY prevents display state changes

### Requirement: omarchy-system-wake restores display and keyboard after unlock

A new script `omarchy-system-wake` SHALL restore display brightness via `brightnessctl -r` and SHALL turn on displays via `hyprctl dispatch dpms on`.

#### Scenario: Wake after idle lock

- GIVEN the session was locked by hypridle
- WHEN the user unlocks
- THEN lock listener `on-resume` triggers `omarchy-system-wake`
- AND display brightness is restored to pre-lock levels
- AND displays are turned on

#### Scenario: Wake after sleep resume

- GIVEN the system resumes from sleep and user unlocks
- WHEN `omarchy-system-wake` executes
- THEN display brightness and DPMS state are restored

### Requirement: Lock listener uses omarchy-system-lock with on-resume

The hypridle lock listener (timeout 151s) SHALL use `omarchy-system-lock` as `on-timeout` and `omarchy-system-wake` as `on-resume`.

#### Scenario: Unified lock path across all triggers

- GIVEN any lock trigger (idle, sleep, manual keybind)
- WHEN the lock activates
- THEN `omarchy-system-lock` is invoked
- AND 1password is locked and keyboard is reset regardless of trigger

### Requirement: T14 host config removes lock listener override

The t14 host configuration (`hosts/t14/home/omarchy.nix`) MUST remove the `services.hypridle.settings` override block because the flag-based toggle makes custom lock timeout unnecessary. The host SHALL use upstream omarchy-nix hypridle defaults.

#### Scenario: T14 uses upstream hypridle defaults

- GIVEN the t14 host configuration is evaluated
- WHEN hypridle settings are resolved
- THEN lock timeout is the upstream default (151s)
- AND no host-specific lock listener override exists
- AND the `idle-off` flag mechanism controls behavior instead
