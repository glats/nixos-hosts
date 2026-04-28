# Version Update Specification

## Purpose

Update the gentle-ai binary and source from v1.21.0 to v1.24.1 while maintaining build integrity and reproducibility.

## Requirements

### Requirement: Binary Version Update

The system MUST update the gentle-ai package version from 1.21.0 to 1.24.1 in `pkgs/gentle-ai/default.nix`.

#### Scenario: Version field updated

- GIVEN `pkgs/gentle-ai/default.nix` with `version = "1.21.0"`
- WHEN the version update is applied
- THEN the version field reads `version = "1.24.1"`
- AND the download URL reflects the new version

#### Scenario: Hash updated for new binary

- GIVEN version is updated to 1.24.1
- WHEN the hash is computed
- THEN `sha256` matches the v1.24.1 linux_amd64 tarball
- AND the hash is NOT the v1.21.0 hash

### Requirement: Source Input Update

The system MUST update the `gentle-ai-src` flake input to reference the v1.24.1 tag.

#### Scenario: Flake input points to correct tag

- GIVEN `flake.nix` with `gentle-ai-src` input
- WHEN the input is updated
- THEN the URL references tag v1.24.1
- AND the flake.lock is updated accordingly

### Requirement: Flake Lock Update

The system MUST update `flake.lock` to reflect the new `gentle-ai-src` revision.

#### Scenario: Lock file updated

- GIVEN `flake.nix` with updated `gentle-ai-src`
- WHEN `nix flake lock --update-input gentle-ai-src` runs
- THEN `flake.lock` contains the new revision hash
- AND the `lastModified` timestamp reflects v1.24.1

#### Scenario: Lock file is valid

- GIVEN an updated `flake.lock`
- WHEN `nix flake check` runs
- THEN the lock file resolves without errors
- AND all inputs are fetchable

### Requirement: Build Verification

The system MUST verify the updated gentle-ai package builds successfully.

#### Scenario: Package builds from source

- GIVEN updated version and hash in `default.nix`
- WHEN `nix build .#gentle-ai` runs
- THEN the derivation builds without errors
- AND the output contains a valid `gentle-ai` binary

#### Scenario: Binary runs and reports version

- GIVEN a built gentle-ai package
- WHEN `./result/bin/gentle-ai --version` runs
- THEN the output includes `1.24.1`
- AND the exit code is 0
