# Delta Specs: Shutdown Hang — Iteration 3 (A+B+C+D)

> **Iteration**: 3
> **Supersedes**: iteration 2 spec entirely
> **Established baseline**: REQ-1 through REQ-10 from iteration 2 remain in place as read-only infrastructure (see Appendix A). This document specifies the delta — new capabilities, modifications to existing requirements, and apply-slice sequencing for the four neutral approach categories.
>
> **Stacking rule**: options A through D are designed to be **stacked cumulatively** across sequential apply slices. Slice 1 = A only; Slice 2 = A + B; Slice 3 = A + B + C; Slice 4 = A + B + C + D. No option is removed between slices.

---

## Apply-Slice Sequencing

### Slice 1 — Apply A (Module Blacklist Only)

| Option | Action | File |
|--------|--------|------|
| A | Add `boot.blacklistedKernelModules` | `hosts/rog/default.nix` |
| B | No change | — |
| C | No change | — |
| D | No change | — |

Hook at `/usr/lib/systemd/system-shutdown/rog-poweroff` continues to run `rmmod` sequence + `\_SI._SST` as specified in REQ-3 through REQ-6 (iteration 2 baseline). The `rmmod` calls for blacklisted modules become no-ops (modules were never loaded), which is acceptable.

### Slice 2 — Apply B (Blacklist + OSI Policy)

| Option | Action | File |
|--------|--------|------|
| A | (retained from slice 1) | `hosts/rog/default.nix` |
| B | Toggle `includeAcpiOsi = false` or adjust OSI string | `hosts/rog/default.nix` or `modules/features/boot.nix` |
| C | No change | — |
| D | No change | — |

### Slice 3 — Apply C (Blacklist + OSI + DSDT Override)

| Option | Action | File |
|--------|--------|------|
| A | (retained) | `hosts/rog/default.nix` |
| B | (retained) | — |
| C | Import and enable DSDT-override module | New `modules/hardware/rog-dsdt-override.nix` + import in `hosts/rog/default.nix` |
| D | No change | — |

### Slice 4 — Apply D (All Four Options)

| Option | Action | File |
|--------|--------|------|
| A | (retained) | — |
| B | (retained) | — |
| C | (retained) | — |
| D | Replace hook body with direct port poweroff | `modules/hardware/rog-poweroff-workaround.nix` |

---

## ADDED Requirements

### REQ-11: Module Blacklist (Option A)

`hosts/rog/default.nix` SHALL add `boot.blacklistedKernelModules = [ "asus_nb_wmi" "asus_armoury" ]` to prevent these modules from loading at any point during boot or runtime.

The following modules MUST NOT be blacklisted:
- `asus_wmi` — required for general WMI functionality (hotkeys, backlight)
- `hid_asus` — required for keyboard input
- `acpi_call` — required for the workaround hook's ACPI fallback in slices 1-3

The existing hook script (REQ-3 baseline) MAY attempt `rmmod` on blacklisted modules. The `|| true` guard MUST absorb the non-zero exit (module not loaded -> rmmod returns error -> script continues). This is harmless and provides backward compatibility if the blacklist is removed.

#### Scenario 11-A: Blacklisted modules never load

- GIVEN `boot.blacklistedKernelModules` contains `"asus_nb_wmi"` and `"asus_armoury"`
- WHEN the system boots
- THEN `lsmod | grep asus_nb_wmi` returns empty
- AND `lsmod | grep asus_armoury` returns empty

#### Scenario 11-B: Required modules remain available

- GIVEN only `asus_nb_wmi` and `asus_armoury` are blacklisted
- WHEN the system boots
- THEN `lsmod | grep asus_wmi` returns non-empty
- AND `lsmod | grep hid_asus` returns non-empty (if the module exists for this kernel)
- AND keyboard input is functional

#### Scenario 11-C: Hook tolerates absent blacklisted modules

- GIVEN `asus_nb_wmi` is blacklisted AND `hardware.rog.poweroffWorkaround.enable = true`
- WHEN the shutdown hook executes `rmmod asus_nb_wmi`
- THEN the `rmmod` call exits non-zero (module not loaded)
- AND the `|| true` guard prevents script termination
- AND the hook continues to the next command

#### Scenario 11-D: Cross-host safety

- GIVEN the `thinkcentre` or `t14` host configuration
- WHEN evaluated
- THEN `boot.blacklistedKernelModules` does NOT contain `asus_nb_wmi` or `asus_armoury`
- AND no non-rog host is affected

#### Scenario 11-E: Reversible by config change

- GIVEN `boot.blacklistedKernelModules` contains the blacklist
- WHEN the line is removed from `hosts/rog/default.nix` and the system is rebuilt
- THEN the next boot loads `asus_nb_wmi` and `asus_armoury` normally (if present in the kernel)

---

### REQ-12: ACPI OSI Policy Change (Option B)

The ACPI OSI kernel parameters SHALL be changed on `rog` to alter how the firmware AML dispatches shutdown behavior.

At least one of the following approaches SHALL be implemented (the design phase will choose which):

**Approach 12-A: Remove OSI override entirely**
- Set `boot-settings.includeAcpiOsi = false` in `hosts/rog/default.nix`
- This removes both `acpi_osi=!` and `acpi_osi="Windows 2018"` from the kernel command line
- The kernel falls back to its default ACPI OSI behavior (Linux-native)

**Approach 12-B: Change the Windows version string**
- Modify `modules/features/boot.nix` to change `"Windows 2018"` to a different version string (e.g., `"Windows 2019"` or `"Windows 2023"`)
- Or add a configurable option `boot-settings.acpiOsiString` that accepts a string or null

The chosen approach MUST be documented in the design.

#### Scenario 12-A: OSI params absent from cmdline

- GIVEN `boot-settings.includeAcpiOsi = false` on rog
- WHEN `cat /proc/cmdline` is inspected after boot
- THEN neither `acpi_osi=!` nor `acpi_osi=` appears in the output
- AND the system boots successfully to multi-user.target

#### Scenario 12-B: No other host affected

- GIVEN any non-rog host configuration
- WHEN evaluated
- THEN its `boot-settings.includeAcpiOsi` setting is unchanged (default `false` or host-specific value)

#### Scenario 12-C: Revision-safe toggle

- GIVEN `boot-settings.includeAcpiOsi` is toggled to `false` and the system is rebuilt
- WHEN the generation selector is used at boot to pick the previous generation
- THEN the OSI params from the previous generation are present on the command line
- AND recovery via generation rollback works

#### Scenario 12-D: Behavior change observable in ACPI log

- GIVEN OSI params have been changed
- WHEN the system boots
- THEN `dmesg | grep -i "acpi.*osi"` shows the new OSI string (or absence thereof)
- AND this provides evidence that the firmware AML dispatch is using the new policy

---

### REQ-13: DSDT/SSDT Table Override (Option C)

A new NixOS module `modules/hardware/rog-dsdt-override.nix` SHALL be created to inject a patched DSDT or SSDT table at boot, bypassing the buggy AML methods in the firmware.

The module MUST expose a boolean option `hardware.rog.dsdtOverride.enable` with default `false`.

When enabled, the module MUST:
1. Accept a compiled `.aml` table file via an option (e.g., `hardware.rog.dsdtOverride.table` of type `path`)
2. Wire the `.aml` file into the boot via `hardware.acpiTables` (the NixOS-native mechanism)
   - The `.aml` file SHALL be discovered by the Linux ACPI table upgrade mechanism (CONFIG_ACPI_TABLE_UPGRADE=y required — the `linux_zen` kernel SHOULD have this enabled by default)
3. Validate that the table signature and OEM ID match the target firmware (fail-closed: do not inject a mismatched table)

The module file and enabling import SHALL be:
- New file: `modules/hardware/rog-dsdt-override.nix`
- Import added to `hosts/rog/default.nix`
- Set `hardware.rog.dsdtOverride.enable = true`

The `.aml` file itself is produced **offline** (not during Nix build):
1. On the rog machine: dump the system DSDT via `acpidump` or by reading `/sys/firmware/acpi/tables/DSDT`
2. Offline: decompile with `iasl -d`, patch the problematic methods (LPS0 handler, fan_curve, ATKD.WMNB where identified), recompile with `iasl -tc`
3. The resulting `.aml` file SHALL be committed to the NixOS repo (under a path like `hosts/rog/acpi/rog-dsdt.aml`)
4. A SHA256 hash or comment documenting the source firmware version MUST accompany the file

#### Scenario 13-A: New module evaluates without error

- GIVEN `modules/hardware/rog-dsdt-override.nix` is imported in `hosts/rog/default.nix`
- WHEN `hardware.rog.dsdtOverride.enable` is set to `true`
- AND a valid `.aml` path is provided
- THEN `nix flake check --no-build` exits 0 for the `rog` host

#### Scenario 13-B: Table injection at boot

- GIVEN `hardware.rog.dsdtOverride.enable = true`
- WHEN the system boots
- THEN `dmesg | grep "ACPI.*override\|ACPI.*table\|ACPI.*DSDT"` shows that the custom table was loaded
- AND the patched AML methods are in effect

#### Scenario 13-C: Disabled does not inject

- GIVEN `hardware.rog.dsdtOverride.enable = false`
- WHEN the system boots
- THEN `dmesg | grep "ACPI.*override\|ACPI.*table"` does NOT show any DSDT override
- AND the system uses the firmware's native DSDT

#### Scenario 13-D: Signature mismatch guard

- GIVEN the provided `.aml` file has a DSDT signature or OEM ID that does not match the current firmware
- WHEN the system boots
- THEN either the NixOS build fails (if validation is done at build time) OR the kernel rejects the override (if validation is at boot time)
- AND the system boots using the firmware's native DSDT without error

#### Scenario 13-E: Reversible by disabling

- GIVEN `hardware.rog.dsdtOverride.enable = true`
- WHEN the option is set back to `false`, rebuilt, and rebooted
- THEN the system boots entirely from the firmware's native DSDT
- AND no ACPI table override is loaded

#### Scenario 13-F: Cross-host safety

- GIVEN the `thinkcentre` or `t14` host configuration
- WHEN evaluated
- THEN no DSDT override module is imported or enabled
- AND `hardware.acpiTables` is empty for those hosts

---

### REQ-14: Direct Port Poweroff (Option D)

The hook script in `modules/hardware/rog-poweroff-workaround.nix` SHALL be replaced (not appended) when option D is active. The replacement SHALL issue a chipset-level poweroff by writing to the x86 I/O port `0x604` instead of calling the ACPI `\_SI._SST` method.

The implementation MUST satisfy:
1. The hook SHALL write the value `0x2000` (or `0x2000` as the lower word — the exact value is implementation-specific per chipset) to I/O port `0x604`
2. This SHALL be done via **one** of:
   - A small C program compiled with `pkgs.writeCFlags` or `pkgs.stdenv.mkDerivation` that calls `iopl(3)` then `outw(0x2000, 0x604)`, OR
   - A shell script using `printf '\x00\x20\x00\x00' > /dev/port` if `/dev/port` is accessible in the shutdown ramfs, OR
   - A shell script using `setpci` (from `pciutils`) if the PCI configuration space mapping of port 0x604 is known
3. The hook MUST remain a single executable file placed via `systemd.shutdownRamfs.contents`
4. Every command MUST be wrapped with `|| true` (REQ-5 no-blocking guarantee extends to this implementation)
5. **The module blacklist (REQ-11), OSI policy (REQ-12), and DSDT override (REQ-13) are all still active** when this option runs — they are not removed

The mechanism to toggle between the ACPI hook (slices 1-3) and the direct port hook (slice 4) SHALL be:
- Either a new option `hardware.rog.poweroffWorkaround.mode = "acpi" | "direct"` with default `"acpi"`, OR
- Conditional logic within the hook script itself based on a kernel parameter or file presence

The design phase will choose the mechanism.

#### Scenario 14-A: Direct port poweroff triggers poweroff

- GIVEN `hardware.rog.poweroffWorkaround.mode = "direct"` (or slice 4 equivalent)
- WHEN `systemctl poweroff` is issued
- THEN filesystems and services stop normally
- AND the shutdown ramfs hook writes to port `0x604`
- AND the machine powers off physically (fan stops, LEDs off)

#### Scenario 14-B: Hook remains non-blocking

- GIVEN port `0x604` is already powering off correctly
- WHEN a failure occurs (port not accessible, permission denied, iopl fails)
- THEN the hook command exits non-zero
- AND the `|| true` guard absorbs the error
- AND the system does not hang on the hook
- AND the machine's poweroff behavior falls through to the kernel's default ACPI S5

#### Scenario 14-C: ACPI mode is unaffected by D changes

- GIVEN `hardware.rog.poweroffWorkaround.mode = "acpi"` (or pre-slice-4)
- WHEN the system shuts down
- THEN the hook runs the original rmmod + `\_SI._SST` sequence (REQ-3, REQ-4 baseline)
- AND the direct port poweroff code is NOT executed
- AND behavior is identical to pre-slice-4

#### Scenario 14-D: Cross-slice compatibility

- GIVEN all four options are active (slice 4)
- WHEN the system boots
- THEN blacklisted modules are absent (REQ-11)
- AND the OSI policy is changed (REQ-12)
- AND the DSDT override is loaded (REQ-13)
- AND the hook uses direct port poweroff (REQ-14)
- AND all four coexist without conflicts
- AND `nix flake check --no-build` exits 0

---

## MODIFIED Requirements

### REQ-3: Hook Script — Module Unload (Compatibility Note for Options A, D)

REQ-3 from iteration 2 baseline stated: "The hook script MUST attempt to unload asus_nb_wmi, asus_armoury, asus_wmi, acpi_call in order."

**For Option A (module blacklist):** The `rmmod` calls for blacklisted modules (`asus_nb_wmi`, `asus_armoury`) become no-ops because those modules were never loaded. This is ACCEPTABLE — the `|| true` guard absorbs the non-zero exit. No code change is required.

**For Option D (direct port poweroff, all slices including A+B+C):** The hook body is REPLACED, not appended. The rmmod sequence is REMOVED. This is INTENTIONAL — the blacklist (REQ-11) already ensures these modules are absent, and the direct port poweroff bypasses ACPI entirely, so module state at shutdown is irrelevant for the poweroff mechanism.

#### Scenario 3-D: Blacklist + unchanged hook (slice 1)

- GIVEN `boot.blacklistedKernelModules` has `asus_nb_wmi` AND the hook is still the original ACPI version
- WHEN the hook runs
- THEN `rmmod asus_nb_wmi` returns non-zero (module absent)
- AND `rmmod asus_armoury` returns non-zero (module absent)
- AND `rmmod asus_wmi` returns zero (module present)
- AND the script continues past all failures

#### Scenario 3-E: Direct port hook removes rmmod calls (slice 4)

- GIVEN `hardware.rog.poweroffWorkaround.mode = "direct"` (or equivalent)
- WHEN the hook script content is inspected
- THEN it does NOT contain any `rmmod` invocation
- AND it does NOT contain any `modprobe acpi_call` invocation
- AND it does NOT contain any `\_SI._SST` echo
- AND it does contain an `outw(0x2000, 0x604)` call or equivalent

---

### REQ-4: Hook Script — ACPI `_SI._SST` Fallback (Modified for Option D)

REQ-4 from iteration 2 baseline stated: "After module unload: modprobe acpi_call || true, then echo '\_SI._SST' > /proc/acpi/call || true."

**For Option D:** This requirement is SUPERSEDED by the direct port poweroff. The ACPI call is replaced by I/O port write. The `acpi_call` module is no longer needed in the hook (though it may remain as a loaded kernel module if other services use it).

For slices 1-3 (without option D), REQ-4 remains fully in effect as specified in iteration 2.

#### Scenario 4-C: Original ACPI path preserved in pre-D slices

- GIVEN `hardware.rog.poweroffWorkaround.mode = "acpi"` (slices 1-3)
- WHEN the hook runs
- THEN `acpi_call` is loaded
- AND `\_SI._SST` is written to `/proc/acpi/call`
- AND behavior matches iteration 2 REQ-4 exactly

#### Scenario 4-D: Direct port hook has no ACPI call (slice 4)

- GIVEN the hook uses direct port poweroff
- WHEN the hook content is inspected
- THEN it does NOT contain `\_SI._SST`
- AND it does NOT contain `modprobe acpi_call`

---

### REQ-6: Breadcrumb Evidence File (Amended for Option D)

REQ-6 from iteration 2 required writing `/run/shutdown-hook-ran` as the last step.

**For Option D:** The breadcrumb SHOULD still be written, but its value SHALL be `direct-poweroff` (not `ok`) to distinguish slice-4 execution from pre-D slices. This provides forensic evidence of which hook variant ran during the last shutdown attempt.

#### Scenario 6-B: Breadcrumb identifies direct port mode

- GIVEN slice 4 is deployed
- WHEN the hook runs during shutdown
- THEN `/run/shutdown-hook-ran` is written with content `direct-poweroff`
- AND the sentinel file confirms the direct port path was executed

---

### REQ-8: Import and Enable (Modified for Options C, D)

REQ-8 from iteration 2 baseline requires importing `rog-poweroff-workaround.nix` and setting `hardware.rog.poweroffWorkaround.enable = true`.

**For Option C:** `hosts/rog/default.nix` SHALL additionally import `../../modules/hardware/rog-dsdt-override.nix` and set `hardware.rog.dsdtOverride.enable = true`.

**For Option D:** No additional import (the existing workaround module is modified in place via the mode option). However, if a separate poweroff program binary is used (not a shell `printf`), `hosts/rog/default.nix` SHALL include any required path to that binary in its configuration.

#### Scenario 8-C: DSDT override imported and enabled

- GIVEN slice 3 or 4 is deployed
- WHEN `hosts/rog/default.nix` is evaluated
- THEN `rog-dsdt-override.nix` appears in the import list
- AND `hardware.rog.dsdtOverride.enable` reads `true`

---

### Baseline `boot-settings` Configuration (Modified for Option B)

The current `hosts/rog/default.nix` sets `includeAcpiOsi = true`. **For Option B**, this SHALL be changed. At minimum one of:
1. `includeAcpiOsi = false` — removes both OSI params
2. A new option or parameter change that alters the OSI string without removing it entirely

The specific chosen approach SHALL be documented in the design phase.

#### Scenario Baseline-B: OSI params match chosen approach

- GIVEN option B has been deployed
- WHEN `cat /proc/cmdline` is inspected after boot
- THEN the ACPI OSI parameters match the chosen approach (absent if disabled, or new string if changed)
- AND the system is stable at multi-user.target

---

## REMOVED Restriction

The iteration 2 "Non-Requirements" section listed "DSDT/SSDT custom override — documented as iteration 3 fallback only." This restriction IS REMOVED for iteration 3. DSDT override is now in scope as Option C.

The iteration 2 "Non-Requirements" entries for "touching thinkcentre, t14, mact2" and "changing boot kernel parameters beyond iteration 1" remain in effect.

---

## Success Criteria

All of the following MUST be true for iteration 3 to be considered done:

1. `nix flake check --no-build` exits 0 for all hosts at every slice
2. `format-nix` produces no diff
3. **Slice 1**: `boot.blacklistedKernelModules` contains `asus_nb_wmi` and `asus_armoury` on rog; `lsmod` confirms they are absent after boot; `asus_wmi` and `hid_asus` remain loaded
4. **Slice 2**: OSI kernel params reflect the chosen policy; system boots stably; change is reversible by generation rollback
5. **Slice 3**: DSDT override loads at boot (dmesg confirms custom table); disabling the option restores native DSDT
6. **Slice 4**: Direct port poweroff causes actual poweroff; hook breadcrumb confirms direct mode ran
7. If the hang persists at any slice: the diagnostic capture (`/var/log/shutdown-debug/`) provides evidence of where execution stopped, proving each option's mechanism was or was not the cause

---

## Appendix A: Established Baseline (Read-Only — From Iteration 2)

The following requirements from iteration 2 are ALREADY DEPLOYED and MUST NOT be regressed by iteration 3 changes. They are retained as the foundation on which options A-D are stacked.

| ID | Requirement | Implemented In |
|----|-------------|----------------|
| REQ-1 | Late Shutdown Hook Module with `hardware.rog.poweroffWorkaround.enable` option | `modules/hardware/rog-poweroff-workaround.nix` |
| REQ-2 | Hook delivery via `systemd.shutdownRamfs.contents` | `modules/hardware/rog-poweroff-workaround.nix` |
| REQ-3 | Hook script: ASUS WMI module unload (rmmod sequence) | `modules/hardware/rog-poweroff-workaround.nix` |
| REQ-4 | Hook script: ACPI `_SI._SST` fallback via acpi_call | `modules/hardware/rog-poweroff-workaround.nix` |
| REQ-5 | No blocking: all commands wrap `|| true` | `modules/hardware/rog-poweroff-workaround.nix` |
| REQ-6 | Breadcrumb `/run/shutdown-hook-ran` sentinel | `modules/hardware/rog-poweroff-workaround.nix` |
| REQ-7 | Clean disable path for `asus-fan-control` | `modules/hardware/asus-fan-control.nix` |
| REQ-8 | Import and enable rog-poweroff-workaround on rog | `hosts/rog/default.nix` |
| REQ-9 | Disable ASUS fan-control on rog | `hosts/rog/default.nix` |
| REQ-10 | Retire `rog-shutdown.service` (enable=false) | `modules/hardware/rog-shutdown.nix` |

Plus the iteration 1 baseline:
- `shutdown-debug-capture` service captures journal/dmesg/ps/mounts → `modules/base/shutdown-debug.nix`
- `boot-settings.includeDiagLogging = true` → `hosts/rog/default.nix`
- Persistent journal storage → `shutdown-fix.nix`
- `my.shutdownDebug.enable = true` → `hosts/rog/default.nix`

**Cross-slice invariants**: These baseline modules and settings MUST remain present and unmodified across ALL four slices. No iteration 3 change MAY remove or disable:
- The shutdown-debug capture service or its `.enable` option
- The `includeDiagLogging = true` setting
- The persistent journald configuration
- The disabled watchdog setting in `shutdown-fix.nix`
