# Vanilla Derivation Specification

## Purpose

Define a pure upstream asset derivation (`vanilla.nix`) that copies Gentle AI assets exactly as released, with zero local modifications. This serves as the reproducible baseline for layered overrides.

## Requirements

### Requirement: Pure Upstream Copy

The derivation MUST copy all upstream assets from `gentle-ai-src` without any local modifications, merges, or overrides. The output must be byte-identical to what upstream ships.

#### Scenario: Build produces unmodified upstream assets

- GIVEN `vanilla.nix` is built with `gentle-ai-src` pointing to a specific upstream commit
- WHEN the derivation completes
- THEN all files under `$out/share/gentle-ai/` match the upstream repository exactly
- AND no local persona rules, skills, or overrides are present

#### Scenario: Upstream AGENTS.md is preserved as-is

- GIVEN upstream contains `AGENTS.md` at the repository root
- WHEN the derivation installs assets
- THEN `$out/share/gentle-ai/AGENTS.md` is a byte-identical copy of the upstream file

#### Scenario: Upstream skills are copied without modification

- GIVEN upstream contains skills in `internal/assets/skills/` and/or `skills/`
- WHEN the derivation installs assets
- THEN all upstream skills are present under `$out/share/gentle-ai/skills/` unmodified

### Requirement: Complete Asset Coverage

The derivation MUST copy all asset categories that upstream provides: AGENTS.md, OpenCode assets (including ALL plugins/), skills (both `internal/assets/skills/` and root `skills/`), and agent-specific configs (claude, cursor, etc.). No upstream plugins may be excluded.

#### Scenario: All upstream asset directories are included

- GIVEN upstream has assets in `internal/assets/opencode/` (including `plugins/`), `internal/assets/skills/`, and `internal/assets/{agent}/`
- WHEN the derivation completes
- THEN each directory exists under `$out/share/gentle-ai/` with all upstream contents

#### Scenario: Missing upstream directories are handled gracefully

- GIVEN upstream does not have a particular asset directory (e.g., no `skills/` at root, no `opencode/plugins/`)
- WHEN the derivation runs
- THEN the build succeeds without errors
- AND the missing directory is simply absent from the output

### Requirement: Separate Derivation

The vanilla derivation MUST be a standalone Nix derivation, independent of `default.nix`, buildable on its own via `nix build .#gentle-ai-assets-vanilla` (or equivalent attribute).

#### Scenario: Vanilla derivation builds independently

- GIVEN the flake exposes the vanilla derivation as a package
- WHEN running `nix build .#gentle-ai-assets-vanilla`
- THEN the build succeeds and produces a valid output path

#### Scenario: Vanilla derivation does not depend on extraSkills

- GIVEN the vanilla derivation is defined
- WHEN inspecting its inputs
- THEN it accepts only `gentle-ai-src` and standard Nixpkgs arguments
- AND it does NOT accept `extraSkills` or any local override parameters
