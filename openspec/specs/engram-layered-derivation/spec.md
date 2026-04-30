# Engram Layered Derivation Specification

## Purpose

Define a layered derivation that composes on top of the engram vanilla derivation, allowing ENGRAM_BIN path customization via overlay while preserving the pure upstream plugin as the base.

## Requirements

### Requirement: Vanilla Base Import

The layered derivation (`pkgs/engram-assets/default.nix`) MUST import the vanilla derivation as its base, not duplicate the upstream copy logic inline.

#### Scenario: Default imports vanilla derivation

- GIVEN `pkgs/engram-assets/default.nix` is evaluated
- WHEN inspecting its source
- THEN it references the vanilla derivation as its upstream base
- AND it does NOT contain inline `cp $src/...` commands for the upstream plugin

### Requirement: ENGRAM_BIN Customization via Overlay

The layered derivation MUST support overriding the ENGRAM_BIN path. The default value MUST be the nix store path to the engram binary (`${pkgs.engram}/bin/engram`).

#### Scenario: Default ENGRAM_BIN is nix store path

- GIVEN `engram-assets` is built with default parameters
- WHEN inspecting the output plugin file
- THEN any ENGRAM_BIN references resolve to `${pkgs.engram}/bin/engram`

#### Scenario: ENGRAM_BIN can be overridden

- GIVEN a custom ENGRAM_BIN path is provided via overlay parameter
- WHEN the layered derivation is built
- THEN the output plugin file uses the custom ENGRAM_BIN path
- AND the vanilla base plugin content is preserved except for the ENGRAM_BIN substitution

### Requirement: Clean Composition Method

The layering MUST use a clean Nix composition method (`runCommand`, `substituteInPlace`, or similar) that does not modify the vanilla derivation's output.

#### Scenario: Vanilla output is not mutated

- GIVEN the vanilla derivation produces output at path V
- AND the layered derivation produces output at path L
- WHEN comparing V and L
- THEN V remains unchanged (read-only, not modified by layering)
- AND L contains the composed result with ENGRAM_BIN customization

### Requirement: Flake Package Exposure

The flake MUST expose both `engram-assets-vanilla` and `engram-assets` as buildable packages in `packages.${system}`.

#### Scenario: Both derivations are buildable

- GIVEN the flake is evaluated
- WHEN running `nix build .#engram-assets-vanilla`
- THEN the vanilla build succeeds
- AND when running `nix build .#engram-assets`
- THEN the layered build also succeeds
