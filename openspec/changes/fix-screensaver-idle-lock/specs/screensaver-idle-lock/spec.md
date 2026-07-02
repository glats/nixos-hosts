# Screensaver Idle-Lock Specification

## Purpose

Defines the behavior of the Omarchy/Hyprland screensaver and idle-lock system on t14, covering the caffeine toggle (`omarchy-toggle-idle`) and multi-monitor screensaver launch (`omarchy-launch-screensaver`).

## Requirements

### Requirement: Toggle Idle Disables Screensaver

When the user presses `Super+Ctrl+I`, the system MUST atomically disable BOTH hypridle timers AND the screensaver launch mechanism. Re-enabling MUST restore both.

The `omarchy-toggle-idle` script SHALL create the `screensaver-off` flag file (`~/.local/state/omarchy/toggles/screensaver-off`) when stopping idle, and SHALL remove it when starting idle.

#### Scenario: Toggle off disables screensaver

- GIVEN hypridle is running and no `screensaver-off` flag exists
- WHEN the user presses `Super+Ctrl+I`
- THEN hypridle service is stopped
- AND the `screensaver-off` flag file is created
- AND the waybar idle indicator is refreshed

#### Scenario: Screensaver does not launch while idle is toggled off

- GIVEN hypridle is stopped and the `screensaver-off` flag exists
- WHEN the screensaver timeout would have fired (150s idle)
- THEN `omarchy-launch-screensaver` detects the flag and exits without launching

#### Scenario: Toggle on restores screensaver and idle

- GIVEN hypridle is stopped and the `screensaver-off` flag exists
- WHEN the user presses `Super+Ctrl+I` again
- THEN the `screensaver-off` flag file is removed
- AND hypridle service is started
- AND the waybar idle indicator is refreshed

### Requirement: Screensaver Covers All Monitors

The screensaver MUST appear fullscreen on ALL connected monitors. Each monitor MUST be focused and allowed to settle before the terminal spawns. Unreachable monitors MUST be skipped gracefully with a notification.

#### Scenario: All monitors receive screensaver

- GIVEN 4 monitors connected (eDP-1 + 3 external)
- WHEN `omarchy-launch-screensaver` is invoked
- THEN each monitor is focused in sequence
- AND a fullscreen terminal window spawns on each monitor
- AND the originally focused monitor is restored after the loop

#### Scenario: Unreachable monitor is skipped

- GIVEN a monitor name that `focusmonitor` cannot resolve (e.g., during hot-plug transient)
- WHEN `omarchy-launch-screensaver` iterates to that monitor
- THEN a low-priority notification is shown: "Could not focus {monitor} — skipping"
- AND the iteration continues to the next monitor
- AND the screensaver launches on all reachable monitors

#### Scenario: Focus settles before terminal spawn

- GIVEN a monitor has been successfully focused
- WHEN the script proceeds to spawn the terminal
- THEN at least 300ms elapses between `focusmonitor` and `dispatch exec`
- AND the terminal window receives the fullscreen window rule on the correct monitor

#### Scenario: All spawns complete before lock release

- GIVEN the monitor iteration loop has finished
- WHEN the script exits
- THEN all background `dispatch exec` processes have been waited on
- AND the flock is released only after all terminal windows have spawned
