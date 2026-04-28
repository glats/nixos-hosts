# Gentle AI Assets Build Specification

## Purpose

Define the build process for `gentle-ai-assets` as a layered derivation (vanilla + local), replacing the previous inline merge approach.

## Requirements

### Requirement: Layered Build Output

The `gentle-ai-assets` package MUST produce a complete asset directory containing both upstream assets and local overrides, accessible at `$out/share/gentle-ai/`.

#### Scenario: Build produces complete asset tree

- GIVEN `nix build .#gentle-ai-assets` is executed
- WHEN the build completes
- THEN `$out/share/gentle-ai/` contains: AGENTS.md, opencode/ (including plugins/), skills/, and agent config directories
- AND skills/ includes both upstream and local skills
- AND opencode/plugins/ includes merged upstream and local plugins

#### Scenario: Build includes local persona rules

- GIVEN local persona rules are defined in `default.nix`
- WHEN the build completes
- THEN `opencode/persona-gentleman.md` in the output contains local rules prepended to upstream content

### Requirement: Flake Check Passes

The flake MUST pass `nix flake check` after the refactor, with no warnings or errors related to `gentle-ai-assets`.

#### Scenario: Flake check succeeds

- GIVEN the refactor is complete
- WHEN running `nix flake check`
- THEN the command exits with code 0
- AND no warnings are emitted about `gentle-ai-assets` or `gentle-ai-src`

### Requirement: Vanilla Derivation Exposed

The flake MUST expose the vanilla derivation as a separate buildable attribute alongside the layered `gentle-ai-assets`.

#### Scenario: Both derivations are buildable

- GIVEN the flake is evaluated
- WHEN running `nix build .#gentle-ai-assets`
- THEN the layered build succeeds
- AND when running `nix build .#gentle-ai-assets-vanilla` (or equivalent)
- THEN the vanilla build also succeeds

### Requirement: Backward Compatible Interface

The `gentle-ai-assets` package MUST accept the same arguments as before (`gentle-ai-src`, `extraSkills`, `writeText`) to avoid breaking consumers.

#### Scenario: Existing call pattern still works

- GIVEN the current `flake.nix` calls `pkgs.callPackage ./pkgs/gentle-ai-assets { inherit gentle-ai-src; writeText = pkgs.writeText; extraSkills = ./modules/home/opencode/skills; }`
- WHEN the refactor is applied
- THEN this call pattern still produces a valid derivation
- AND the output contains both upstream and local content
