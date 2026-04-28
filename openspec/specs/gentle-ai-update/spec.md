# Gentle AI Update Specification

## Purpose

Define a documented, streamlined update workflow for upgrading Gentle AI, ensuring binary version, flake input tag, and sync marker stay synchronized.

## Requirements

### Requirement: Update Workflow Documentation

A document `docs/gentle-ai-update.md` MUST exist that describes the complete step-by-step process for updating Gentle AI to a new version.

#### Scenario: Documentation covers all update steps

- GIVEN a maintainer needs to update Gentle AI from v1.21.0 to v1.22.0
- WHEN they follow `docs/gentle-ai-update.md`
- THEN the document instructs them to:
  1. Update binary version in `pkgs/gentle-ai/default.nix`
  2. Update `gentle-ai-src` tag in `flake.nix` to match
  3. Run `nix flake lock --update-input gentle-ai-src`
  4. Update `.last-sync` marker
  5. Build and verify: `nix build .#gentle-ai-assets && nix flake check`

#### Scenario: Documentation includes verification steps

- GIVEN the update steps are complete
- WHEN following the document
- THEN it includes commands to verify the update succeeded
- AND it specifies what to check (build passes, flake check passes, version consistency)

### Requirement: Version Consistency After Update

After following the update workflow, the binary version, flake input tag, and `.last-sync` marker MUST all reflect the same version.

#### Scenario: All version references match after update

- GIVEN the update workflow is followed for v1.22.0
- WHEN inspecting the repository
- THEN `pkgs/gentle-ai/default.nix` has `version = "1.22.0"`
- AND `flake.nix` `gentle-ai-src.url` contains `v1.22.0`
- AND `.last-sync` references `v1.22.0`

### Requirement: Update Script Compatibility

The existing `updateScript` in `pkgs/gentle-ai/default.nix` MUST continue to function after the refactor, updating the binary version and hash.

#### Scenario: Update script runs successfully

- GIVEN the `update-gentle-ai` script exists
- WHEN the script is executed
- THEN it updates `version` and `sha256` in `pkgs/gentle-ai/default.nix`
- AND it does NOT modify `flake.nix` (that remains a manual step per the workflow)
