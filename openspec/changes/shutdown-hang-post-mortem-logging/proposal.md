# Proposal: Shutdown Hang — Iteration 3

## Intent

Resolve the `rog` ACPI S5 poweroff hang that persists after iteration 2 proved the `\_SI._SST` LED-call and module unloading in the late ramfs hook do not trigger poweroff.

## Scope

- In scope: four neutral approach categories (module blacklist, ACPI OSI policy, DSDT/SSDT override, direct port poweroff).
- Out of scope: changing diagnostic capture, touching non-rog hosts, new flake inputs, hardware replacement.

## Capabilities

- **Module blacklist**: Prevent asus_nb_wmi/asus_armoury from loading at boot to eliminate their firmware interactions entirely.
- **ACPI OSI policy**: Toggle or remove the current acpi_osi override to change how firmware AML dispatches on shutdown.
- **DSDT table override**: Patch buggy ACPI methods (LPS0 handler, fan_curve, ATKD.WMNB) via initrd cpio override — surgical but complex.
- **Direct port poweroff**: Use x86 I/O port 0x604 to issue a chipset-level poweroff, bypassing ACPI S5 entirely.

## Approach

Four neutral avenues, each addressing a different layer of the hang. Any combination may be tested sequentially in the same iteration:

- **A. Module blacklist**: Add `boot.blacklistedKernelModules = [ "asus_nb_wmi" "asus_armoury" ]` in `hosts/rog/default.nix`. Keeps `asus_wmi` + `hid_asus` for keyboard. Simple, one-line change, no new files.
- **B. ACPI OSI policy**: In `hosts/rog/default.nix`, remove `includeAcpiOsi = true` or change the params in `modules/features/boot.nix` to drop/adjust the Windows version string. Can be toggled per boot via kernel cmdline edit.
- **C. DSDT/SSDT override**: Extract DSDT via `acpidump`, decompile with `iasl`, patch the offending AML methods, recompile to `.aml`, inject via `boot.initrd.kernelModules` + cpio or `hardware.acpiTables`. Requires offline analysis of the firmware dump on the target machine.
- **D. Direct port poweroff**: Add a small C program or shell one-liner calling `outw(0x2000, 0x604)` via `acpi_call` or direct `/dev/port` access, wired as either a systemd service or the existing shutdown ramfs hook. Bypasses ACPI entirely.

## Affected Areas

| File | Likely Action |
|------|---------------|
| `hosts/rog/default.nix` | Toggle blacklist, OSI, or add poweroff route |
| `modules/features/boot.nix` | (Conditional) adjust ACPI OSI kernel params |
| `modules/hardware/rog-poweroff-workaround.nix` | Update or replace hook body depending on chosen approach |
| `modules/base/shutdown-fix.nix` | Read-only |
| `modules/base/shutdown-debug.nix` | Read-only |

## Risks

- Blacklist may lose hotkeys or WMI features if `asus_wmi` also gets caught.
- OSI change could destabilize boot, require recovery via generation selector.
- DSDT override is fragile across BIOS updates and may brick on signature mismatch.
- Direct port poweroff bypasses all ACPI S5 sequencing (filesystem sync already done; risk is unclean chipset state on next boot).

## Rollback Plan

- Module blacklist: delete the one blacklist line, rebuild.
- OSI policy: restore `includeAcpiOsi = true` or revert boot.nix kernel params.
- DSDT override: remove the `.aml` file from initrd; remove `hardware.acpiTables` entry.
- Direct port: revert the hook change in `rog-poweroff-workaround.nix` or toggle enable.
- All approaches: `git revert` the commit, rebuild, reboot.

## Dependencies

- For approach C: `acpica-tools` on rog to dump/extract. Flake already builds from nixpkgs.
- For approach D: `outw(0x2000, 0x604)` via `/dev/port` requires no new packages (shell + `printf` or small C program); `acpi_call` module is already loaded.
- No new flake inputs required for any approach.

## Success Criteria

- `nix flake check --no-build` and `format-nix` pass.
- After `systemctl poweroff`, rog actually powers off (fan stops, LEDs off).
- If still hangs: diagnostic capture provides evidence of where execution stopped.
