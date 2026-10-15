# flake-bootstrap Specification

## Purpose

Define requirements for a standalone Nix flake in an independent Git repo at `/home/glats/minimal-nix` that provides per-system build outputs for x86_64-linux and aarch64-darwin.

## Requirements

### Requirement: Independent Git Repository

The flake SHALL reside in a new local Git repository at `/home/glats/minimal-nix`. The repository MUST NOT have an origin remote configured. The repository MUST be initialized with `git init` and nothing else.

#### Scenario: Local repo without remote

- GIVEN the directory `/home/glats/minimal-nix` does not exist
- WHEN the repo is created with `git init`
- THEN `git remote -v` produces no output
- AND the working tree is at `/home/glats/minimal-nix`

### Requirement: Flat Flake Structure

The repository MUST have a single top-level `flake.nix`. The flake MUST NOT import any external builder libraries (no `lib/mkHost.nix`). Host modules SHALL be inline or referenced as flat relative-path imports only.

#### Scenario: Flake structure verifies

- GIVEN the `flake.nix` exists at `/home/glats/minimal-nix/flake.nix`
- WHEN `nix flake check --no-build` is run from the repo root
- THEN the flake evaluates without errors
- AND no build actions are executed

### Requirement: Flake Inputs

The flake MUST declare inputs for `nixpkgs` (pinned to `nixos-26.05`), `nix-darwin` (branch `nix-darwin-26.05`), `home-manager` (master branch), and `determinate` (Determinate Nix flake). No sops-nix or omarchy-nix inputs SHALL be present.

#### Scenario: Required inputs are declared

- GIVEN the `flake.nix` inputs block
- WHEN the flake is evaluated
- THEN `nixpkgs` resolves to `github:NixOS/nixpkgs/nixos-26.05`
- AND `nix-darwin` resolves to a `nix-darwin-26.05` ref
- AND `home-manager` and `determinate` resolve to their respective GitHub sources
- AND no secrets-management input (sops-nix, agenix) is present

### Requirement: Per-System Outputs

The flake MUST produce `nixosConfigurations.minimal-linux` and `darwinConfigurations.minimal-mac`. Both outputs SHALL share a common Home Manager configuration. No `homeConfigurations` standalone output is required.

#### Scenario: All expected outputs are exposed

- GIVEN the flake outputs function
- WHEN `nix eval .#nixosConfigurations.minimal-linux.config.system.build.toplevel.drvPath` is run
- THEN a valid derivation path is returned
- WHEN `nix eval .#darwinConfigurations.minimal-mac.config.system.build.toplevel.drvPath` is run
- THEN a valid derivation path is returned

### Requirement: Formatter

The flake MUST define `formatter.x86_64-linux` pointing to `nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style`.

#### Scenario: Formatter is available

- GIVEN the flake at `/home/glats/minimal-nix`
- WHEN `nix fmt .#` is run
- THEN Nix files in the repo are formatted
