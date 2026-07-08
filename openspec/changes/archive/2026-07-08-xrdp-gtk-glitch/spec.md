# Spec: xrdp Compositor Configuration

## Purpose

Define compositor behavior for xrdp-serving hosts (rog, thinkcentre) to fix GTK/MATE panel rendering in virtual X11 sessions.

## Requirements

### Requirement: External compositors MUST NOT be active on xrdp hosts

picom's XRender backend is incompatible with xrdp's virtual frame buffer (upstream: yshui/picom#1433). The rog and thinkcentre hosts SHALL NOT import or enable picom.

#### Scenario: rog home modules exclude picom

- GIVEN the rog host Home Manager configuration
- WHEN the home module import list is evaluated
- THEN `home-linux/picom.nix` is NOT in the import list

#### Scenario: thinkcentre home modules exclude picom

- GIVEN the thinkcentre host Home Manager configuration
- WHEN the home module import list is evaluated
- THEN `home-linux/picom.nix` is NOT in the import list

### Requirement: marco compositing SHALL be enabled on MATE hosts

marco's built-in `compositor-xrender.c` works correctly in the software rendering mode provided by xrdp virtual X sessions. On hosts with `config.my.desktop.suite == "mate"`, the dconf key `org/mate/marco/general/compositing-manager` SHALL be set to `true` without a lock.

#### Scenario: MATE hosts enable marco compositing

- GIVEN a host where `my.desktop.suite == "mate"`
- WHEN dconf settings are evaluated
- THEN `compositing-manager` is set to `true` and not locked

#### Scenario: Non-MATE hosts unaffected

- GIVEN a host where `my.desktop.suite != "mate"` (e.g., t14 with Hyprland)
- WHEN dconf settings are evaluated
- THEN no marco-related dconf keys are set or locked

### Requirement: Build-time validation SHALL pass for affected hosts

The configuration change SHALL pass `nix flake check --no-build` for both rog and thinkcentre hosts.

#### Scenario: Flake check passes for both hosts

- GIVEN the compositor changes applied
- WHEN `nix flake check --no-build` executes
- THEN both rog and thinkcentre configurations evaluate without errors

## Non-Goals

- t14 and mact2 hosts SHALL remain unchanged
- `home-linux/picom.nix` SHALL remain in the repository for potential future use
- No xrdp service configuration changes are made
