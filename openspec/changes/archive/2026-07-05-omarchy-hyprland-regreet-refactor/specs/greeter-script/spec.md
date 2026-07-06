# Delta Spec: greeter-script

> Domain: Greeter launch script extraction from embedded bash to standalone script.
> Host: t14 (consumes the omarchy-nix generated config).
> Repository: omarchy-nix (the change lives in `modules/nixos/system.nix`).
> Source files: omarchy-nix `modules/nixos/system.nix` (`environment.etc."greetd/hyprland.conf".text` block).

---

## MODIFIED Requirements

### REQ-GS-001: Extract greetd-regreet-start script into writeShellScriptBin

**What**: The embedded bash script in `environment.etc."greetd/hyprland.conf".text` (the `greeterScript` let-binding, currently ~40 lines) SHALL be extracted from the `let greeterScript = pkgs.writeShellScript ...` expression inside the config string interpolation into a standalone `pkgs.writeShellScriptBin` (or equivalent named derivation) at the top level of the module.

**Why**: The current implementation defines the script inline inside a string interpolation (`let greeterScript = ... in ''...${greeterScript}...''`). This means:
1. The script is unnamed — it appears as `writeShellScript-XXXXXX` in the nix store, making it hard to identify
2. The entire config string is invalidated and rebuilt if any part of the script changes
3. Error handling is implicit (stderr mostly redirected to `/dev/null`)
4. The script is not independently testable or debuggable

After extraction, the script SHALL:
- Be a named derivation (e.g., `greetd-regreet-start`) visible in `ls /nix/store` or `nix path-info`
- Be independently callable from a shell for debugging (`/nix/store/.../bin/greetd-regreet-start`)
- Remain referenced by exec-once in the Hyprland config (`exec-once = ${greeterScript}/bin/greetd-regreet-start`)
- Preserve the same behavior for monitor selection, internal panel disable, and greeter launch

**Migration**: Move the script content from the `let greeterScript = ...` binding to a top-level `pkgs.writeShellScriptBin "greetd-regreet-start"`, then reference `${greeterScript}/bin/greetd-regreet-start` in the Hyprland config string.

#### Scenario: Script is independently executable

- **Given** the greeter script is extracted to a named derivation
- **When** the system is built
- **Then** the script SHALL be located at a path like `/nix/store/<hash>-greetd-regreet-start/bin/greetd-regreet-start`
- **And** SHALL be invokable directly for debugging: `/nix/store/<hash>-greetd-regreet-start/bin/greetd-regreet-start`

#### Scenario: Script is still referenced by Hyprland config

- **Given** the script is extracted
- **When** `environment.etc."greetd/hyprland.conf"` is generated
- **Then** the `exec-once` line SHALL reference `${greeterScript}/bin/greetd-regreet-start`
- **And** greetd SHALL invoke the same script path as before (from the greeter user's perspective)

#### Scenario: Script extraction does not change the Hyprland config structure

- **Given** the script is extracted from the config string
- **When** `/etc/greetd/hyprland.conf` is generated
- **Then** the monitor declarations, cursor env vars, wayvnc exec-once, and input block SHALL remain unchanged
- **And** only the exec-once line SHALL change (from inline derivation path to `${greeterScript}/bin/greetd-regreet-start`)
- **And** `misc.disable_hyprland_logo`, `disable_splash_rendering`, and `disable_hyprland_guiutils_check` SHALL remain unchanged

#### Scenario: Extraction does not change the script's behavior

- **Given** the script content is identical to the current embedded version (before timeout/error handling additions)
- **When** the greeter starts
- **Then** monitor selection SHALL work identically (10x100ms polling loop, jq-based matching on `focusMonitor`)
- **And** internal panel disable SHALL work identically (DRM connector status reads)
- **And** regreet SHALL launch identically
- **And** `hyprctl dispatch exit` SHALL execute when regreet exits

---

## ADDED Requirements

### REQ-GS-002: Add timeout to monitor enumeration polling loop

**What**: The monitor enumeration polling loop (`for _ in $(seq 1 10); do hyprctl monitors -j | jq -e 'length > 0'; sleep 0.1; done`) SHALL gain a maximum total wait time with explicit timeout handling.

**Rationale**: The current loop polls up to 10 times at 100ms intervals (total 1 second). If monitors are never enumerated (e.g., KMS failure), the script proceeds silently without monitors. Adding a timeout guard makes the failure mode explicit.

**Implementation**: The script SHALL:
1. Track elapsed time using a start timestamp (`date +%s.%N` or `$SECONDS`)
2. If no monitors are found within 2 seconds total (increased from the current implicit ~1s), log a warning to stderr and proceed with the built-in display only
3. The timeout value (`2`) SHALL be configurable via a script-level variable for future tuning

#### Scenario: Monitors enumerated within timeout

- **Given** Hyprland enumerates monitors within 2 seconds of starting
- **When** the greeter script starts
- **Then** the polling loop SHALL detect monitors as soon as `hyprctl monitors -j` returns non-empty JSON
- **And** the script SHALL proceed to monitor selection without delay

#### Scenario: Monitors NOT enumerated within timeout

- **Given** Hyprland fails to enumerate monitors within 2 seconds
- **When** the polling loop reaches the timeout
- **Then** a warning message SHALL be printed to stderr (e.g., "WARNING: no monitors detected after 2s, continuing with built-in display only")
- **And** the `focusMonitor` phase SHALL be skipped (no target monitor to select)
- **And** the script SHALL proceed to Phase 2 (internal panel disable) and Phase 3 (launch regreet)
- **And** regreet SHALL render on whatever display Hyprland has available

#### Scenario: Script exits non-zero on monitor failure (optional enhancement)

- **Given** monitor enumeration times out AND no display is available
- **When** the script reaches the end of Phase 1 with no usable monitors
- **Then** the script MAY exit with a non-zero status code
- **And** a clear error message SHALL be logged to stderr
- **And** the system SHALL remain recoverable via the VT escape hatch (`systemd.mask=greetd.service`)

### REQ-GS-003: Add stderr logging for all phases

**What**: All phases of the greeter script SHALL log diagnostic messages to stderr, replacing the current pattern of `/dev/null 2>&1` redirections that discard error output.

**Rationale**: The current script redirects most hyprctl and jq stderr to `/dev/null` (e.g., `hyprctl monitors -j 2>/dev/null | jq ... >/dev/null 2>&1`). While this suppresses noise from Hyprland IPC startup races, it also hides real failures. A structured logging approach preserves debuggability while still handling transient errors gracefully.

**Implementation**:
1. Each phase SHALL log a start message to stderr (e.g., `echo "greetd-regreet-start: Phase 1 — monitor enumeration" >&2`)
2. `hyprctl` and `jq` commands SHALL keep stderr visible (remove `2>/dev/null` redirections)
3. Non-critical failures (e.g., `hyprctl keyword monitor X,disable` failing because monitor X doesn't exist) SHALL log a warning to stderr instead of silently discarding
4. Each phase SHALL log a completion message (e.g., `echo "greetd-regreet-start: Phase 1 — done" >&2`)

#### Scenario: All phases log start/completion

- **Given** the greeter script runs normally
- **When** it completes
- **Then** the systemd journal (or greetd log) SHALL contain messages for each phase:
  - Phase 1 start and completion (monitor selection)
  - Phase 2 start and completion (internal panel disable)
  - Phase 3 start (launching regreet) — no completion message because regreet blocks

#### Scenario: Non-critical hyprctl failures are logged, not hidden

- **Given** an external monitor from the `monitors` list is disconnected
- **When** `hyprctl keyword monitor "$m,disable"` fails because the monitor doesn't exist
- **Then** a warning SHALL be logged to stderr (e.g., "WARNING: could not disable monitor $m (may be disconnected)")
- **And** the script SHALL continue to the next monitor (not abort)

#### Scenario: Critical failures (regreet itself) are propagated

- **Given** the regreet binary crashes or fails to start
- **When** `${pkgs.regreet}/bin/regreet` exits with non-zero status
- **Then** the script SHALL log the exit code to stderr
- **And** the script SHALL still execute `hyprctl dispatch exit` to clean up the Hyprland compositor
- **And** the exit code SHALL be preserved for greetd to detect

### REQ-GS-004: Preserve keyboard layout switching at login screen

**What**: The Hyprland-as-greeter-compositor architecture SHALL continue to provide keyboard layout switching (Alt+Shift between es and latam) at the login screen, as configured via `omarchy.greeter.keyboard.layouts` and `omarchy.greeter.keyboard.options`.

**Rationale**: This is the primary reason Hyprland is used instead of cage for the greeter. The keyboard layout toggle is a hard requirement for this bilingual host. The refactored script MUST NOT remove or break this capability.

#### Scenario: es/latam toggle works at greetd login screen

- **Given** the greeter Hyprland config includes `input { kb_layout = es,latam; kb_options = grp:alt_shift_toggle }`
- **When** a user presses Alt+Shift at the ReGreet login screen
- **Then** the keyboard layout SHALL toggle between es and latam
- **And** the ReGreet password field SHALL accept input in the active layout

#### Scenario: ReGreet session behavior is unchanged

- **Given** the greeter script refactoring is applied
- **When** greetd starts the greeter session
- **Then** ReGreet SHALL render as a GTK application inside the Hyprland compositor
- **And** the greeter SHALL accept username/password input
- **And** the session SHALL launch `uwsm start hyprland-uwsm.desktop` upon successful authentication
- **And** the greeter Hyprland session SHALL exit cleanly after `hyprctl dispatch exit`

### REQ-GS-005: Document escape-hatch VT fallback

**What**: A comment SHALL be added to the greeter script source (in the system.nix file) and to `hosts/t14/home/omarchy.nix` documenting the VT escape hatch for recovering from greeter failures.

**Rationale**: The greeter is the only path to graphical login. If the refactored script has a bug, the user must be able to recover. The documented procedure is: append `systemd.mask=greetd.service` to the kernel command line at the bootloader, which skips greetd and drops to a VT login prompt.

#### Scenario: Escape hatch is documented in multiple locations

- **Given** the greeter script is extracted and refactored
- **When** a developer reads either `omarchy-nix/modules/nixos/system.nix` or `hosts/t14/home/omarchy.nix`
- **Then** at least one of these files SHALL document the VT fallback procedure
- **And** the documentation SHALL include the exact kernel cmdline argument: `systemd.mask=greetd.service`
- **And** it SHALL note that the console keymap is preserved (VT login works with the system keymap)

#### Scenario: VT fallback allows recovery after greeter failure

- **Given** the greeter Hyprland session fails to start (e.g., config syntax error)
- **When** the user reboots with `systemd.mask=greetd.service` on the kernel cmdline
- **Then** greetd SHALL NOT start
- **And** the system SHALL present a VT login prompt
- **And** the user SHALL be able to log in, fix the configuration, and rebuild
