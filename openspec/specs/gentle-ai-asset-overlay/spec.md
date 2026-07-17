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

### Requirement: extraFiles — Flat File Overlays

Alongside `extraAssets`, the derivation also accepts `extraFiles` (type path, default `null`). While `extraAssets` supports recursive directory overlays, `extraFiles` SHALL only copy flat files — no directory merging. The `review-gate.md` file from `shared/assets/` SHALL be copied via this parameter.

#### Scenario: Flat file copied, directory skipped

- GIVEN `extraFiles` points to `shared/assets/` containing `review-gate.md` (file) and `skills/` (dir)
- WHEN the derivation builds
- THEN `$out/share/gentle-ai/review-gate.md` matches the source file
- AND no content from `skills/` appears in `$out/share/gentle-ai/skills/`

#### Scenario: extraFiles is null

- GIVEN `extraFiles` is `null` (default)
- WHEN the derivation builds
- THEN build succeeds with no flat-file overlay applied

### Requirement: sharedOpencodePaths Wiring

`lib/packages.nix` MUST expose both `extraAssets` and `extraFiles` via the `sharedOpencodePaths` attribute set and pass them to both `linuxPackages.gentle-ai-assets` and `darwinPackages.gentle-ai-assets`. The `extraAssets` path SHALL point to `shared/opencode/assets` (recursive overrides). The `extraFiles` path SHALL point to `shared/assets` (flat-file only overlays).

#### Scenario: Both platforms receive both parameters

- GIVEN `sharedOpencodePaths` includes `extraAssets = ./../shared/opencode/assets` and `extraFiles = ./../shared/assets`
- WHEN `lib/packages.nix` is evaluated
- THEN both `linuxPackages.gentle-ai-assets` and `darwinPackages.gentle-ai-assets` SHALL receive both `extraAssets` and `extraFiles`

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

### Requirement: sdd-review-policy.md Asset Registration

The file `shared/opencode/assets/opencode/sdd-review-policy.md` SHALL exist as a local asset in the `extraAssets` tree. The existing `cp -r ${extraAssets}/. $TEMP_DIR/` mechanism in `pkgs/gentle-ai-assets/default.nix` SHALL copy it into the nix store at `$out/share/gentle-ai/opencode/sdd-review-policy.md` with no derivation changes needed.

#### Scenario: File placed under extraAssets

- GIVEN `shared/opencode/assets/opencode/sdd-review-policy.md` exists with review policy content
- WHEN `gentle-ai-assets` derivation builds
- THEN `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/sdd-review-policy.md` SHALL match the source

#### Scenario: Flake check passes with new file

- GIVEN the new asset file exists in the source tree
- WHEN `nix flake check --no-build` runs
- THEN no errors are produced from the new file

### Requirement: ExtraAssets Inventory Completeness

The `shared/opencode/assets/` tree SHALL now contain both `opencode/sdd-orchestrator.md` (existing) and `opencode/sdd-review-policy.md` (new). This completes the inventory of local extraAssets — both files in the `opencode/` subdirectory are now tracked.

#### Scenario: Complete inventory

- GIVEN the full `shared/opencode/assets/` tree
- WHEN listing `opencode/` files
- THEN both `sdd-orchestrator.md` and `sdd-review-policy.md` are present
