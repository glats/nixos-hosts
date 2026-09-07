# Design: Diagnose and Fix rog S5 Shutdown

## Technical Approach

Deploy three gates: prove logging, attempt firmware-derived PM1a S5 from shutdown ramfs, then invoke EFI shutdown after normal ACPI preparation. `thinkcentre` is the acknowledged sink. Nothing unloads network modules.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Late hook | Self-contained `rog-poweroff-hook` linked at `/etc/systemd/system-shutdown/rog-poweroff`; generated JSON in shutdown ramfs | Shell; subprocess chain | After unmounts, it emits `rog-s5:` `hook-start`, `modules-state`, `s5-attempt`, `s5-refused`/`s5-returned`, `hook-end`. Non-poweroff verbs exit; successful S5 never returns. |
| Persistent dump | `printk.always_kmsg_dump=1`, `efi_pstore.pstore_disable=N`; startup verifies pstore/EFI parameter paths | ramoops | Pinned 6.18.45 has `PSTORE=y` and `EFI_VARS_PSTORE=y`; systemd-pstore retains records. |
| Netconsole | Nix loads `configfs`/`netconsole`; `netconsole-setup` discovers `enp3s0`'s current IPv4 and writes configfs `target1` fields | Kernel command line; fixed source IP | Supports DHCP. It binds UDP 6665, writes a nonce marker to `/dev/kmsg`, and requires a matching ACK within 2s; timeout fails the oneshot visibly. |
| Receiver | `netconsole-log` fsync-appends timestamped UDP lines under `/var/log/netconsole/` and ACKs nonces | Netcat; send-only test | Gives durable, objective readiness; a static user, `LogsDirectory`, firewall, and logrotate bound privilege/storage. |
| ACPI discovery | Pure strict parsers: valid signatures/lengths/checksums; X_PM1a_CNT GAS offset 172 preferred, legacy PM1a offset 64 fallback; one root `Name(\_S5, Package(...))` with literal integers | `acpi_call`; full AML; constants | Fails closed. `acpi_call` can evaluate Packages, but its fan-control dependency/text contract stays untouched. **Correction:** offset 116 is `RESET_REG`. |
| Port I/O | 16-bit little-endian `/dev/port` read-modify-write: replace SLP_TYP bits 10–12, set SLP_EN 13 | `iopl(3)`; blind write | No cgo; preserves other bits. Refuse non-I/O GAS, port 0 or >`0xfffe`, non-16-bit width, SLP_TYP outside 1–7, ambiguity, or wrong DMI. |
| EFI fallback | DMI-scoped `rog-efi-poweroff` module at `SYS_OFF_PRIO_FIRMWARE+1`; emit `efi-fallback`, call EFI ResetSystem | Userspace EFI; below ACPI; kernel patch | Linux exports `efi`; no production userspace API exists. Below ACPI is unreachable on a hang. Priority 225 replaces only final entry while existing ACPI prepare runs, matching T14 RFC v3. |
| Static receiver address | NetworkManager profile bound to `enp0s31f6`, retaining DHCP route/DNS and adding `172.16.0.11/24` | `networking.interfaces`; replace DHCP | Keeps one manager and Docker untouched; disable the competing wired profile at rollout. |

## Data Flow

```text
boot: rog configfs -> kmsg nonce -> UDP 6666 thinkcentre -> fsync log -> ACK 6665 -> unit ready
poweroff: systemd-shutdown -> Go hook -> validated /dev/port S5
                                     `-> refusal/return -> ACPI prepare -> EFI handler -> physical off
```

## File Changes

| File | Action | Description |
|---|---|---|
| `linux/system/hardware/rog-poweroff.nix` | Create | Options, units, ramfs, kernel wiring. |
| `linux/system/base/shutdown-debug.nix` | Modify | Opt-in EFI-pstore collection; defaults unchanged. |
| `hosts/{rog,thinkcentre}/default.nix` | Modify | Stages and receiver wiring. |
| `pkgs/nixos-scripts/{cmd,internal}/` | Create | Commands, packages, tests, fixtures. |
| `pkgs/nixos-scripts/default.nix` | Modify | Build three commands. |
| `pkgs/rog-efi-poweroff/{default.nix,Makefile,rog-efi-poweroff.c}` | Create | Kernel module package. |
| `docs/rog-s5-poweroff.md` | Create | Runbook. |

## Interfaces / Contracts

```nix
hardware.rog.s5-recovery = {
  diagnostics.enable = false;
  s5Write.enable = false;
  efiFallback.enable = false;
  netconsole = { enable = true; interface = "enp3s0"; localPort = 6665;
    remoteIP = "172.16.0.11"; remoteMAC = "6c:4b:90:2d:97:42"; remotePort = 6666; };
};
```

Later stages assert diagnostics enabled. Generated JSON contains no firmware value.

## Testing Strategy

| Layer | Approach |
|---|---|
| Unit | Table-driven FADT/AML/validation, ACK, framing, ordering, and refusal fixtures; assert zero writes on invalid input. |
| Integration | Go tests, kernel-matched module build, `format-nix`, `nix flake check --no-build`; inspect ramfs and handler registration. |
| E2E | Gate 1: ACK plus pstore backend/parameters and ordered diagnostic-only shutdown trace. Gate 2: one supervised S5-write trial. Gate 3: EFI enabled only after refusal/return evidence. Acceptance is **three consecutive unattended poweroffs** with physical-off and receiver/pstore evidence. |

## Threat Matrix

| Boundary | Applicability | Design response / RED tests |
|---|---|---|
| Documentation-like paths | N/A — no classification | None |
| Git repository selection | N/A — no Git | None |
| Commit state | N/A — no commits | None |
| Push state | N/A — no pushes | None |
| PR commands | N/A — no PR automation | None |

Process integration is applicable: RED tests cover wrong verbs, missing config/sysfs, malformed firmware, ACK timeout/spoofing, zero-write refusal, and ordering.

## Migration / Rollout

Deploy receiver/address, then diagnostics. Advance after Gate 1; enable S5 write after fixtures match live `0x1804`; enable EFI after primary refusal/return. Roll back each boolean to `8dc4ed4`.

## Open Questions

- [ ] Confirm `thinkcentre` prefix/profile and address non-conflict before cutover.
- [ ] Capture rog's real FADT/DSDT as sanitized test fixtures and confirm root `_S5` uses the supported literal Package form; otherwise stop for parser-scope review.
