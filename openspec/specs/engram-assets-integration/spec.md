# Engram Assets Integration Specification

## Purpose

Define how the OpenCode home module integrates the engram plugin from the nix store path instead of a local file, and the removal of the local `engram.ts` copy.

## Requirements

### Requirement: Nix Store Path for Engram Plugin

The `opencode.nix` home activation script MUST copy the engram plugin from `${pkgs.engram-assets}/share/engram/opencode/plugins/engram.ts` instead of the local file path `${./opencode/plugins/engram.ts}`.

#### Scenario: Activation copies engram from nix store

- GIVEN `cfg.plugins.engram.enable = true`
- WHEN the activation script runs during home-manager switch
- THEN it copies `engram.ts` from `${pkgs.engram-assets}/share/engram/opencode/plugins/engram.ts`
- AND the file is placed in `$runtime_dir/plugins/engram.ts`

#### Scenario: Activation does not reference local path

- GIVEN the activation script is inspected
- WHEN searching for engram plugin source references
- THEN no `${./opencode/plugins/engram.ts}` path is present
- AND only the nix store path is used

### Requirement: Local Engram Plugin File Deleted

The file `modules/home/opencode/plugins/engram.ts` MUST be removed from the repository. The plugin source of truth is the upstream `engram-src` flake input.

#### Scenario: Local file is removed

- GIVEN the change is applied
- WHEN inspecting `modules/home/opencode/plugins/`
- THEN `engram.ts` does NOT exist
- AND no other local plugin files remain (only upstream plugins via gentle-ai-assets)

### Requirement: Overlay Integration

The `engram-assets` package MUST be added to the overlay in `modules/base/overlays.nix` so it is accessible as `pkgs.engram-assets`.

#### Scenario: engram-assets available via overlay

- GIVEN the overlay is applied
- WHEN evaluating `pkgs.engram-assets`
- THEN it resolves to the layered engram derivation
- AND `pkgs.engram-assets-vanilla` resolves to the vanilla derivation

### Requirement: Plugin Toggle Still Controls Copy

The `cfg.plugins.engram.enable` toggle MUST continue to control whether the engram plugin is copied to the runtime directory.

#### Scenario: Disabled engram plugin is not copied

- GIVEN `cfg.plugins.engram.enable = false`
- WHEN the activation script runs
- THEN `engram.ts` is NOT copied to `$runtime_dir/plugins/`
- AND no error occurs
