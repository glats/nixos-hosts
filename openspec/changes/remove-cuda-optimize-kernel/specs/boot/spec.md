# boot Specification

## Purpose

Shared boot configuration (systemd-boot, plymouth, kernel params). Kernel selection is per-host, not shared. Applies to rog, thinkcentre, and t14.

## Requirements

### Requirement: No Shared Kernel

The `boot.nix` module MUST NOT set `boot.kernelPackages`. Kernel selection MUST be configured explicitly in each host's `default.nix`.

#### Scenario: boot.nix does not set kernel

- GIVEN `boot.nix` is imported by any host
- WHEN the module is evaluated
- THEN `boot.kernelPackages` MUST NOT be set

### Requirement: Per-Host Kernel Declaration

Every Linux host MUST explicitly declare `boot.kernelPackages` in its `default.nix`.

#### Scenario: rog uses cached default kernel

- GIVEN `hosts/rog/default.nix` is loaded
- WHEN `boot.kernelPackages` is evaluated
- THEN it MUST equal `pkgs.linuxPackages`

#### Scenario: thinkcentre uses cached default kernel

- GIVEN `hosts/thinkcentre/default.nix` is loaded
- WHEN `boot.kernelPackages` is evaluated
- THEN it MUST equal `pkgs.linuxPackages`

#### Scenario: t14 keeps zen kernel

- GIVEN `hosts/t14/default.nix` is loaded
- WHEN `boot.kernelPackages` is evaluated
- THEN it MUST equal `pkgs.linuxPackages_zen`

### Requirement: Preserved Boot Configuration

All other boot settings (systemd-boot, plymouth, kernel params) MUST remain unchanged.

#### Scenario: Boot config unchanged after kernel removal

- GIVEN `boot.nix` is imported with `boot-settings.enable = true`
- WHEN the module is evaluated
- THEN `systemd-boot` MUST be enabled
- AND `plymouth` MUST be enabled
- AND `kernelParams` MUST include `quiet`, `splash`, and `loglevel=3`
