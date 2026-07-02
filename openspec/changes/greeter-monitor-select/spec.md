# Delta for greeter-monitor-select

## ADDED Requirements

### REQ-1: Target Monitor Identification

The system SHALL identify the target greeter monitor by matching `focusMonitor` (a configurable description substring) against the `description` field from `hyprctl monitors -j`. The system MUST retry enumeration until at least one monitor is reported.

#### SC-1.1: Docked with Lenovo present

- GIVEN t14 is docked with Lenovo G24-10 connected and `focusMonitor = "LEN G24"`
- WHEN the greeter startup script enumerates monitors
- THEN the monitor whose description contains `"LEN G24"` is identified as the target

#### SC-1.2: Enumeration retry

- GIVEN `hyprctl monitors -j` initially returns an empty list at exec-once
- WHEN the script polls for monitors
- THEN it retries until a monitor appears or the retry limit is reached

### REQ-2: Non-Target Monitor Disable

The system MUST disable all connected external monitors that do NOT match `focusMonitor` before launching ReGreet. The internal panel (eDP-*) is handled by existing logic and MUST NOT be disabled here. After disabling, the system MUST focus the target monitor.

#### SC-2.1: Multiple externals — only Lenovo stays

- GIVEN t14 docked with Lenovo G24-10, AOC 24P1W1, and AOC 2470W connected
- AND `focusMonitor = "LEN G24"`
- WHEN the script runs
- THEN AOC monitors are disabled, Lenovo remains enabled and focused
- AND ReGreet launches on Lenovo only

#### SC-2.2: Docked but Lenovo NOT connected — fallback

- GIVEN t14 docked with externals connected but none match `"LEN G24"`
- WHEN the script runs
- THEN selection phase is skipped, existing eDP-1 disable logic runs
- AND ReGreet launches using default behavior

### REQ-3: Graceful Degradation

The system MUST NOT prevent ReGreet from launching if monitor selection fails. If `hyprctl` or `jq` is unavailable, errors, or produces unparseable output, the system MUST skip selection and proceed to the existing launch sequence.

#### SC-3.1: hyprctl fails or times out

- GIVEN `hyprctl monitors -j` returns non-zero exit or empty output after all retries
- WHEN the script runs
- THEN selection is skipped, ReGreet launches via existing behavior

#### SC-3.2: jq fails or missing

- GIVEN `jq` is not in PATH or fails to parse monitor JSON
- WHEN the script attempts target matching
- THEN selection is skipped, ReGreet launches via existing behavior

### REQ-4: Backward Compatibility

When `focusMonitor` is empty (the default), the system MUST skip the selection phase entirely. The greeter sequence MUST behave identically to pre-change behavior.

#### SC-4.1: Empty focusMonitor

- GIVEN `focusMonitor = ""` (default)
- WHEN the script runs
- THEN no selection occurs beyond existing eDP-1 logic
- AND ReGreet launches unchanged on all hosts

#### SC-4.2: Undocked — only eDP-1

- GIVEN t14 undocked with only eDP-1 connected and `focusMonitor = "LEN G24"`
- WHEN the script runs
- THEN no external matches, selection is skipped
- AND eDP-1 remains enabled, ReGreet launches on eDP-1

### REQ-5: Host Isolation

`focusMonitor` MAY be set on any host but MUST only produce effects on hosts whose greeter script implements selection. On other hosts the option has no effect.

#### SC-5.1: focusMonitor on non-t14 host

- GIVEN a non-t14 host (e.g., rog) with `focusMonitor` set
- WHEN the greeter starts
- THEN selection does not execute, greeter behaves as before