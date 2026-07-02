# Artifact-Store-Aware Dispatcher Selection Specification

## Purpose

Ensure the SDD runtime routes status and continuity queries to the correct backend based on the selected artifact store mode, and that the deployed binary and assets are version-aligned so store-aware guards function correctly.

## Requirements

### Requirement: Store-Mode Dispatcher Gate

The runtime orchestrator and status commands MUST inspect the active artifact store mode before invoking the native `gentle-ai` dispatcher. The native dispatcher SHALL be treated as authoritative ONLY when the artifact store is `openspec`. For `engram` and `hybrid` stores, the runtime MUST resolve status from Engram artifacts and MUST NOT surface native OpenSpec-only blocked responses as final output.

#### Scenario: Engram-only change with native dispatcher available

- GIVEN the artifact store mode is `engram`
- AND a change exists only in Engram (no `openspec/changes/{name}/` directory)
- AND the `gentle-ai` binary is available on PATH
- WHEN the orchestrator resolves change status
- THEN the runtime SHALL query Engram for the change state
- AND the runtime SHALL NOT invoke the native `gentle-ai sdd-status` dispatcher
- AND the runtime SHALL return the correct next recommended phase from Engram artifacts

#### Scenario: Hybrid-mode change with both stores populated

- GIVEN the artifact store mode is `hybrid`
- AND a change exists in both Engram and `openspec/changes/`
- WHEN the orchestrator resolves change status
- THEN the runtime MAY invoke the native dispatcher to validate the OpenSpec side
- AND the runtime SHALL also query Engram for the Engram-side state
- AND the runtime SHALL use `hybrid` as the canonical store token in all contracts and logs

#### Scenario: OpenSpec-only change remains unaffected

- GIVEN the artifact store mode is `openspec`
- AND a change exists in `openspec/changes/{name}/`
- WHEN the orchestrator resolves change status
- THEN the runtime SHALL invoke the native `gentle-ai sdd-status` dispatcher
- AND the dispatcher output SHALL be treated as authoritative

#### Scenario: Engram-only change with stale openspec directory present

- GIVEN the artifact store mode is `engram`
- AND unrelated active changes exist in `openspec/changes/`
- AND the target change exists only in Engram
- WHEN the orchestrator resolves change status for the target change
- THEN the runtime SHALL NOT be misled by the presence of other OpenSpec changes
- AND the runtime SHALL resolve status exclusively from Engram

### Requirement: Binary and Asset Version Alignment

The `gentle-ai` binary version and the `gentle-ai-src` flake input version MUST be identical. The `gentle-ai-assets` and `gentle-ai-assets-vanilla` packages derive their content from `gentle-ai-src`, so the flake pin and the binary package version MUST be updated together to prevent behavioral drift between the binary's status engine and the deployed orchestration prompts.

#### Scenario: Version bump propagates to all packages

- GIVEN the flake pins `gentle-ai-src` at version `v1.42.0`
- AND `pkgs/gentle-ai/default.nix` declares `version = "1.42.0"`
- WHEN the flake is built
- THEN the binary, assets-vanilla, and assets packages SHALL all reflect v1.42.0 content
- AND the deployed runtime orchestrator SHALL include the store-aware dispatcher guard

#### Scenario: Version mismatch is not introduced

- GIVEN a version bump to `gentle-ai-src` in `flake.nix`
- WHEN the change is applied
- THEN `pkgs/gentle-ai/default.nix` version field SHALL match the flake input tag
- AND the sha256 hashes for linux and darwin SHALL be updated to match the new release binaries

### Requirement: Canonical Store Token Terminology

All SDD contracts, phase skills, preflight mappings, and orchestrator rules SHALL use `hybrid` as the canonical token for the dual-store artifact mode. The token `both` SHALL NOT appear as a store mode identifier.

#### Scenario: Preflight mapping uses hybrid token

- GIVEN a session configures artifact store mode
- WHEN the preflight or mode-selection logic maps store identifiers
- THEN the dual-store mode SHALL be identified as `hybrid`
- AND the token `both` SHALL NOT be emitted or accepted as a store mode

#### Scenario: Phase skills reference consistent terminology

- GIVEN any SDD phase skill or shared contract references artifact store modes
- WHEN the store mode list is enumerated
- THEN the valid values SHALL be `openspec`, `engram`, and `hybrid`
- AND no reference to `both` as a store mode SHALL exist
