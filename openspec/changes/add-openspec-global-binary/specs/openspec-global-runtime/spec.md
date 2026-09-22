# openspec-global-runtime Specification

## Purpose

Make the bare `openspec` CLI resolvable on the interactive shell PATH of every
Home Manager user across all Linux and Darwin hosts, independent of any project
directory. The binary MUST come exclusively from the pinned Nixpkgs
`pkgs.openspec` attribute — no GitHub flake input, overlay, or wrapper.

## Requirements

### Requirement: Global PATH availability of `openspec`

The Home Manager user's interactive shell MUST resolve the bare `openspec`
command from PATH on every Linux host (`rog`, `thinkcentre`, `t14`) and every
Darwin host (`macm5`), regardless of the current working directory or whether a
project has been initialized.

#### Scenario: `openspec` resolves on a Linux host shell

- GIVEN a Home Manager activation has completed on `rog`, `thinkcentre`, or `t14`
- WHEN the user runs `openspec --version` from an arbitrary directory
- THEN the command executes the Nixpkgs `openspec` binary and prints its version
- AND exit status is 0

#### Scenario: `openspec` resolves on the Darwin host shell

- GIVEN a Home Manager activation has completed on `macm5`
- WHEN the user runs `openspec --version` from an arbitrary directory
- THEN the command executes the Nixpkgs `openspec` binary and prints its version
- AND exit status is 0

#### Scenario: availability is independent of project initialization

- GIVEN a directory with no SDD project or `project-init` state
- WHEN the user runs `openspec list --json`
- THEN the command succeeds using the global binary
- AND no project initialization is a precondition for the command to resolve

### Requirement: Nixpkgs-pinned source, no GitHub flake input

The `openspec` binary SHALL be sourced solely from the pinned Nixpkgs
`pkgs.openspec` attribute already available to the flake. The change MUST NOT
introduce a GitHub flake input, an overlay, a wrapper script, or a custom
derivation for `openspec`.

#### Scenario: source is the pinned Nixpkgs attribute

- GIVEN the Nix flake has nixpkgs pinned to `nixos-26.05`
- WHEN the Home Manager configuration is evaluated
- THEN `openspec` resolves to the `pkgs.openspec` attribute from that pin
- AND no additional flake input, overlay, or wrapper is added

#### Scenario: binary collision is avoided

- GIVEN `project-init` may also expose `openspec` on some hosts
- WHEN both the global package and any wrapped variant resolve
- THEN both derive from the same pinned Nixpkgs `openspec` derivation
- AND no separate wrapper changes the CLI's identity or version

### Requirement: Idempotent, additive package-list change

The change SHALL only append `pkgs.openspec` to the existing `home.packages`
lists in `linux/home/shell.nix` and `darwin/home/shell.nix`. It MUST NOT remove,
rename, reorder, or otherwise alter any existing package in either list, and
re-applying the change MUST NOT duplicate or strip entries.

#### Scenario: existing packages are preserved on Linux

- GIVEN `linux/home/shell.nix` declares `home.packages` including
  `pkgs.nixos-scripts` and `pkgs.qrencode`
- WHEN the change is applied
- THEN those packages remain present and installed
- AND `pkgs.openspec` is added as an additional entry

#### Scenario: existing package is preserved on Darwin

- GIVEN `darwin/home/shell.nix` declares `home.packages` including
  `pkgs.nixos-scripts`
- WHEN the change is applied
- THEN `pkgs.nixos-scripts` remains present and installed
- AND `pkgs.openspec` is added as an additional entry

#### Scenario: idempotent re-application

- GIVEN the change has already been applied once
- WHEN the configuration is re-evaluated and re-activated
- THEN `openspec` appears exactly once on PATH
- AND no package is removed or duplicated

### Requirement: No coupling to `add-project-init`

Availability of the global `openspec` binary MUST remain fully independent of
the `add-project-init` change and the `project-init` Go binary. This change MUST
NOT modify `add-project-init`, `project-init`, or `pkgs/nixos-scripts`.

#### Scenario: global binary works without project-init changes

- GIVEN the `add-project-init` change is not applied
- WHEN a Home Manager user runs `openspec --version`
- THEN the global binary resolves and executes successfully
- AND no `project-init` behavior is required or invoked
