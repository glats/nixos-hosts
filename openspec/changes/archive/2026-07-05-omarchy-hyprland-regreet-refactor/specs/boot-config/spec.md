# Delta Spec: boot-config

> Domain: Boot configuration consolidation for t14 host.
> Host: t14 only.
> Source files: `modules/features/boot.nix` (to be deleted), `hosts/t14/default.nix` (to be modified).

---

## REMOVED Requirements

### REQ-BC-001: Remove boot-settings custom module

**What**: The `modules/features/boot.nix` file and its `boot-settings.*` option namespace SHALL be removed from the repository.

**Why**: The `boot-settings` module is a thin wrapper around standard `boot.*` NixOS options. It adds a layer of indirection (`boot-settings.enable = true`, `boot-settings.includeAcpiOsi`, etc.) without providing any abstraction beyond what `boot.*` already offers. The module exists to share boot config across hosts, but in practice only t14 uses it (rog has its own boot config, thinkcentre has its own, mact2 is darwin). The indirection causes confusion: developers must cross-reference two files to understand what `boot` settings are active.

**(Reason: redundant wrapper around standard `boot.*` options; only used by t14)**

**(Migration: Move the `boot.*` settings directly into `hosts/t14/default.nix`)**

#### Scenario: boot-settings module is deleted

- **Given** `modules/features/boot.nix` currently defines `options.boot-settings` and `config.boot.*`
- **When** the module is deleted from the filesystem
- **Then** `imports` in `hosts/t14/default.nix` SHALL NOT reference `../../modules/features/boot.nix`
- **And** `boot-settings.enable` SHALL NOT appear anywhere in the t14 config
- **And** `nix flake check --no-build` SHALL pass after the equivalent `boot.*` options are added directly

#### Scenario: No other host references boot-settings

- **Given** the `boot-settings` module is only imported by t14
- **When** the module is removed
- **Then** no other host (`rog`, `thinkcentre`, `mact2`) SHALL be affected
- **And** `nixos-build dry` for any non-t14 host SHALL report no changes

---

## ADDED Requirements

### REQ-BC-002: Declare boot options directly in t14/default.nix

**What**: The t14 host SHALL configure its bootloader, kernel, and quiet boot parameters directly using standard `boot.*` NixOS options in `hosts/t14/default.nix`, replacing the removed `boot-settings` wrapper.

**Migration mapping**: Every value currently set by `boot-settings.enable = true` SHALL be preserved. The mapping is:

| Old (`boot-settings` wrapper) | New (direct `boot.*`) |
|---|---|
| `boot-settings.enable = true` | Direct `boot` attrset in `hosts/t14/default.nix` |
| `boot.loader.systemd-boot.enable = true` | Same — `boot.loader.systemd-boot.enable = true` |
| `boot.loader.systemd-boot.configurationLimit = 3` | Same |
| `boot.loader.efi.canTouchEfiVariables = true` | Same |
| `boot.plymouth.enable = true` | Same |
| `boot.consoleLogLevel = 0` | Same |
| `boot.initrd.verbose = false` | Same |
| `boot.kernelPackages = pkgs.linuxPackages_zen` | Same |
| All kernelParams (quiet, splash, loglevel=3, etc.) | Same — `boot.kernelParams = [...]` |

The t14 host does NOT use `includeAcpiOsi`, `includePoweroffFix`, or `includeDiagLogging` — these are rog-specific and SHALL NOT be carried over to the direct config.

#### Scenario: Boot config produces identical binary output

- **Given** the `boot-settings.enable = true` configuration is replaced with direct `boot.*` options
- **When** `nixos-build dry` is run for t14
- **Then** the generated system profile SHALL be identical to the previous generation
- **And** no bootloader changes SHALL be detected

#### Scenario: All boot settings are in one place

- **Given** the `boot-settings` module is removed
- **When** a developer reads `hosts/t14/default.nix`
- **Then** all boot configuration SHALL be visible in one contiguous block
- **And** the boot section SHALL include a comment referencing the removed `modules/features/boot.nix` for historical context

#### Scenario: Quiet boot behavior is preserved

- **Given** the new direct boot configuration
- **When** the t14 boots
- **Then** the kernel command line SHALL include `quiet splash loglevel=3 boot.shell_on_fail rd.systemd.show_status=false rd.udev.log_level=3 udev.log_priority=3 vt.global_cursor_default=0`
- **And** `boot.consoleLogLevel` SHALL be `0`
- **And** `boot.initrd.verbose` SHALL be `false`
- **And** Plymouth SHALL be enabled

#### Scenario: Zen kernel is preserved

- **Given** the new direct boot configuration
- **When** Home Manager activation evaluates kernel packages
- **Then** `boot.kernelPackages` SHALL be `pkgs.linuxPackages_zen`

#### Scenario: systemd-boot with 3-generation limit is preserved

- **Given** the new direct boot configuration
- **When** the system is built and switched
- **Then** systemd-boot SHALL be the active bootloader
- **And** SHALL keep at most 3 generations in the boot menu

#### Scenario: Non-t14 hosts are unaffected

- **Given** `rog` uses its own boot config (i3 + nvidia), `thinkcentre` uses its own (KDE + grub), `mact2` is darwin
- **When** `boot-settings` is removed and t14 uses direct config
- **Then** `nix flake check --no-build` SHALL pass for all hosts
- **And** `nixos-build dry` for rog SHALL report no boot changes
- **And** `nixos-build dry` for thinkcentre SHALL report no boot changes
