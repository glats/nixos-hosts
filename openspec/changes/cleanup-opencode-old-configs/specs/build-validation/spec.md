# Delta for Build Validation

## Purpose

Ensure all build integrity checks pass after cleanup — both hosts must build, flake must validate, and formatting must be correct.

## ADDED Requirements

### Requirement: Flake Validation

After all changes, `nix flake check` MUST pass with zero errors and zero warnings.

#### Scenario: Flake check passes clean

- GIVEN all script deletions and module edits are applied
- WHEN running `nix flake check`
- THEN exit code is 0
- AND no errors or warnings are printed

### Requirement: Nix Formatting

All modified `.nix` files MUST conform to `nixfmt` formatting standards.

#### Scenario: Format check produces no changes

- GIVEN all `.nix` file edits are applied
- WHEN running `format-nix`
- THEN no files are modified (or all modifications are committed)
- AND exit code is 0

### Requirement: Multi-Host Build

Both hosts (`rog` and `thinkcentre`) MUST build successfully after cleanup.

#### Scenario: rog host builds

- GIVEN the cleanup changes are applied
- WHEN running `nixos-build` targeting the `rog` host
- THEN the build completes without errors
- AND the system can be activated

#### Scenario: thinkcentre host builds

- GIVEN the cleanup changes are applied
- WHEN running `nixos-build` targeting the `thinkcentre` host
- THEN the build completes without errors
- AND the system can be activated
