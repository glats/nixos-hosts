# local-ai-assets-package Specification

## Purpose

Derivation packaging locally maintained skills from `shared/assets/skills/` into a Nix store output consumed by the skill-deployment system — separate from upstream gentle-ai vendor assets.

## Requirements

### Requirement: Derivation Output Layout

The `local-ai-assets` derivation MUST copy the contents of `./../shared/assets/skills/` into `$out/share/local-ai/skills/`. It SHALL use `stdenvNoCC`, with `dontUnpack = true` and an `installPhase` copying skills to the output. The derivation copies whatever skill directories exist in the source tree — no hardcoded count.

#### Scenario: Build produces local skill directories

- GIVEN `shared/assets/skills/` contains skill subdirectories (e.g., `nix-verify/`, `git-feature-flow/`, `opencode-session-recovery/`)
- WHEN `nix build .#packages.x86_64-linux.local-ai-assets` runs
- THEN `$out/share/local-ai/skills/` contains exactly those skill directories with their `SKILL.md` files

#### Scenario: Cross-platform build parity

- GIVEN the derivation uses `stdenvNoCC` with no platform-specific logic
- WHEN built on `x86_64-darwin`
- THEN output layout matches `x86_64-linux` exactly

### Requirement: Package Registration

`lib/packages.nix` MUST register `local-ai-assets` via `callPackage` in both `linuxPackages` and `darwinPackages`. The package SHALL also be registered in platform overlays (`overlays/linux.nix` and `overlays/darwin.nix`) so that Home Manager consumer modules can resolve it via `pkgs.local-ai-assets`.

#### Scenario: Both platform registries resolve

- GIVEN `lib/packages.nix` is evaluated
- WHEN referencing `linuxPackages.local-ai-assets` or `darwinPackages.local-ai-assets`
- THEN both resolve to a valid `stdenvNoCC.mkDerivation` result

#### Scenario: Overlay registration for HM scope

- GIVEN `overlays/linux.nix` and `overlays/darwin.nix` register `local-ai-assets`
- WHEN a Home Manager module references `pkgs.local-ai-assets`
- THEN the package resolves without error
