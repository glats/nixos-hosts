# dead-code Specification

## Purpose

Repo-wide hygiene: delete proven-dead code and clean the stale references that point at it. Every deletion is behavior-neutral and grep-verifiable.

## Requirements

### Requirement: darwin/default.nix Orphan Deleted

The file `darwin/default.nix` SHALL NOT exist. It is a true orphan (zero import references) that duplicates `hosts/mact2/default.nix` with a drifted provider value.

#### Scenario: file removed

- GIVEN the repo after the change
- WHEN `test -e darwin/default.nix` runs
- THEN it SHALL fail (file absent)

#### Scenario: mact2 still evaluates via live path

- GIVEN `darwin/default.nix` deleted
- WHEN `nix build .#darwinConfigurations.mact2.config.system.build.toplevel --no-build` or equivalent darwin eval runs
- THEN it SHALL succeed (built from `hosts/mact2/default.nix` via `mkDarwinHost`)

### Requirement: darwin/system/nix.nix Stale Comment Cleaned

The comment at `darwin/system/nix.nix:2` SHALL NOT reference `darwin/default.nix` (which no longer exists).

#### Scenario: no orphan reference in nix.nix

- GIVEN the repo after the change
- WHEN `rg -n 'darwin/default.nix' darwin/system/nix.nix` runs
- THEN it SHALL return zero matches

### Requirement: mkHost Alias Removed

`lib/mkHost.nix` SHALL NOT export `mkHost` (it only aliases `mkNixosHost`), and `flake.nix:141` SHALL NOT destructure `mkHost` from the `mkHost.nix` import.

#### Scenario: alias gone from lib

- GIVEN the repo after the change
- WHEN `rg -n 'mkHost' lib/mkHost.nix` runs
- THEN it SHALL match only `mkNixosHost` (no `mkHost =` binding)

#### Scenario: alias gone from flake.nix

- GIVEN the repo after the change
- WHEN `rg -n 'mkHost' flake.nix` runs
- THEN it SHALL return zero matches

### Requirement: conkyConfig specialArg Removed

`linux/system/base/home-manager.nix:16` SHALL NOT set `conkyConfig` in `extraSpecialArgs`. It is unconsumed; `conky-rog.nix`/`conky-thinkcentre.nix` define a local `let` binding of the same name that shadows it.

#### Scenario: specialArg absent

- GIVEN the repo after the change
- WHEN `rg -n 'conkyConfig' linux/system/base/home-manager.nix` runs
- THEN it SHALL return zero matches

#### Scenario: standalone HM still builds

- GIVEN `conkyConfig` specialArg removed
- WHEN `nix build .#homeConfigurations.rog.activationPackage --no-build` runs
- THEN it SHALL succeed (conky modules use local bindings)

### Requirement: romarr/grabarr Commented TODO Imports Removed

`hosts/rog/default.nix` SHALL NOT contain the commented-out `romarr.nix`/`grabarr.nix` import lines (currently at lines 63 and 65). The referenced files do not exist.

#### Scenario: commented imports gone

- GIVEN the repo after the change
- WHEN `rg -n 'romarr\.nix|grabarr\.nix' hosts/rog/default.nix` runs
- THEN it SHALL return zero matches

#### Scenario: note

- The sibling change `remove-romarr-grabarr` also targets these lines; this delta removes the two commented lines so the file is clean regardless of merge order.
