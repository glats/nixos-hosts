# local-ai-assets-package Specification

## Purpose

Derivation packaging locally maintained skills from `shared/assets/skills/` into a Nix store output consumed by the skill-deployment system — separate from upstream gentle-ai vendor assets.

## Requirements

### Requirement: Derivation Output Layout

The `local-ai-assets` derivation MUST copy the contents of `./../shared/assets/skills/` into `$out/share/local-ai/skills/`. It SHALL use `stdenvNoCC`, `dontUnpack = true`, and an `installPhase` copying skills to the output.

#### Scenario: Build produces 3 local skill directories

- GIVEN `shared/assets/skills/` contains `nix-verify/`, `git-feature-flow/`, `opencode-session-recovery/`
- WHEN `nix build .#packages.x86_64-linux.local-ai-assets` runs
- THEN `$out/share/local-ai/skills/` contains exactly those 3 directories with their `SKILL.md` files

#### Scenario: Cross-platform build parity

- GIVEN the derivation uses `stdenvNoCC` with no platform-specific logic
- WHEN built on `x86_64-darwin`
- THEN output layout matches `x86_64-linux` exactly

### Requirement: Package Registration

`lib/packages.nix` MUST register `local-ai-assets` via `callPackage` in both `linuxPackages` and `darwinPackages`.

#### Scenario: Both platform registries resolve

- GIVEN `lib/packages.nix` is evaluated
- WHEN referencing `linuxPackages.local-ai-assets` or `darwinPackages.local-ai-assets`
- THEN both resolve to a valid `stdenvNoCC.mkDerivation` result
