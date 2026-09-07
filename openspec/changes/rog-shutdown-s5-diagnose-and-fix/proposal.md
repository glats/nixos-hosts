# Proposal: Diagnose and Fix rog S5 Shutdown

## Intent

Make `rog` complete `systemctl poweroff` despite its GL553VD firmware defect while preserving the late-shutdown failure point. Do not restore workarounds removed by `8dc4ed4`.

## Scope

### In Scope
- Host scope: `rog` only; one selected LAN host receives netconsole UDP.
- Add late-shutdown `/dev/kmsg` breadcrumbs, netconsole over `enp3s0`, `printk.always_kmsg_dump=1`, and EFI pstore collection.
- Add a helper that derives PM1a control and S5 sleep type from firmware, then writes `SLP_TYP_S5 | SLP_EN` without the broken `_PTS`/S5 AML path.
- Add an EFI `ResetSystem(EfiResetShutdown)` fallback that preserves `acpi_power_off_prepare` teardown.
- Test parsing, ordering, and refusal paths.

### Out of Scope
- DSDT/SSDT overrides, kexec, firmware replacement, or coreboot.
- Restoring `acpi=force`, `reboot=acpi`, `pcie_aspm=off`, `acpi=noirq`, ACPI OSI overrides, or watchdog changes.
- Changes to `acpi_call` or manual `asus-fan-control` use.

## Capabilities

### New Capabilities
- `rog-s5-poweroff-recovery`: Persistent diagnosis, firmware-derived ACPI S5 poweroff, and EFI fallback for `rog`.

### Modified Capabilities
- None.

## Approach

Stage rollout behind Nix options: diagnostics first, then a guarded firmware-derived S5 write, then EFI shutdown fallback. Reject missing, malformed, or unsafe ACPI values instead of guessing. Keep userspace logic in tested `pkgs/nixos-scripts` Go code and host-specific wiring in Nix.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `linux/system/base/shutdown-debug.nix` | Modified | Persistent diagnostics and netconsole. |
| `linux/system/hardware/rog-poweroff.nix` | New | Guarded rog-only activation and fallback ordering. |
| `pkgs/nixos-scripts/` | Modified | Tested ACPI discovery and poweroff logic. |
| `hosts/rog/default.nix` | Modified | Enable staged diagnostics and selected recovery path. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Incorrect port/value write hangs earlier | Medium | Derived values, strict validation, rog-only gate, tests, diagnostics first. |
| Netconsole exposes kernel logs on LAN | Medium | Fixed receiver, port, interface, and MAC. |
| EFI fallback skips teardown | Low | Retain `acpi_power_off_prepare`; invoke only after primary failure. |

## Rollback Plan

Disable the rog-only options, remove added kernel parameters, and rebuild to return to `8dc4ed4`. Do not restore deleted workarounds.

## Dependencies

- Receiver chosen: `thinkcentre` at `172.16.0.11`, MAC `6c:4b:90:2d:97:42`, UDP port `6666` (proposed). Verified live on 2026-09-07 (ssh hostname + avahi).
- `thinkcentre` currently gets its address via DHCP (lease happens to repeat) — the change must pin `172.16.0.11` statically in thinkcentre's NixOS config so the netconsole target never moves. Note `rog`'s own LAN IP is also DHCP-dynamic; netconsole setup must not assume a fixed source address (prefer runtime configfs setup over kernel cmdline).
- EFI runtime services and pstore must be available on `rog`.

## Success Criteria

- [ ] A failed shutdown leaves ordered breadcrumbs through the final poweroff attempt in netconsole and/or EFI pstore.
- [ ] The helper selects PM1a `0x1804` and firmware S5 type without hardcoding either.
- [ ] Repeated `systemctl poweroff` trials reach physical S5 (`Power down` or equivalent receiver evidence) without manual intervention.
- [ ] Missing/invalid firmware data fails closed to the EFI fallback; `acpi_call`, fan control, and other hosts remain unchanged.
