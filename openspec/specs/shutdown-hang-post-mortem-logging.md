# Specification: Shutdown Hang Post-Mortem Logging

> **Archived**: 2026-06-26
> **Status**: Implemented, verified (PASS with 3 minor warnings), archived.
> **Note**: This spec was merged from the delta spec at archive time. The following spec/implementation mismatches were identified during verification and are NOT corrected here (they reflect the original specification — the implementation deviates intentionally):
> 1. **File extensions**: Spec says `.txt` (e.g., `journalctl-b.txt`), implementation uses `.log`
> 2. **Service dependency**: Spec/design say `requiredBy` for rog-shutdown.service, implementation uses `wantedBy` (soft dep is preferred for best-effort ACPI calls — won't block shutdown)
> 3. **Ordering directives**: Spec/design omit `After=shutdown.target` and `Before=shutdown.target` on shutdown-debug-capture; implementation includes both (systemd accepts them without error)
> See `sdd/shutdown-hang-post-mortem-logging/archive.md` for full archive report.

## New Capability: `shutdown-debug-capture`

### Requirement: Diagnostic Snapshot Service

The system MUST provide a systemd oneshot service (`shutdown-debug-capture`) that captures system state before poweroff/reboot/halt and writes output to `/var/log/shutdown-debug/{boot-id}/`.

#### Scenario: Normal shutdown captures diagnostics

- GIVEN the `shutdown-debug-capture` service is active
- WHEN the system initiates poweroff
- THEN a directory `/var/log/shutdown-debug/{boot-id}/` is created
- AND the following files are written: `journalctl-b.txt`, `dmesg.txt`, `pstree.txt`, `ps.txt`, `lsmod.txt`, `mount.txt`, `df.txt`, `lsof.txt`, `cmdline.txt`, `acpi-wakeup.txt`, `sensors.txt`
- AND `nvidia-smi.txt` is written only if `nvidia-smi` binary exists

#### Scenario: Service does not block shutdown

- GIVEN any diagnostic command fails or hangs
- WHEN the service executes
- THEN each command MUST use `|| true` to prevent failure propagation
- AND `TimeoutStopSec=10` MUST force termination if exceeded
- AND `sync` MUST flush all writes before service exit

#### Scenario: Logs persist across reboots

- GIVEN the system has shut down at least once
- WHEN the system boots again
- THEN `/var/log/shutdown-debug/` MUST contain previous boot's diagnostic directory
- AND the directory MUST survive reboot without manual intervention

---

## Delta: `boot-settings`

### Requirement: Optional Diagnostic Kernel Logging (ADDED)

The system MUST expose a boolean option `boot-settings.includeDiagLogging` (default: `false`). When `true`, the system MUST append `loglevel=7`, `systemd.log_level=debug`, `systemd.log_target=console` to kernel boot parameters.

#### Scenario: Diagnostic logging enabled

- GIVEN `boot-settings.includeDiagLogging = true`
- WHEN the system boots
- THEN `/proc/cmdline` contains `loglevel=7 systemd.log_level=debug systemd.log_target=console`

#### Scenario: Diagnostic logging disabled (default)

- GIVEN `boot-settings.includeDiagLogging = false` (or unset)
- WHEN the system boots
- THEN `/proc/cmdline` does NOT contain `loglevel=7`

#### Scenario: Thinkcentre unaffected

- GIVEN the `thinkcentre` host configuration
- WHEN evaluated
- THEN `boot-settings.includeDiagLogging` is NOT set to `true`

---

## Delta: `shutdown-fix.nix`

### Requirement: Persistent Journal Storage (ADDED)

The system MUST configure journald with `Storage=persistent`, `SystemMaxUse=500M`, and `MaxRetentionSec=2week`.

#### Scenario: Journal persists across reboots

- GIVEN journald is configured with `Storage=persistent`
- WHEN the system reboots
- THEN `journalctl --list-boots` shows entries from previous boots

#### Scenario: Journal size is bounded

- GIVEN journald is configured with `SystemMaxUse=500M`
- WHEN journal data exceeds 500M
- THEN journald prunes oldest entries to stay within limit

#### Scenario: Watchdog disable preserved

- GIVEN `shutdown-fix.nix` has existing watchdog-disable behavior
- WHEN journald config is added
- THEN the watchdog-disable configuration is NOT removed or altered

---

## Delta: `rog-shutdown.nix`

### Requirement: ACPI S5 Service Ordering Fix (MODIFIED)

The `rog-shutdown.service` MUST use `requiredBy = [ "poweroff.target" "reboot.target" "halt.target" ]` instead of `before = [ "poweroff.target" ]`. It MUST set `TimeoutStartSec=0` and `TimeoutStopSec=10`. The `sync && echo _SI._SST > /proc/acpi/call` script MUST be retained.

(Previously: used `before = [ "poweroff.target" ]` which fired ACPI S5 before other services stopped)

#### Scenario: ACPI S5 fires after all services stop

- GIVEN the system initiates poweroff
- WHEN `rog-shutdown.service` runs
- THEN it executes AFTER `systemd-shutdown.service` and other stopped services
- AND `sync && echo _SI._SST > /proc/acpi/call` runs successfully

#### Scenario: Service does not hang indefinitely

- GIVEN `rog-shutdown.service` is running
- WHEN 10 seconds elapse without completion
- THEN systemd forcibly terminates the service

#### Scenario: Works for all shutdown targets

- GIVEN the system initiates reboot OR halt (not just poweroff)
- WHEN targets are evaluated
- THEN `rog-shutdown.service` is required by `reboot.target` and `halt.target`

---

## Delta: `hosts/rog/default.nix`

### Requirement: Import and Enable Diagnostic Logging (ADDED)

The `rog` host MUST import `../../modules/base/shutdown-debug.nix` and set `boot-settings.includeDiagLogging = true`.

#### Scenario: Module is imported

- GIVEN the `rog` host configuration is evaluated
- WHEN imports are resolved
- THEN `shutdown-debug.nix` is in the module list

#### Scenario: Diagnostic logging is active

- GIVEN the `rog` host configuration
- WHEN boot parameters are generated
- THEN `loglevel=7 systemd.log_level=debug systemd.log_target=console` are present
