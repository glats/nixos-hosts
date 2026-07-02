# gentle-ai-asset-overlay Specification

## Purpose

Generic file-overlay mechanism for the `gentle-ai-assets` derivation. Allows arbitrary files to be layered on top of vanilla upstream assets, surviving `nixos-build switch` without manual patching. Primary use case: anti-hallucination notes that prevent SDD sub-agents from conflating Engram topic keys (`sdd/...`) with filesystem paths (`openspec/...`).

## Requirements

### Requirement: extraAssets Derivation Parameter

The `gentle-ai-assets` derivation MUST accept an optional `extraAssets` parameter of type path (default: `null`). When non-null, the derivation SHALL recursively copy the contents of `${extraAssets}` over the vanilla asset tree, with later files overwriting earlier ones. The overlay directory structure MUST mirror `$out/share/gentle-ai/` exactly.

#### Scenario: extraAssets provided with override files

- GIVEN `extraAssets` points to a directory containing `opencode/sdd-orchestrator.md`
- WHEN the `gentle-ai-assets` derivation builds
- THEN `$out/share/gentle-ai/opencode/sdd-orchestrator.md` SHALL contain the overlay version
- AND all other files SHALL remain identical to vanilla

#### Scenario: extraAssets is null (no-op)

- GIVEN `extraAssets` is `null` (default)
- WHEN the `gentle-ai-assets` derivation builds
- THEN output SHALL be identical to vanilla (no files added, modified, or removed)

#### Scenario: extraAssets contains nested skill overrides

- GIVEN `extraAssets` contains `skills/sdd-explore/SKILL.md`
- WHEN the derivation builds
- THEN `$out/share/gentle-ai/skills/sdd-explore/SKILL.md` SHALL be the overlay version
- AND all other skill files SHALL remain vanilla

### Requirement: sharedOpencodePaths Wiring

`lib/packages.nix` MUST expose `extraAssets` via the `sharedOpencodePaths` attribute set and pass it to both `linuxPackages.gentle-ai-assets` and `darwinPackages.gentle-ai-assets`. The path SHALL point to `shared/opencode/assets`.

#### Scenario: Both platforms receive extraAssets

- GIVEN `sharedOpencodePaths` includes `extraAssets = ./../shared/opencode/assets`
- WHEN `lib/packages.nix` is evaluated
- THEN both `linuxPackages.gentle-ai-assets` and `darwinPackages.gentle-ai-assets` SHALL receive the same `extraAssets` path

### Requirement: Anti-Hallucination Override Files

The `shared/opencode/assets/` directory MUST contain override files for `sdd-orchestrator.md`, `skills/sdd-explore/SKILL.md`, and `skills/sdd-init/SKILL.md`. Each override file SHALL contain an explicit note distinguishing Engram topic keys (prefix `sdd/`) from filesystem paths (`openspec/`).

#### Scenario: Override files contain anti-hallucination note

- GIVEN the overlay assets directory exists
- WHEN each of the 3 override files is inspected
- THEN each file SHALL contain text explicitly stating that `sdd/` prefixes are Engram topic keys, NOT filesystem paths
- AND each file SHALL state the canonical filesystem path prefix is `openspec/`

### Requirement: Orchestrator Source Switch

`shared/opencode.nix` MUST source `sdd-orchestrator.md` from the layered `gentle-ai-assets` derivation (not `gentle-ai-assets-vanilla`) so that overlay content is deployed to `~/.config/opencode/sdd-orchestrator.md`.

#### Scenario: Activated system uses layered asset

- GIVEN `extraAssets` contains an override for `sdd-orchestrator.md`
- WHEN `nixos-build switch` completes
- THEN `~/.config/opencode/sdd-orchestrator.md` SHALL contain the anti-hallucination note

#### Scenario: Flake update does not regress overrides

- GIVEN a flake update changes upstream `sdd-orchestrator.md` text
- WHEN `nixos-build switch` runs
- THEN the anti-hallucination override SHALL still be present in `~/.config/opencode/sdd-orchestrator.md`

### Requirement: Vanilla Drift Safety

When upstream vanilla content changes (via `nix flake update`), the overlay MUST NOT silently lose override content. The overlay files are independent copies — upstream changes to overridden files SHALL NOT affect the overlay output unless the overlay files themselves are updated.

#### Scenario: Upstream changes non-overridden file

- GIVEN a flake update modifies `skills/sdd-tasks/SKILL.md` in vanilla
- AND `extraAssets` does NOT contain an override for `sdd-tasks`
- WHEN the derivation builds
- THEN the output SHALL reflect the new upstream version of `sdd-tasks/SKILL.md`
