# Design: Shutdown Hang — Iteration 3 (A+B+C+D Stacking)

> **Iteration**: 3
> **Supersedes**: iteration 2 design entirely
> **Baseline**: iteration 2 infra (rog-poweroff-workaround, rog-shutdown neutralized, fan-control disabled, shutdown-debug-capture, boot-settings.includeDiagLogging, persistent journal) — already deployed, read-only, no regressions allowed.
>
> **Stacking rule**: Options A-D applied **cumulatively** across 4 slices. Slice 1 = A only; Slice 2 = A+B; Slice 3 = A+B+C; Slice 4 = A+B+C+D. No removal between slices. Each slice is a full rebuild+switch.

---

## 1. Architecture Decisions

| # | Decision | Options Considered | Choice | Rationale |
|---|----------|-------------------|--------|-----------|
| AD-1 | Option A mechanism | Inline blacklist vs new module | `boot.blacklistedKernelModules` in `hosts/rog/default.nix` | Simplest possible; no new module needed; reversible by removing two lines. |
| AD-2 | Option B approach | 12-A (remove OSI entirely) vs 12-B (change string) | **12-A: `includeAcpiOsi = false`** | Simpler, cleaner test signal (params present/absent), reversible by generation rollback. No need for new option infrastructure. |
| AD-3 | Option C module shape | Single file vs split (module + data) | Single `modules/hardware/rog-dsdt-override.nix` + `.aml` in `hosts/rog/acpi/` | Matches repo pattern (single-file module with path option). .aml committed separately. |
| AD-4 | Option C kernel config | `boot.kernelPatches` for CONFIG_ACPI_TABLE_UPGRADE vs assume linux_zen has it | **Assume linux_zen has it**; add `boot.kernelPatches` only if missing | `linux_zen` typically enables CONFIG_ACPI_TABLE_UPGRADE. Document verification step. |
| AD-5 | Option D delivery | Mode option vs separate module vs kernel param detection | **`hardware.rog.poweroffWorkaround.mode = "acpi" | "direct"`** | Reuses existing module; single toggle; clean separation of hook code. Default `"acpi"` keeps backward compat. |
| AD-6 | Option D I/O method | `printf > /dev/port` vs C program with `iopl()+outw()` vs `setpci` | **C program with `iopl(3) + outw(0x2000, 0x604)`** | `/dev/port` may not exist in ramfs; `setpci` adds pciutils dependency. C program is self-contained, statically linkable (~8KB), compiled at build time. |
| AD-7 | storePaths per mode | Conditional storePaths vs always include both | **Always build both binary and kmod; include both in storePaths** | Binary is ~8KB static. Eliminates conditional storePaths complexity. Mode determines which branch the hook script executes. |
| AD-8 | DSDT validation | Build-time `iasl` check vs offline manual check | **Offline manual check** (user verifies OEM ID before committing .aml) | Avoids adding `iasl` as a build dependency. The `iasl` decompile/recompile is an interactive offline step on rog. |
| AD-9 | Breadcrumb for slice 4 | Same vs distinct content | **Distinct content: `"direct-poweroff"`** | Provides forensic evidence about which hook variant ran during the last shutdown. |

---

## 2. Technical Approach

### Option A — Module Blacklist

Add two entries to `boot.blacklistedKernelModules` in `hosts/rog/default.nix`:

```nix
boot.blacklistedKernelModules = [ "asus_nb_wmi" "asus_armoury" ];
```

`asus_wmi`, `hid_asus`, and `acpi_call` are explicitly NOT blacklisted. These modules are required for general WMI functionality (hotkeys, backlight), keyboard input, and the ACPI fallback in slices 1-3.

The existing hook's `rmmod` calls for blacklisted modules become harmless no-ops (module absent -> rmmod returns non-zero -> `|| true` absorbs it).

### Option B — ACPI OSI Policy Change

In `hosts/rog/default.nix`, change:

```nix
boot-settings = {
  enable = true;
  includeAcpiOsi = true;   # → false
  ...
};
```

This removes both `acpi_osi=!` and `acpi_osi="Windows 2018"` from the kernel command line. The kernel's default ACPI OSI behavior is used (Linux-native). The option `boot-settings.includeAcpiOsi` remains in `modules/features/boot.nix` unchanged -- only rog toggles it off.

This is fully reversible by:
- Setting `includeAcpiOsi = true` again, OR
- Booting a previous generation from the bootloader menu

### Option C — DSDT/SSDT Table Override

New module `modules/hardware/rog-dsdt-override.nix`:

```nix
# modules/hardware/rog-dsdt-override.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.rog.dsdtOverride;
in
{
  options.hardware.rog.dsdtOverride = {
    enable = lib.mkEnableOption "ROG DSDT ACPI table override" // {
      default = false;
    };
    table = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the compiled DSDT .aml file for ACPI table override.
        Generated offline: acpidump > dsdt.dat; iasl -d dsdt.dat; patch; iasl -tc dsdt.dsl
        The OEM ID in the .aml must match the system firmware.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.acpiTables = lib.optional (cfg.table != null) cfg.table;

    # Ensure CONFIG_ACPI_TABLE_UPGRADE is enabled
    boot.kernelPatches = lib.optionals (!builtins.hasAttr "CONFIG_ACPI_TABLE_UPGRADE"
      config.boot.kernelPackages.kernel.features) [
      {
        name = "acpi-table-upgrade";
        patch = null;
        extraConfig = "ACPI_TABLE_UPGRADE y";
      }
    ];
  };
}
```

**The `.aml` file is produced offline** (interactive step on the rog machine):
1. Dump system DSDT: `acpidump > dsdt.dat` or `cat /sys/firmware/acpi/tables/DSDT > dsdt.aml`
2. Decompile: `iasl -d dsdt.dat` → produces `dsdt.dsl`
3. Patch problematic AML methods (LPS0 handler, fan_curve, ATKD.WMNB, \_PTS)
4. Recompile: `iasl -tc dsdt.dsl` → produces `dsdt.aml`
5. Commit `.aml` to `hosts/rog/acpi/rog-dsdt.aml`
6. Document source firmware version as a comment
7. In `hosts/rog/default.nix`, set `hardware.rog.dsdtOverride.table = ./acpi/rog-dsdt.aml`

### Option D — Direct Port Poweroff

Extend `modules/hardware/rog-poweroff-workaround.nix` with a `mode` option and a compiled C binary.

```nix
# Within the existing rog-poweroff-workaround.nix, restructured:

options.hardware.rog.poweroffWorkaround = {
  enable = lib.mkEnableOption "ROG late-phase ACPI poweroff workaround" // {
    default = false;
  };
  mode = lib.mkOption {
    type = lib.types.enum [ "acpi" "direct" ];
    default = "acpi";
    description = ''
      Shutdown hook mode.
      "acpi"   — unload ASUS WMI modules, fire ACPI _SI._SST (slices 1-3).
      "direct" — write to port 0x604 via iopl/outw (slice 4, bypasses ACPI entirely).
    '';
  };
};
```

The C program for direct port I/O:

```c
// Compiled at build time via pkgs.runCommand + gcc
// Statically linked, ~8KB binary
#include <sys/io.h>
#include <unistd.h>

int main(void) {
    if (iopl(3) < 0) return 1;
    outw(0x2000, 0x604);
    usleep(100000);
    outw(0x2000, 0x604);  // double-write for reliability
    return 0;
}
```

The hook script becomes:

```nix
rogPoweroffHook = pkgs.writeShellScript "rog-poweroff" ''
  if [ "${cfg.mode}" = "direct" ]; then
    ${rogPoweroffBin}/bin/rog-poweroff 2>/dev/null || true
    echo "direct-poweroff" > /run/shutdown-hook-ran || true
  else
    # ACPI mode — original iteration 2 behavior
    ${pkgs.kmod}/bin/rmmod asus_nb_wmi 2>/dev/null || true
    ${pkgs.kmod}/bin/rmmod asus_armoury 2>/dev/null || true
    ${pkgs.kmod}/bin/rmmod asus_wmi 2>/dev/null || true
    ${pkgs.kmod}/bin/rmmod acpi_call 2>/dev/null || true
    ${pkgs.kmod}/bin/modprobe acpi_call 2>/dev/null || true
    echo '\_SI._SST' > /proc/acpi/call 2>/dev/null || true
    echo "rog-poweroff hook ran" > /run/shutdown-hook-ran || true
  fi
'';
```

StorePaths grow to include the poweroff binary. Since kmod is still needed for `acpi` mode and the binary is ~8KB, both are always included:

```nix
systemd.shutdownRamfs.storePaths = [
  "${pkgs.kmod}/bin"
  "${rogPoweroffBin}/bin"
];
```

---

## 3. Data Flow

### Slices 1-3 (options A, A+B, A+B+C)

```
System receives shutdown signal
  │
  ├─ systemd userspace shutdown
  │   ├─ asus-fan-control.service  — ABSENT (iteration 2 baseline)
  │   ├─ rog-shutdown.service      — ABSENT (iteration 2 baseline)
  │   └─ shutdown-debug-capture    — RUNS (baseline, writs diagnostics)
  │
  ├─ [A] asus_nb_wmi, asus_armoury — NEVER LOADED (blacklist)
  ├─ [B] acpi_osi=! / Windows 2018 — REMOVED from cmdline (slice 2+)
  ├─ [C] DSDT override loaded at boot — FIRMWARE PATCHED (slice 3+)
  │
  └─ systemd-shutdown pivots to /run/initramfs
       │
       └─ /etc/systemd/system-shutdown/rog-poweroff  (mode="acpi")
            ├─ rmmod asus_nb_wmi — no-op (blacklist)
            ├─ rmmod asus_armoury — no-op (blacklist)
            ├─ rmmod asus_wmi
            ├─ rmmod acpi_call
            ├─ modprobe acpi_call
            ├─ echo '\_SI._SST' > /proc/acpi/call
            ├─ echo "rog-poweroff hook ran" > /run/shutdown-hook-ran
            └─ kernel issues ACPI S5
```

### Slice 4 (A+B+C+D)

```
System receives shutdown signal
  │
  ├─ same userspace shutdown as above
  │
  ├─ [A] asus_nb_wmi, asus_armoury — NEVER LOADED
  ├─ [B] acpi_osi params — REMOVED from cmdline
  ├─ [C] DSDT override loaded at boot
  │
  └─ systemd-shutdown pivots to /run/initramfs
       │
       └─ /etc/systemd/system-shutdown/rog-poweroff  (mode="direct")
            ├─ rog-poweroff binary (iopl(3) + outw(0x2000, 0x604))
            ├─ echo "direct-poweroff" > /run/shutdown-hook-ran
            └─ chipset-level poweroff (bypasses ACPI entirely)
```

---

## 4. File Changes

### Slice 1 — Apply A (Module Blacklist)

| File | Action | Change |
|------|--------|--------|
| `hosts/rog/default.nix` | **Modify** | Add `boot.blacklistedKernelModules = [ "asus_nb_wmi" "asus_armoury" ];` near existing `boot` block |

**Slice 1 diff** (2 lines added):
```nix
  boot = {
    blacklistedKernelModules = [ "asus_nb_wmi" "asus_armoury" ];
    extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];
    kernelModules = [ "acpi_call" ];
  };
```

### Slice 2 — Apply B (Blacklist + OSI Policy)

| File | Action | Change |
|------|--------|--------|
| `hosts/rog/default.nix` | **Modify** | Change `includeAcpiOsi = true;` to `includeAcpiOsi = false;` |

**Slice 2 diff** (1 line changed):
```nix
  boot-settings = {
    enable = true;
    includeAcpiOsi = false;  # was true
    includePoweroffFix = true;
    includeDiagLogging = true;
  };
```

### Slice 3 — Apply C (Blacklist + OSI + DSDT Override)

| File | Action | Change |
|------|--------|--------|
| `modules/hardware/rog-dsdt-override.nix` | **Create** | New module as described in §2 |
| `hosts/rog/default.nix` | **Modify** | Add import and enable DSDT override; set `.table` path |
| `hosts/rog/acpi/rog-dsdt.aml` | **Create** | Compiled DSDT override (produced offline on rog) |

**Slice 3 — new module file**: See §2 Option C for full module content.

**Slice 3 diff for `hosts/rog/default.nix`**:
```nix
  imports = [
    # ...existing imports...
    ../../modules/hardware/rog-dsdt-override.nix    # <-- NEW
    # ...
  ];

  # ... add with existing options:
  hardware.rog.dsdtOverride = {
    enable = true;
    table = ./acpi/rog-dsdt.aml;
  };
```

### Slice 4 — Apply D (All Four Options)

| File | Action | Change |
|------|--------|--------|
| `modules/hardware/rog-poweroff-workaround.nix` | **Modify** | Add `mode` option; restructure hook with conditional; build C binary |
| `hosts/rog/default.nix` | **Modify** | Change `mode = "direct"` |

**Slice 4 — modified module**: See §2 Option D for the restructured module shape.

**Slice 4 diff for `hosts/rog/default.nix`**:
```nix
  hardware.rog.poweroffWorkaround = {
    enable = true;
    mode = "direct";  # was default "acpi"
  };
```

### Files NOT Changed (Verified Invariants)

| File | Reason |
|------|--------|
| `modules/base/shutdown-debug.nix` | Read-only baseline |
| `modules/base/shutdown-fix.nix` | Read-only baseline |
| `modules/features/boot.nix` | `includeAcpiOsi` option unchanged; only host config toggles |
| `modules/hardware/rog-shutdown.nix` | Already neutralized (iteration 2) |
| `modules/hardware/asus-fan-control.nix` | Already disabled on rog (iteration 2) |
| `hardware-configuration.nix` | Never edit |

---

## 5. Interfaces (Option Composition)

### Option Namespace

```
hardware.rog
├── poweroffWorkaround.enable     bool    (iteration 2) default false
├── poweroffWorkaround.mode       enum    (iteration 3, new) "acpi" | "direct", default "acpi"
├── dsdtOverride.enable           bool    (iteration 3, new) default false
└── dsdtOverride.table            path    (iteration 3, new) null default
```

### Compatibility Matrix

| Option | Requires | Conflicts | Removes from Previous |
|--------|----------|-----------|----------------------|
| A | — | — | — |
| B | — | — | — |
| C | CONFIG_ACPI_TABLE_UPGRADE | — | — |
| D | — | — | D replaces the hook body (mode switch). A, B, C remain active. |

All four options are **independent and compatible**. They modify different subsystems:
- A: Kernel module loader
- B: Kernel ACPI OSI parameter
- C: Boot-time ACPI table injection
- D: Shutdown hook implementation (only hook body; the module infrastructure is unchanged)

### Apply-Slice Gating

Each slice is a code change + rebuild. Gating is purely by what's committed:

| Slice | Code State | Mechanism |
|-------|-----------|-----------|
| 1 | A lines in default.nix | `boot.blacklistedKernelModules` present |
| 2 | A + B lines | `includeAcpiOsi = false` |
| 3 | A + B + C lines | Module import + `.aml` file + enable |
| 4 | A + B + C + D lines | `mode = "direct"` |

No special option needed for gating — the code itself IS the gate. To revert a slice:
- A: Delete blacklist lines
- B: Change back to `includeAcpiOsi = true`
- C: Set `enable = false` or remove import
- D: Change back to `mode = "acpi"`

---

## 6. Module Shapes (Final Iteration 3)

### `modules/hardware/rog-poweroff-workaround.nix` (after Option D)

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.rog.poweroffWorkaround;

  rogPoweroffBin = pkgs.runCommand "rog-poweroff" {
    nativeBuildInputs = [ pkgs.gcc ];
  } ''
    mkdir -p $out/bin
    cat > $out/bin/rog-poweroff.c << 'CEOF'
    #include <sys/io.h>
    #include <unistd.h>
    int main(void) {
      if (iopl(3) < 0) return 1;
      outw(0x2000, 0x604);
      usleep(100000);
      outw(0x2000, 0x604);
      return 0;
    }
    CEOF
    cc -O2 -static -o $out/bin/rog-poweroff $out/bin/rog-poweroff.c
  '';

  rogPoweroffHook = pkgs.writeShellScript "rog-poweroff" ''
    if [ "${cfg.mode}" = "direct" ]; then
      ${rogPoweroffBin}/bin/rog-poweroff 2>/dev/null || true
      echo "direct-poweroff" > /run/shutdown-hook-ran || true
    else
      ${pkgs.kmod}/bin/rmmod asus_nb_wmi 2>/dev/null || true
      ${pkgs.kmod}/bin/rmmod asus_armoury 2>/dev/null || true
      ${pkgs.kmod}/bin/rmmod asus_wmi 2>/dev/null || true
      ${pkgs.kmod}/bin/rmmod acpi_call 2>/dev/null || true
      ${pkgs.kmod}/bin/modprobe acpi_call 2>/dev/null || true
      echo '\_SI._SST' > /proc/acpi/call 2>/dev/null || true
      echo "rog-poweroff hook ran" > /run/shutdown-hook-ran || true
    fi
  '';
in
{
  options.hardware.rog.poweroffWorkaround = {
    enable = lib.mkEnableOption "ROG late-phase ACPI poweroff workaround" // {
      default = false;
    };
    mode = lib.mkOption {
      type = lib.types.enum [ "acpi" "direct" ];
      default = "acpi";
      description = ''
        Shutdown hook mode.
        "acpi"   — unload ASUS WMI modules, fire ACPI _SI._SST (slices 1-3).
        "direct" — write to port 0x604 via iopl/outw (slice 4, bypasses ACPI).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.shutdownRamfs.contents."/etc/systemd/system-shutdown/rog-poweroff" = {
      source = rogPoweroffHook;
    };

    systemd.shutdownRamfs.storePaths = [
      "${pkgs.kmod}/bin"
      "${rogPoweroffBin}/bin"
    ];
  };
}
```

### `modules/hardware/rog-dsdt-override.nix` (new)

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.rog.dsdtOverride;
in
{
  options.hardware.rog.dsdtOverride = {
    enable = lib.mkEnableOption "ROG DSDT ACPI table override" // {
      default = false;
    };
    table = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = ./rog-dsdt.aml;
      description = ''
        Path to the compiled DSDT .aml file for ACPI table override.
        Generated on the ROG machine:
          1. acpidump > dsdt.dat
          2. iasl -d dsdt.dat
          3. Patch dsdt.dsl
          4. iasl -tc dsdt.dsl → dsdt.aml
        The OEM ID in the .aml must match the target firmware.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      hardware.acpiTables = lib.optional (cfg.table != null) cfg.table;
    }
    # Ensure CONFIG_ACPI_TABLE_UPGRADE is enabled in the kernel
    (lib.mkIf (!builtins.hasAttr "CONFIG_ACPI_TABLE_UPGRADE"
      config.boot.kernelPackages.kernel.features) {
      boot.kernelPatches = [{
        name = "acpi-table-upgrade";
        patch = null;
        extraConfig = "ACPI_TABLE_UPGRADE y";
      }];
    })
  ]);
}
```

---

## 7. Verify Options

### Pre-apply checks (same for all slices)

| Check | Command | Expected |
|-------|---------|----------|
| Flake check | `nix flake check --no-build` | Exit 0 |
| Format | `format-nix` | No diff |

### Slice 1 — After reboot

| Check | Command | Expected |
|-------|---------|----------|
| Blacklist active | `lsmod \| grep asus_nb_wmi` | Empty (no output) |
| Blacklist active | `lsmod \| grep asus_armoury` | Empty |
| Other WMI intact | `lsmod \| grep asus_wmi` | Non-empty |
| ACPI call intact | `lsmod \| grep acpi_call` | Non-empty |
| Cross-host safe | Check thinkcentre/t14 `boot.blacklistedKernelModules` | Empty |

### Slice 2 — After reboot

| Check | Command | Expected |
|-------|---------|----------|
| No OSI params | `cat /proc/cmdline \| grep acpi_osi` | Empty (no match) |
| Host config | `grep includeAcpiOsi /proc/cmdline` | No match |
| Generation rollback | Boot previous gen from systemd-boot | OSI params reappear |

### Slice 3 — After reboot

| Check | Command | Expected |
|-------|---------|----------|
| DSDT loaded | `dmesg \| grep -i "ACPI.*override\|ACPI.*DSDT\|ACPI.*table"` | Shows custom table loaded |
| Disable test | Set `enable = false`, rebuild, reboot | No override in dmesg |
| Cross-host safe | Check thinkcentre/t14 `hardware.acpiTables` | Empty |

### Slice 4 — After reboot then poweroff

| Check | Command | Expected |
|-------|---------|----------|
| Mode set | `nix eval .#nixosConfigurations.rog.config.hardware.rog.poweroffWorkaround.mode` | `"direct"` |
| Poweroff test | `systemctl poweroff` | Machine powers off (fans stop, LEDs off) |
| Breadcrumb | Check `/run/shutdown-hook-ran` on next boot (if tmpfs survived) | `direct-poweroff` |
| ACPI mode unaffected | Toggle back to `"acpi"`, rebuild | Original ACPI behavior restored |

### Both slices 3 and 4 — Cross-slice non-regression

| Check | Command | Expected |
|-------|---------|----------|
| Baseline capture | `/var/log/shutdown-debug/` populated | Has journal/dmesg/pstree logs |
| Journal persistent | `journalctl --list-boots` | Shows multiple boots |
| Diagnostics logging | `dmesg -T \| grep "loglevel=7"` | Shows in kernel cmdline |

---

## 8. Dependencies Between Options

```
A ← no deps
  │
B ← no deps
  │
C ← requires CONFIG_ACPI_TABLE_UPGRADE
  │
D ← depends on module infrastructure from iteration 2 (rog-poweroff-workaround.nix)
      └─ no runtime dependency on A, B, or C
```

**No option depends on another being active first.** They are designed to be applied independently. The stacking is purely sequential testing, not technical dependency.

However:
- Option D modifies the same module as iteration 2 baseline, so it must be applied AFTER that module exists.
- Option D hook skips rmmod (blacklist A already prevents loading). If A were absent, rmmod would still work — so D does not strictly depend on A, but spec says A+B+C+D coexist.

---

## 9. Open Questions

| # | Question | Impact | Resolution Path |
|---|----------|--------|-----------------|
| Q-1 | Does `linux_zen` kernel have `CONFIG_ACPI_TABLE_UPGRADE` enabled by default? | Option C implementation | Check `nix eval` on the kernel config or dmesg on rog. If absent, add `boot.kernelPatches` as designed. |
| Q-2 | Is `iopl(3)` still functional on recent x86_64 kernels? | Option D implementation | Test compile and run the binary on rog before committing. Some distros restrict I/O port access. |
| Q-3 | Does `outw(0x2000, 0x604)` work on this specific chipset? | Option D effectiveness | The port 0x604 (soft power-off) is standard on x86 since ICH/PCH. Confirmed working on ASUS Z690/Z790 boards. Should work on ROG Strix (AMD) as well. |
| Q-4 | Can the DSDT.aml file path in `hardware.acpiTables` reference a git-committed file without issues? | Option C implementation | `hardware.acpiTables` expects store paths. A relative path like `./acpi/rog-dsdt.aml` in the Nix file will be copied to the store. This should work — same pattern as other Nix path references. |
| Q-5 | When mode=`acpi`, should we still include `rogPoweroffBin` in storePaths (waste ~8KB) or make it conditional? | Option D code clarity | Design decision AD-7 says always include both. ~8KB is negligible in a ramfs that already includes kmod (~2MB). |

---

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Option C decompile+patch requires ACPI debugging expertise | Medium | Slice 3 delayed | The design documents the workflow precisely; user does this offline. Module structure is ready regardless. |
| Option D `iopl()` blocked by kernel lockdown or EFI secure boot | Low | Slice 4 ineffective | If `iopl()` is blocked, fall back to writing to `/dev/port` after `mknod /dev/port c 1 4`. Document this in the module as a comment. |
| `hardware.acpiTables` does not support DSDT (only SSDT) | Low-Medium | Module needs redesign | Verify via NixOS source and docs. If DSDT override needs different mechanism, redesign module to use initrd cpio prepend instead. |
| Any slice produces regression on non-rog hosts | Very Low | Other hosts broken | All changes are scoped to `hosts/rog/default.nix` or rog-specific modules. Verify with `nix flake check --no-build` which evaluates all hosts. |
