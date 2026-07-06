# Spec: greeter-script

> Domain: Greeter launch script for t14 Omarchy/Hyprland stack.
> Host: t14 (consumes the omarchy-nix generated config).
> Repository: omarchy-nix (the change lives in `modules/nixos/system.nix`).
> Source files: omarchy-nix `modules/nixos/system.nix`.

---

## REQ-GS-001: Greetd-regreet-start script as writeShellScriptBin

**What**: The greeter script SHALL be defined as `pkgs.writeShellScriptBin "greetd-regreet-start"` (a named derivation at `$out/bin/greetd-regreet-start`) and referenced from the Hyprland config as `exec-once = ${greeterScript}/bin/greetd-regreet-start`.

**Why**: The named derivation is PATH-installable, independently testable, and debuggable.

#### Scenario: Script is independently executable

- **Given** the greeter script is a named derivation
- **When** the system is built
- **Then** the script SHALL be located at a path like `/nix/store/<hash>-greetd-regreet-start/bin/greetd-regreet-start`

#### Scenario: Script is still referenced by Hyprland config

- **Given** the script is extracted to `writeShellScriptBin`
- **When** `/etc/greetd/hyprland.conf` is generated
- **Then** the `exec-once` line SHALL reference `${greeterScript}/bin/greetd-regreet-start`

#### Scenario: Script extraction does not change the Hyprland config structure

- **Given** the script is extracted from the config string
- **When** `/etc/greetd/hyprland.conf` is generated
- **Then** monitor declarations, cursor env vars, wayvnc exec-once, and input block SHALL remain unchanged

#### Scenario: Extraction does not change the script's behavior

- **Given** the script content
- **When** the greeter starts
- **Then** monitor selection SHALL work identically
- **And** internal panel disable SHALL work identically
- **And** regreet SHALL launch identically
- **And** `hyprctl dispatch exit` SHALL execute when regreet exits

---

## REQ-GS-002: Timeout on monitor enumeration polling loop

**What**: The monitor enumeration polling loop SHALL have a 2s total timeout (20 x 100ms) with explicit warning to stderr on timeout.

#### Scenario: Monitors enumerated within timeout

- **Given** Hyprland enumerates monitors within 2 seconds
- **When** the greeter script starts
- **Then** the polling loop SHALL detect monitors as soon as `hyprctl monitors -j` returns non-empty JSON
- **And** the script SHALL proceed without delay

#### Scenario: Monitors NOT enumerated within timeout

- **Given** Hyprland fails to enumerate monitors within 2 seconds
- **When** the polling loop reaches the timeout
- **Then** a warning message SHALL be printed to stderr
- **And** the script SHALL proceed with whatever display is available

---

## REQ-GS-003: Stderr logging for all phases

**What**: All phases of the greeter script SHALL log diagnostic messages to stderr.

#### Scenario: All phases log start/completion

- **Given** the greeter script runs normally
- **When** it completes
- **Then** stderr SHALL contain messages for each phase (monitor selection, panel disable, regreet launch)

#### Scenario: Non-critical hyprctl failures are logged, not hidden

- **Given** an external monitor is disconnected
- **When** `hyprctl keyword monitor` fails
- **Then** a warning SHALL be logged to stderr
- **And** the script SHALL continue

#### Scenario: Critical failures (regreet itself) are propagated

- **Given** regreet crashes or fails to start
- **When** `${pkgs.regreet}/bin/regreet` exits with non-zero status
- **Then** `hyprctl dispatch exit` SHALL still execute to clean up the Hyprland compositor

**Note**: greetd session stderr is not forwarded to systemd journal by default. Diagnostic logging may require `systemd-cat` or greetd logging config changes to be retrievable post-hoc.

---

## REQ-GS-004: Preserve keyboard layout switching at login screen

**What**: The Hyprland-as-greeter-compositor architecture SHALL continue to provide keyboard layout switching (Alt+Shift between es and latam) at the login screen.

#### Scenario: es/latam toggle works at greetd login screen

- **Given** the greeter Hyprland config includes `input { kb_layout = es,latam; kb_options = grp:alt_shift_toggle }`
- **When** a user presses Alt+Shift at the ReGreet login screen
- **Then** the keyboard layout SHALL toggle between es and latam

#### Scenario: ReGreet session behavior is unchanged

- **Given** the greeter script refactoring is applied
- **When** greetd starts the greeter session
- **Then** ReGreet SHALL render as a GTK application inside the Hyprland compositor
- **And** the greeter SHALL accept username/password input
- **And** the session SHALL launch `uwsm start hyprland-uwsm.desktop` upon successful authentication

---

## REQ-GS-005: Document escape-hatch VT fallback

**What**: The VT escape hatch SHALL be documented in `hosts/t14/home/omarchy.nix` for recovering from greeter failures.

#### Scenario: Escape hatch is documented

- **Given** the greeter script is refactored
- **When** a developer reads `hosts/t14/home/omarchy.nix`
- **Then** the VT fallback procedure SHALL be documented
- **And** the documentation SHALL include the exact kernel cmdline argument: `systemd.mask=greetd.service`

#### Scenario: VT fallback allows recovery after greeter failure

- **Given** the greeter Hyprland session fails to start
- **When** the user reboots with `systemd.mask=greetd.service` on the kernel cmdline
- **Then** greetd SHALL NOT start
- **And** the system SHALL present a VT login prompt
- **And** the user SHALL be able to log in, fix the configuration, and rebuild
