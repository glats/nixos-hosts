# nixos-host Specification

## Purpose

Define requirements for the `minimal-linux` NixOS configuration: boot, networking, the `claudio` user, and a kmscon console safe for 256-color applications.

## Requirements

### Requirement: Boot and Networking Minimum

The `minimal-linux` host MUST boot via systemd-boot (UEFI). IPv4 DHCP networking SHALL be enabled. SSH daemon MUST be started.

#### Scenario: Minimal boot configuration

- GIVEN the `minimal-linux` configuration module
- WHEN `services.openssh.enable` is true
- AND `systemd.network.enable` is true with DHCP on all interfaces
- AND `boot.loader.systemd-boot.enable` is true
- THEN the configuration evaluates without boot-related type errors

### Requirement: Claudio User and Password

The system MUST define user `claudio` with `isNormalUser = true`, membership in the `wheel` group, and an initial hashed password.

#### Scenario: User claudio is defined

- GIVEN the `minimal-linux` config
- WHEN `users.users.claudio.isNormalUser` is true
- AND `users.users.claudio.extraGroups` includes `wheel`
- AND `users.users.claudio.initialHashedPassword` is set
- THEN the user can log in after first boot
- AND the user is not `glats` or any other host-specific name

### Requirement: KMS Con Safe Console

The console SHALL be kmscon with `hwRender = false`, `useXkbConfig = true`, and no truecolor claim. `TERM` MUST default to `xterm-256color`. No `COLORTERM` environment variable SHALL be set in the kmscon configuration or any system-wide profile.

#### Scenario: KMS con is 256-color honest

- GIVEN `minimal-linux` with `services.kmscon.enable = true`
- AND `services.kmscon.hwRender = false`
- AND `services.kmscon.useXkbConfig = true`
- WHEN the system boots to console
- THEN `echo $TERM` reports `xterm-256color`
- AND `echo $COLORTERM` produces empty output
- AND 256-color SGR sequences render correctly

#### Scenario: No truecolor override leaks in

- GIVEN `minimal-linux` system configuration
- WHEN the configuration is searched
- THEN no `COLORTERM=truecolor` assignment exists in environment variables, shell profiles, or kmscon extraConfig
