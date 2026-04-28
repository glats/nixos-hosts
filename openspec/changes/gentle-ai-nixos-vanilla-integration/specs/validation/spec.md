# Validation Specification

## Purpose

Verify the updated configuration builds, passes checks, and functions correctly on both target hosts (rog and thinkcentre).

## Requirements

### Requirement: Flake Check Pass

The system MUST pass `nix flake check` with no errors or warnings after all changes.

#### Scenario: Flake check succeeds

- GIVEN all changes are applied
- WHEN `nix flake check` runs
- THEN the exit code is 0
- AND no error or warning messages are printed

#### Scenario: Flake check with stale lock

- GIVEN `flake.lock` is out of date
- WHEN `nix flake check` runs
- THEN it reports the lock file needs updating
- AND provides the command to fix it

### Requirement: Multi-Host Build

The system MUST build successfully on both `rog` and `thinkcentre` host configurations.

#### Scenario: rog host builds

- GIVEN updated flake with v1.24.1
- WHEN `nixos-rebuild build --flake .#rog` runs
- THEN the build completes without errors
- AND all modules evaluate correctly

#### Scenario: thinkcentre host builds

- GIVEN updated flake with v1.24.1
- WHEN `nixos-rebuild build --flake .#thinkcentre` runs
- THEN the build completes without errors
- AND all modules evaluate correctly

#### Scenario: Build fails on one host

- GIVEN a configuration error specific to one host
- WHEN the build runs for that host
- THEN the build fails with a clear error message
- AND the other host build is unaffected

### Requirement: Opendcode Startup Verification

The system MUST verify that opencode starts correctly with the updated gentle-ai skills.

#### Scenario: Opendcode starts without errors

- GIVEN updated skills are in place
- WHEN opencode is launched
- THEN it starts without skill loading errors
- AND all skills are accessible

#### Scenario: Skill loading verified

- GIVEN opencode is running
- WHEN a skill-dependent command is invoked
- THEN the skill loads and executes correctly
- AND no "skill not found" errors occur

### Requirement: Basic Functionality Test

The system MUST verify core functionality works after the update.

#### Scenario: gentle-ai binary executes

- GIVEN the updated gentle-ai package
- WHEN `gentle-ai --help` runs
- THEN help text is displayed
- AND the exit code is 0

#### Scenario: gentle-ai-assets builds

- GIVEN updated gentle-ai-src input
- WHEN `nix build .#gentle-ai-assets` runs
- THEN the derivation builds successfully
- AND the output contains expected skill files
