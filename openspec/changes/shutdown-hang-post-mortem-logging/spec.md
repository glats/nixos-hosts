# Delta Specs: Shutdown Hang — ASUS WMI Isolation + Late Shutdown Hook (Iteration 2)

> **Iteration**: 2 (full re-spec after review checkpoint #1629)
> **Supersedes**: iteration 1 spec entirely
> **Established baseline**: `shutdown-debug-capture`, `boot-settings.includeDiagLogging`,
> and persistent journal storage from iteration 1 are already deployed and treated as
> read-only infrastructure. They are not re-specified here; they remain in place as
> verification evidence for the new requirements below.

---

## New Capability: `rog-poweroff-workaround`

### REQ-1: Late Shutdown Hook Module

A new NixOS module (`modules/hardware/rog-poweroff-workaround.nix`) MUST be created.
The module MUST expose a boolean option `hardware.rog.poweroffWorkaround.enable` with
default `false`. All behaviour in this module MUST be gated behind that option.

#### Scenario 1-A: Option defaults to disabled

- GIVEN the `rog-poweroff-workaround` module is imported
- WHEN `hardware.rog.poweroffWorkaround.enable` is not set
- THEN no hook script, no ramfs contents, and no unit stubs are installed
- AND the evaluated configuration for any other host (thinkcentre, t14, mact2) is
  unaffected if the module is absent from their imports

---

### REQ-2: Hook Delivery via `systemd.shutdownRamfs.contents`

When the option is enabled, the module MUST deliver the hook script via
`systemd.shutdownRamfs.contents."/shutdown/rog-poweroff".source` (or the equivalent
NixOS attribute path verified to land the file at
`/usr/lib/systemd/system-shutdown/rog-poweroff` at runtime).

The installed file MUST be executable.

#### Scenario 2-A: Hook file lands at the correct path after rebuild

- GIVEN `hardware.rog.poweroffWorkaround.enable = true`
- WHEN the system is rebuilt
- THEN `/usr/lib/systemd/system-shutdown/rog-poweroff` exists on the running system
- AND the file has execute permissions (`-rwxr-xr-x` or equivalent)

#### Scenario 2-B: Hook is absent when option is false

- GIVEN `hardware.rog.poweroffWorkaround.enable = false`
- WHEN the system is rebuilt
- THEN `/usr/lib/systemd/system-shutdown/rog-poweroff` does NOT exist

---

### REQ-3: Hook Script — ASUS WMI Module Unload

The hook script MUST attempt to unload the following kernel modules in order:
`asus_nb_wmi`, `asus_armoury`, `asus_wmi`, `acpi_call`.

Each unload invocation MUST be wrapped with `|| true` so that a failure (module
already absent, busy, or unknown) does NOT stop script execution.

The `rmmod` binary MUST be referenced by absolute Nix store path or resolved from
the environment available in the shutdown ramfs; it MUST NOT assume `/usr/bin/rmmod`.

#### Scenario 3-A: Module unload is best-effort

- GIVEN one or more of the target modules are not loaded at shutdown time
- WHEN the hook script executes
- THEN `rmmod` returns a non-zero exit code for those modules
- AND the script continues to the next command
- AND shutdown proceeds to completion without blocking

#### Scenario 3-B: Hook does not introduce a new shutdown block

- GIVEN any `rmmod` call hangs (kernel bug, module locked)
- WHEN the hook runs
- THEN the `|| true` suffix MUST prevent the script from waiting indefinitely
  (the caller — `systemd-shutdown` — will kill the hook if it exceeds its budget)

---

### REQ-4: Hook Script — ACPI `_SI._SST` Fallback

After the module unload sequence, the hook MUST:

1. Reload `acpi_call` via `modprobe acpi_call` (best-effort, `|| true`)
2. Write the ACPI sleep-state notification: `echo '\_SI._SST' > /proc/acpi/call`
   (best-effort, `|| true`)

All three invocations (`modprobe` and the `echo`) MUST redirect stderr to `/dev/null`
before the `|| true` so that error output does not reach the console log.

#### Scenario 4-A: ACPI call fires after modules are unloaded

- GIVEN `asus_wmi` and related modules have been unloaded in REQ-3
- WHEN the hook script reaches the `modprobe acpi_call` + ACPI write step
- THEN `acpi_call` is loaded (or was already present)
- AND `\_SI._SST` is written to `/proc/acpi/call`
- AND the script exits 0

#### Scenario 4-B: ACPI call path missing (non-rog host or kernel without acpi_call)

- GIVEN `/proc/acpi/call` does not exist
- WHEN the hook script executes
- THEN the `echo '...' > /proc/acpi/call || true` fails silently
- AND the script exits 0
- AND the machine proceeds to poweroff

---

### REQ-5: Hook Script — No Blocking Guarantee

Every command in the hook script MUST be followed by `|| true`. The script MUST NOT
contain any `set -e` directive or equivalent that would cause early exit on failure.

#### Scenario 5-A: Complete script walk-through without blocking

- GIVEN all four module unloads fail AND modprobe fails AND the ACPI write fails
- WHEN the hook script runs end-to-end
- THEN the script exits 0
- AND no output is written to stdout or stderr that would delay `systemd-shutdown`

---

### REQ-6: Breadcrumb Evidence File

The hook script MUST write a sentinel file `/run/shutdown-hook-ran` (with the value
`ok\n` or equivalent non-empty content) as its LAST step before exit.

Because `/run` is a tmpfs that does not persist across reboots, this sentinel is only
meaningful when checked via the shutdown-debug log: the `lsof`/`mount`/`pstree`
diagnostics captured by `shutdown-debug-capture` (iteration 1 baseline) run before
the hook, so the sentinel's presence in the next boot's diagnostic snapshot would be
anomalous. The sentinel's real purpose is to confirm hook execution DURING the
shutdown session — e.g., via a `journalctl -b -1` lookup or via the debug capture's
`lsmod.log` difference.

#### Scenario 6-A: Sentinel written on hook execution

- GIVEN `hardware.rog.poweroffWorkaround.enable = true`
- WHEN a shutdown completes and the system reboots
- THEN the diagnostic snapshot at `/var/log/shutdown-debug/{prior-boot-id}/lsmod.log`
  will show `acpi_call` absent from the loaded modules (proving unload ran)
- AND a post-shutdown check can confirm `/run/shutdown-hook-ran` existed during that
  shutdown session if the system did not actually power off

---

## Delta: `asus-fan-control.nix` (MODIFIED)

### REQ-7: Clean Disable Path for Fan-Control Service

`modules/hardware/asus-fan-control.nix` already wraps its `systemd.services.asus-fan-control`
block inside `lib.mkIf config.services.asus-fan-control-custom.enable`. The existing
`enable` option defaults to `true`.

The module MUST be verified to emit no service definition whatsoever when
`services.asus-fan-control-custom.enable = false`. Specifically: the unit file MUST
be absent from the systemd unit graph (not merely inactive) so it cannot appear as a
dependency in the shutdown sequence.

No code change is required if the existing `lib.mkIf` guard already satisfies this
requirement. If a code change is required to achieve full unit absence, it MUST be
made.

#### Scenario 7-A: Service absent from graph when disabled

- GIVEN `services.asus-fan-control-custom.enable = false`
- WHEN the NixOS configuration is evaluated
- THEN `systemd.services.asus-fan-control` is NOT defined in the output
- AND `systemctl list-units --all | grep asus-fan-control` returns no output on the
  running system

#### Scenario 7-B: Default behavior unchanged

- GIVEN `services.asus-fan-control-custom.enable` is not set (defaults to `true`)
- WHEN the NixOS configuration is evaluated
- THEN `systemd.services.asus-fan-control` is defined exactly as before
- AND no change in behavior occurs for any host that does not set the option

---

## Delta: `hosts/rog/default.nix` (MODIFIED)

### REQ-8: Import and Enable the Late Poweroff Workaround

`hosts/rog/default.nix` MUST import `../../modules/hardware/rog-poweroff-workaround.nix`
and set `hardware.rog.poweroffWorkaround.enable = true`.

#### Scenario 8-A: Module is in rog's import list

- GIVEN the `rog` host configuration is evaluated
- WHEN imports are resolved
- THEN `rog-poweroff-workaround.nix` is in the module list

#### Scenario 8-B: Option is enabled

- GIVEN the `rog` host configuration
- WHEN `hardware.rog.poweroffWorkaround.enable` is read
- THEN its value is `true`

---

### REQ-9: Disable ASUS Fan-Control for Isolation Testing

`hosts/rog/default.nix` MUST set `services.asus-fan-control-custom.enable = false`
for the duration of this experiment.

This is a deliberate isolation change: removing ASUS fan-control from the shutdown
graph tests whether `asus_nb_wmi` / `asus_wmi` EC interactions at poweroff are a
contributing cause of the hang.

#### Scenario 9-A: Fan-control is disabled in rog config

- GIVEN the `rog` host configuration
- WHEN `services.asus-fan-control-custom.enable` is read
- THEN its value is `false`

#### Scenario 9-B: No other host is affected

- GIVEN the `thinkcentre` host configuration (or any host that does not set this option)
- WHEN the configuration is evaluated
- THEN `services.asus-fan-control-custom.enable` defaults to `true`
- AND the `asus-fan-control` unit is present in its graph unchanged

---

## Delta: `rog-shutdown.nix` (MODIFIED — neutralized)

### REQ-10: Retire the `shutdown.target`-Wired Service

`modules/hardware/rog-shutdown.nix` currently defines `systemd.services.rog-shutdown`
wired to `poweroff.target`, `reboot.target`, and `halt.target`. This service fires
too early in the shutdown sequence (before `systemd-shutdown` takes over) and is
superseded by the late hook in REQ-1 through REQ-6.

The service MUST be neutralized so it no longer acts as a workaround vehicle. The
preferred approach is to set `enable = false` on the service (making the unit file
absent from the graph) while retaining the file for reference, OR to delete the file
entirely if it is not imported by any other host.

The `rog-shutdown.nix` module MUST NOT be the primary ACPI S5 workaround path after
this change.

#### Scenario 10-A: `rog-shutdown.service` is absent from shutdown graph

- GIVEN `rog-shutdown.nix` has been neutralized
- WHEN `systemctl list-units --all | grep rog-shutdown` is run after rebuild
- THEN no output is returned (unit is absent, not merely inactive)

#### Scenario 10-B: New hook takes over as sole late ACPI path

- GIVEN `rog-shutdown.nix` is neutralized AND `rog-poweroff-workaround.nix` is enabled
- WHEN `rog` shuts down
- THEN the only ACPI `_SI._SST` invocation originates from the
  `/usr/lib/systemd/system-shutdown/rog-poweroff` hook
- AND the `rog-shutdown.service` does NOT also attempt the ACPI call

---

## Established Baseline (Read-Only — From Iteration 1)

The following requirements are ALREADY SATISFIED by the iteration 1 implementation
and MUST NOT be regressed by iteration 2 changes. They are listed here for traceability
and as the verification evidence layer for the new requirements.

| Baseline requirement | Implemented in | Verification role in iter 2 |
|----------------------|----------------|-----------------------------|
| `shutdown-debug-capture` service captures journal/dmesg/ps/mounts | `modules/base/shutdown-debug.nix` | Captures lsmod before hook runs; proves module state at shutdown entry |
| `boot-settings.includeDiagLogging = true` on rog | `hosts/rog/default.nix` | Console output visible during shutdown for real-time observation |
| Persistent journal storage | `shutdown-fix.nix` (journald config) | `journalctl -b -1` available to inspect hook side effects |
| `my.shutdownDebug.enable = true` on rog | `hosts/rog/default.nix` | Enables the capture service |

These baseline items MUST remain present and unmodified in `hosts/rog/default.nix`
and their respective modules after iteration 2 changes are applied.

---

## Non-Requirements (Explicitly Out of Scope)

- DSDT/SSDT custom override — documented as iteration 3 fallback only
- Touching `thinkcentre`, `t14`, or `mact2` configurations
- Modifying the `shutdown-debug-capture` capture script or its collected artifacts
- Watchdog disable (already correct in `shutdown-fix.nix`)
- Off-host log collection or upload
- Changing boot kernel parameters beyond what iteration 1 already sets

---

## Success Criteria

All of the following MUST be true for iteration 2 to be considered done:

1. `nix flake check --no-build` exits 0 for all hosts
2. `format-nix` produces no diff (code is properly formatted)
3. `/usr/lib/systemd/system-shutdown/rog-poweroff` exists and is executable on `rog`
   after rebuild
4. `systemctl list-units --all | grep asus-fan-control` returns no output on `rog`
5. `systemctl list-units --all | grep rog-shutdown` returns no output on `rog`
6. `rog` powers off completely after `shutdown -h now` (primary bug — requires live test)
7. If the hang persists: `lsmod.log` in the diagnostic snapshot shows `asus_nb_wmi`
   and `asus_wmi` absent, confirming the hook ran and providing fault isolation for
   iteration 3 (DSDT override)
