# home-manager-composition Specification

## Purpose

Standalone `homeConfigurations` (rog, thinkcentre, t14, mact2) SHALL have exactly ONE owner of the platform shared module list. Today `mkHomeConfig` prepends the shared list AND each per-host home file re-imports it, evaluating it twice (module dedup keeps this behavior-neutral). We make the per-host home files the sole owner.

## Requirements

### Requirement: mkHomeConfig Does Not Prepend Shared List

In `flake.nix`, `mkHomeConfig`'s `modules` expression SHALL NOT reference `linuxHomeModules` or `darwinHomeModules`. It SHALL pass through `extraModules` only.

#### Scenario: no prepend bindings referenced

- GIVEN the repo after the change
- WHEN `rg -n 'linuxHomeModules|darwinHomeModules' flake.nix` runs
- THEN it SHALL return zero matches

### Requirement: Shared-List Bindings Removed

The `linuxHomeModules` and `darwinHomeModules` `let` bindings and the retained-for-mkHomeConfig NOTE comment chain in `flake.nix` (lines ~174-187) SHALL be deleted.

#### Scenario: bindings absent

- GIVEN the repo after the change
- WHEN `rg -n 'linuxHomeModules = import|darwinHomeModules = import' flake.nix` runs
- THEN it SHALL return zero matches

#### Scenario: flake still checks

- GIVEN bindings removed
- WHEN `nix flake check --no-build` runs
- THEN it SHALL exit 0

### Requirement: Per-Host Home File Owns Shared List

Each standalone `homeConfiguration` SHALL evaluate the platform shared module list exactly once, via its per-host home file: `hosts/<host>/home/default.nix` (linux) imports `linux/home/shared-modules.nix`; `./darwin/home` (mact2) imports `darwin/home/shared-modules.nix`.

#### Scenario: linux per-host files import shared list

- GIVEN the repo after the change
- WHEN `rg -n 'shared-modules.nix' hosts/rog/home/default.nix hosts/thinkcentre/home/default.nix hosts/t14/home/default.nix` runs
- THEN it SHALL match in all three files

#### Scenario: darwin home imports shared list

- GIVEN the repo after the change
- WHEN `rg -n 'shared-modules.nix' darwin/home/default.nix` runs
- THEN it SHALL match

### Requirement: All Four Standalone Entries Build

All four `homeConfigurations` activation packages SHALL build successfully before and after the change (behavior-neutral: identical module set once dedup is removed).

#### Scenario: build all four

- GIVEN the change applied
- WHEN `nix build .#homeConfigurations.rog.activationPackage .#homeConfigurations.thinkcentre.activationPackage .#homeConfigurations.t14.activationPackage .#homeConfigurations.mact2.activationPackage --no-build` runs
- THEN all four SHALL succeed
