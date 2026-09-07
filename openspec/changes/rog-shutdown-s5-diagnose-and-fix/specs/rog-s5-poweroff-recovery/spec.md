# rog-s5-poweroff-recovery Specification

## Purpose

Define staged diagnosis and recovery for `rog` S5 poweroff without regressions.

## Requirements

### Requirement: Persistent Late-Shutdown Diagnostics

`rog` MUST emit ordered `/dev/kmsg` breadcrumbs, enable `printk.always_kmsg_dump=1`, and retain EFI pstore, not ramoops.

#### Scenario: Preserve a failed shutdown trace [hosts: rog]

- GIVEN `systemctl poweroff` stalls before physical S5
- WHEN the final poweroff stages execute
- THEN breadcrumbs through the last attempt MUST reach netconsole and/or EFI pstore
- AND MUST identify each recovery outcome

### Requirement: Runtime Netconsole Pipeline

`rog` MUST configure configfs netconsole at runtime on `enp3s0` without a fixed source IP, targeting `172.16.0.11`, `6c:4b:90:2d:97:42`, UDP `6666`.

#### Scenario: Verify delivery before a shutdown trial [hosts: rog, thinkcentre]

- GIVEN DHCP-configured `rog` can reach `thinkcentre`
- WHEN setup sends its verification message
- THEN `thinkcentre` MUST receive the message on `6666/udp`
- AND failed readiness MUST be visible

### Requirement: Firmware-Derived S5 Write

The helper MUST derive PM1a_CNT_BLK from FADT/ACPI and SLP_TYP from `\_S5`, then write `SLP_EN | (SLP_TYP_S5 << 10)`. Values MUST NOT be hardcoded; the write MUST bypass `_PTS`/S5 AML.

#### Scenario: Select verified firmware values [hosts: rog]

- GIVEN firmware exposes safe, well-formed shutdown data
- WHEN the helper prepares the S5 write
- THEN it MUST select PM1a `0x1804` and firmware S5 type
- AND tests MUST prove firmware derivation

#### Scenario: Refuse unsafe firmware data [hosts: rog]

- GIVEN either value is missing, malformed, ambiguous, or unsafe
- WHEN the helper validates the write
- THEN it MUST refuse all port I/O without guessing
- AND MUST log refusal before enabled EFI fallback

### Requirement: Ordered EFI Shutdown Fallback

EFI `ResetSystem(EfiResetShutdown)` MUST follow primary failure or refusal without bypassing teardown or `acpi_power_off_prepare`.

#### Scenario: Fall back after primary failure [hosts: rog]

- GIVEN teardown completed and primary recovery failed
- WHEN EFI fallback is enabled
- THEN EFI shutdown MUST follow its breadcrumb
- AND no earlier teardown stage MUST be skipped

### Requirement: Independent Staged Enablement

Diagnostics, S5 write, and EFI fallback MUST have independent `rog`-only Nix options. Later stages MUST retain diagnostics, which MUST NOT enable fixes.

#### Scenario: Advance and roll back stages independently [hosts: rog]

- GIVEN a stage is being evaluated
- WHEN its option changes and `rog` is rebuilt
- THEN only that stage MUST change
- AND rollback MUST restore the `8dc4ed4` baseline, not deleted workarounds

### Requirement: Stable Netconsole Receiver

`thinkcentre` MUST use static `172.16.0.11` and persist netconsole lines with timestamps.

#### Scenario: Retain receiver evidence [hosts: thinkcentre]

- GIVEN the listener is enabled on `thinkcentre`
- WHEN kernel lines arrive on `6666/udp`
- THEN each line MUST be durably recorded with its receive timestamp
- AND remain available after the trial

### Requirement: Tested Go Operational Boundary

New ACPI parsing, breadcrumb, and listener logic MUST be tested Go in `pkgs/nixos-scripts`; command entries MUST remain thin and Nix MUST only wire it.

#### Scenario: Reject untested or non-Go operational logic [hosts: rog, thinkcentre]

- GIVEN recovery source is inspected
- WHEN placement and tests are validated
- THEN shared logic MUST have `go test` coverage under `internal/`
- AND new shell operational implementations MUST be rejected

### Requirement: Success Exit and Non-Interference

Repeated trials MUST reach physical S5 unattended before acceptance. `shutdown-debug.nix`, `shutdown-fix.nix`, `includeDiagLogging`, `asus_nb_wmi`/`asus_armoury` blacklists, `acpi_call`, fan control, and non-`rog` behavior MUST remain unchanged.

#### Scenario: Accept or exit the rollout [hosts: rog]

- GIVEN staged recovery undergoes repeated trials
- WHEN trials consistently reach `Power down` or equivalent evidence
- THEN the successful stage set MAY be retained
- AND failure MUST trigger rollback, not `acpi=force`, `reboot=acpi`, `pcie_aspm=off`, `acpi=noirq`, OSI overrides, watchdog changes, or old port-I/O

#### Scenario: Preserve unrelated behavior [hosts: rog, thinkcentre, t14, mact2]

- GIVEN host configurations and ASUS utilities are exercised
- WHEN effects are compared with baseline
- THEN `acpi_call`, `asus-fan-control`, baseline modules, and other hosts MUST behave as before
