# Hyprland Ownership Boundary Specification

## Purpose

Defines the provider/consumer boundary for Hyprland package selection across the NixOS module stack. Ensures a single ownership layer (upstream omarchy-nix NixOS module) controls package/provider selection, while Home Manager defers and local consumer repos remain config-only.

## Requirements

### Requirement: Upstream NixOS Module Owns Hyprland Package Selection

The upstream omarchy-nix NixOS module (`modules/nixos/hyprland.nix`) MUST be the sole owner of `programs.hyprland.package` and `programs.hyprland.portalPackage` defaults. It SHALL use `pkgs.hyprland` and `pkgs.xdg-desktop-portal-hyprland` from nixpkgs as the default values. Local host configurations MUST NOT override these options with `lib.mkForce` or equivalent priority escalation.

#### Scenario: Upstream provides nixpkgs Hyprland defaults

- GIVEN the omarchy-nix NixOS module is imported in a host configuration
- WHEN no local override exists for `programs.hyprland.package`
- THEN the system uses `pkgs.hyprland` from nixpkgs as the Hyprland package
- AND the system uses `pkgs.xdg-desktop-portal-hyprland` from nixpkgs as the portal package

#### Scenario: Local host does not force-override package selection

- GIVEN a host configuration under `hosts/t14/default.nix`
- WHEN the configuration is evaluated
- THEN no `lib.mkForce` assignment exists on `programs.hyprland.package` or `programs.hyprland.portalPackage`
- AND the `programs.hyprland` block is absent from the host file

### Requirement: Home Manager Layer Defers to NixOS Layer

The omarchy-nix Home Manager module (`modules/home-manager/hyprland.nix`) MUST set `wayland.windowManager.hyprland.package` and `wayland.windowManager.hyprland.portalPackage` to `lib.mkDefault null` when `programs.hyprland.enable` is active in the NixOS layer. This ensures HM never selects a competing package when running in NixOS-integrated mode.

#### Scenario: HM defers package selection to NixOS in integrated mode

- GIVEN the omarchy-nix HM module is loaded with `programs.hyprland.enable = true` at the NixOS level
- WHEN the HM configuration is evaluated
- THEN `wayland.windowManager.hyprland.package` resolves to `null` via `mkDefault`
- AND `wayland.windowManager.hyprland.portalPackage` resolves to `null` via `mkDefault`
- AND the effective Hyprland package comes from the NixOS `programs.hyprland.package` option

#### Scenario: Local HM config does not null-bridge packages

- GIVEN a host's Home Manager configuration under `hosts/t14/home/omarchy.nix`
- WHEN the configuration is evaluated
- THEN no explicit `wayland.windowManager.hyprland.package = null` or `wayland.windowManager.hyprland.portalPackage = null` assignment exists in the local file
- AND the null-defer behavior is provided entirely by the upstream HM module

### Requirement: Local Consumer Repo Must Not Force-Own Hyprland Packages

The local NixOS configuration repository (`hosts/t14/`) MUST NOT contain any `lib.mkForce`, `lib.mkOverride`, or direct assignment on Hyprland package options. All Hyprland package policy MUST reside in the upstream omarchy-nix flake inputs.

#### Scenario: Scattered overrides removed after upstream boundary fix

- GIVEN the current state has scattered `mkForce` overrides in `hosts/t14/default.nix` and null-bridges in `hosts/t14/home/omarchy.nix`
- WHEN the upstream omarchy-nix commit with boundary ownership is merged and the flake input is bumped
- THEN the `programs.hyprland` force-override block is deleted from `hosts/t14/default.nix`
- AND the `wayland.windowManager.hyprland` null-bridge is deleted from `hosts/t14/home/omarchy.nix`
- AND the diff in `hosts/t14/` contains only deletions, no new override logic

#### Scenario: Flake check passes after cleanup

- GIVEN the local Hyprland overrides have been removed
- WHEN `nix flake check --no-build` is executed
- THEN the check passes without errors related to Hyprland package evaluation
- AND no undefined option or missing package errors surface
