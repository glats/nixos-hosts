# Design: Shutdown Hang — ASUS WMI Isolation + Late Shutdown Hook (Iteration 2)

> Iteration: 2 (full re-design after review checkpoint #1629)
> Supersedes: iteration 1 design entirely
> Baseline: shutdown-debug-capture, boot-settings.includeDiagLogging, persistent journal — read-only

## Technical Approach

Replace the too-early `rog-shutdown.nix` systemd service with a true late-phase shutdown hook
delivered via `systemd.shutdownRamfs.contents`. The hook runs after `systemd-shutdown` pivots
to the initramfs at the very last moment before kernel power-off, making it the latest possible
software intervention point. Simultaneously, disable `asus-fan-control` on rog to remove a known
ASUS WMI/EC interaction during the shutdown path.

The hook script: unloads ASUS WMI kernel modules (the identified firmware/ACPI error source),
reloads `acpi_call`, fires `\_SI._SST`, and writes a sentinel breadcrumb. Every command is
`|| true`-wrapped to guarantee the script exits 0 regardless of individual failures.

## Architecture Decisions

| Decision | Options Considered | Choice | Rationale |
|----------|-------------------|--------|-----------|
| Hook delivery mechanism | `systemd.shutdown` (symlink in /etc live system) vs `systemd.shutdownRamfs.contents` | `systemd.shutdownRamfs.contents` | Spec requirement; shutdownRamfs hook runs AFTER pivot-to-initramfs, which is later than any `shutdown.target`-wired service. |
| Script binary paths | Rely on PATH vs absolute Nix store paths | Absolute `${pkgs.kmod}/bin/rmmod` etc. | PATH is not guaranteed in the shutdown ramfs; Nix store paths are stable and resolved at build time. |
| kmod in ramfs | Assume present vs explicit storePaths | Explicit `systemd.shutdownRamfs.storePaths = [ "${pkgs.kmod}/bin" ]` | Default ramfs only includes `coreutils/bin`. kmod must be declared explicitly or rmmod/modprobe store paths will be absent at hook runtime. |
| shutdownRamfs.contents key path | `/lib/systemd/system-shutdown/` vs `/etc/systemd/system-shutdown/` | `/etc/systemd/system-shutdown/rog-poweroff` | Confirmed by NixOS test (`nixos/tests/systemd-shutdown.nix`) and ZFS module: contents key uses `/etc/systemd/system-shutdown/` prefix inside the ramfs. |
| rog-shutdown.nix fate | Delete file vs set enable=false | Set `enable = false` inside the module, keep file | Preserves audit trail; cleanly removes unit from systemd graph without dangling import. |
| Breadcrumb file | None vs `/run/shutdown-hook-ran` | Write `/run/shutdown-hook-ran` | `/run/` is writable in the shutdown ramfs. Breadcrumb is best-effort (tmpfs, may not survive); primary evidence is lsmod.log showing asus_nb_wmi absent. |
| asus-fan-control disable | Delete import vs set enable=false | `services.asus-fan-control-custom.enable = false` in rog default.nix | Keeps module available for future re-enable; existing `lib.mkIf` guard already makes unit absent when option is false. |
| Option namespace | `hardware.rog.poweroffWorkaround.enable` | As specified | Matches the `hardware.` namespace used by `hardware.nvidia-custom.enable` in this repo. |

## Data Flow

```
System receives shutdown signal
  │
  ├─ systemd userspace shutdown (services stop, filesystems unmount, etc.)
  │   ├─ asus-fan-control.service  — ABSENT (disabled in rog default.nix)
  │   ├─ rog-shutdown.service      — ABSENT (enable=false in rog-shutdown.nix)
  │   └─ shutdown-debug-capture.service — RUNS (baseline, read-only)
  │        └─ writes /var/log/shutdown-debug/{boot-id}/ snapshots
  │             (includes lsmod.log — used as hook evidence on next boot)
  │
  └─ systemd-shutdown pivots to /run/initramfs
       │
       └─ executes /etc/systemd/system-shutdown/rog-poweroff  ← NEW HOOK
            │
            ├─ ${pkgs.kmod}/bin/rmmod asus_nb_wmi 2>/dev/null || true
            ├─ ${pkgs.kmod}/bin/rmmod asus_armoury 2>/dev/null || true
            ├─ ${pkgs.kmod}/bin/rmmod asus_wmi 2>/dev/null || true
            ├─ ${pkgs.kmod}/bin/rmmod acpi_call 2>/dev/null || true
            ├─ ${pkgs.kmod}/bin/modprobe acpi_call 2>/dev/null || true
            ├─ echo '\_SI._SST' > /proc/acpi/call 2>/dev/null || true
            ├─ echo "rog-poweroff hook ran" > /run/shutdown-hook-ran || true
            └─ exits 0 (guaranteed — no set -e, all || true)
                 │
                 └─ kernel issues ACPI S5 / poweroff
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `modules/hardware/rog-poweroff-workaround.nix` | **Create** | New module. Option `hardware.rog.poweroffWorkaround.enable` (default false). When true: delivers hook via `systemd.shutdownRamfs.contents."/etc/systemd/system-shutdown/rog-poweroff".source`; adds `pkgs.kmod` to `systemd.shutdownRamfs.storePaths`. |
| `modules/hardware/rog-shutdown.nix` | **Modify** | Add `enable = false` to `systemd.services.rog-shutdown` attrset. Add comment citing successor module. Service is removed from systemd graph; file is kept as audit trail. |
| `modules/hardware/asus-fan-control.nix` | **Verify-only** | Confirm `lib.mkIf config.services.asus-fan-control-custom.enable` guard makes unit absent when false. No code change expected. |
| `hosts/rog/default.nix` | **Modify** | Add import `../../modules/hardware/rog-poweroff-workaround.nix`. Add `hardware.rog.poweroffWorkaround.enable = true`. Add `services.asus-fan-control-custom.enable = false`. |
| `modules/base/shutdown-debug.nix` | **Read-only** | Baseline diagnostics unchanged. lsmod.log from capture will serve as hook evidence. |

## Module Shape: `rog-poweroff-workaround.nix`

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.rog.poweroffWorkaround;

  rogPoweroffHook = pkgs.writeShellScript "rog-poweroff" ''
    # Late shutdown hook: unload ASUS WMI modules, reload acpi_call, fire _SI._SST.
    # Runs inside the shutdown initramfs after systemd-shutdown pivots — the last
    # software phase before kernel issues ACPI S5.
    # No set -e. Every command must be || true so the script always exits 0.

    ${pkgs.kmod}/bin/rmmod asus_nb_wmi 2>/dev/null || true
    ${pkgs.kmod}/bin/rmmod asus_armoury 2>/dev/null || true
    ${pkgs.kmod}/bin/rmmod asus_wmi 2>/dev/null || true
    ${pkgs.kmod}/bin/rmmod acpi_call 2>/dev/null || true

    ${pkgs.kmod}/bin/modprobe acpi_call 2>/dev/null || true
    echo '\_SI._SST' > /proc/acpi/call 2>/dev/null || true

    # Breadcrumb: best-effort evidence that this hook executed.
    # Primary evidence is lsmod.log in shutdown-debug capture (asus_nb_wmi absent).
    echo "rog-poweroff hook ran" > /run/shutdown-hook-ran || true
  '';
in
{
  options.hardware.rog.poweroffWorkaround = {
    enable = lib.mkEnableOption "ROG late-phase ACPI poweroff workaround" // {
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.shutdownRamfs.contents."/etc/systemd/system-shutdown/rog-poweroff" = {
      source = rogPoweroffHook;
    };

    systemd.shutdownRamfs.storePaths = [
      "${pkgs.kmod}/bin"
    ];
  };
}
```

## Module Shape: `rog-shutdown.nix` (neutralized)

Add `enable = false` inside the existing `systemd.services.rog-shutdown` attrset:

```nix
systemd.services.rog-shutdown = {
  description = "ROG ACPI S5 poweroff fallback";
  enable = false; # Superseded by hardware.rog.poweroffWorkaround (rog-poweroff-workaround.nix).
                  # That hook runs after systemd-shutdown pivots to the shutdown initramfs,
                  # which is later and more effective than this shutdown.target-wired service.
  wantedBy = [ ... ]; # retained but inactive (enable=false removes from graph)
  ...
};
```

## NixOS Option Paths (Iteration 2)

| Option | Value | Module |
|--------|-------|--------|
| `hardware.rog.poweroffWorkaround.enable` | `false` (default), `true` on rog | `rog-poweroff-workaround.nix` |
| `systemd.shutdownRamfs.contents."/etc/systemd/system-shutdown/rog-poweroff".source` | `rogPoweroffHook` store path | `rog-poweroff-workaround.nix` |
| `systemd.shutdownRamfs.storePaths` | `[ "${pkgs.kmod}/bin" ]` (appended) | `rog-poweroff-workaround.nix` |
| `systemd.services.rog-shutdown.enable` | `false` | `rog-shutdown.nix` |
| `services.asus-fan-control-custom.enable` | `false` on rog, `true` (default) | set in `hosts/rog/default.nix` |

## Module Dependency Chain

```
hosts/rog/default.nix
 ├── modules/hardware/rog-poweroff-workaround.nix  ← NEW import (creates hook)
 ├── modules/hardware/rog-shutdown.nix             ← MODIFIED (service disabled)
 ├── modules/hardware/asus-fan-control.nix         ← VERIFY-ONLY (lib.mkIf already correct)
 └── modules/base/shutdown-debug.nix               ← READ-ONLY (baseline unchanged)
```

`rog-poweroff-workaround.nix` and `rog-shutdown.nix` are independent — no cross-reference.
No conflict: `rog-shutdown` service is disabled; new module uses a different delivery path
(`shutdownRamfs.contents` vs `systemd.services`).

## Key Technical Facts (Research-Verified)

1. `systemd.shutdownRamfs.enable` defaults to `true` — no explicit enable needed.
2. `systemd.shutdownRamfs.contents` key is the **in-ramfs path** (e.g. `/etc/systemd/system-shutdown/NAME`). Confirmed by nixpkgs source `nixos/tests/systemd-shutdown.nix` and `nixos/modules/tasks/filesystems/zfs.nix`.
3. `systemd.shutdownRamfs.storePaths` must include `pkgs.kmod/bin` — only `coreutils/bin` is in the default storePaths. Without this, `rmmod`/`modprobe` store paths would be absent inside the ramfs at hook runtime.
4. `pkgs.writeShellScript` produces a file with mode `-r-xr-xr-x` (executable). No chmod needed.
5. `systemd.shutdown` (the other NixOS option) creates symlinks on the live system at `/etc/systemd/system-shutdown/` — NOT in the ramfs. It is a different mechanism from `shutdownRamfs.contents`.
6. `acpi_call` module is already in `boot.extraModulePackages` and `boot.kernelModules` in `hosts/rog/default.nix` — no change needed there.
7. The breadcrumb at `/run/shutdown-hook-ran` may not survive reboot (tmpfs), but the lsmod.log snapshot written by `shutdown-debug-capture` during the same shutdown will show `asus_nb_wmi` absent if unload succeeded — that is the persistent evidence.

## Verification Strategy

| Step | Command / Check | Pass Condition |
|------|----------------|----------------|
| 1 — Build | `nix flake check --no-build` | Exit 0, all hosts |
| 2 — Format | `format-nix` | No diff |
| 3 — Hook file | `ls -la /etc/systemd/system-shutdown/rog-poweroff` after rebuild on rog | File exists, executable (`-r-xr-x`) |
| 4 — Fan-control absent | `systemctl list-units --all \| grep asus-fan-control` | No output |
| 5 — rog-shutdown absent | `systemctl list-units --all \| grep rog-shutdown` | No output |
| 6 — Ramfs service | `systemctl status generate-shutdown-ramfs` | `active (exited)` |
| 7 — Live poweroff | `shutdown -h now` on rog | Machine powers off completely |
| 8 — Hook evidence | Next lsmod.log: `grep asus_nb_wmi /var/log/shutdown-debug/*/lsmod.txt` | No match → hook ran and unloaded module |

## Fallback — Iteration 3

If hook runs (asus_nb_wmi absent in lsmod.log) but hang persists:
- `acpidump` on rog, inspect `_PTS` / `\_SB.ATKD` / `\_SB.PCI0.LPCB.EC0` AML
- Ship minimal SSDT override via `hardware.acpiTables`
- Deliberately deferred to iteration 3

## Open Questions

None. All NixOS option paths verified against nixpkgs source at
`/nix/store/w8w3fia26p35xays42lixahnzigsl8dv-source/nixos/modules/system/boot/systemd/shutdown.nix`
and confirmed by `nixos/tests/systemd-shutdown.nix`. `acpi_call` already declared on rog.
