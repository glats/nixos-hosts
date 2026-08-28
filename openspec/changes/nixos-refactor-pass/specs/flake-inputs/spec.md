# flake-inputs Specification

## Purpose

Post-refactor invariant for flake inputs: the unused `ghostty` input is removed and the lockfile is regenerated. No runtime behavior depends on it.

## Requirements

### Requirement: ghostty Input Removed

The `flake.nix` inputs set SHALL NOT declare a `ghostty` flake input, and `flake.lock` SHALL NOT contain a `ghostty` entry. No module in the repo references `inputs.ghostty`.

#### Scenario: ghostty absent from flake.nix

- GIVEN the repo after the change
- WHEN `rg -n 'ghostty = \{' flake.nix` is run
- THEN it SHALL return zero matches

#### Scenario: ghostty absent from flake.lock

- GIVEN the regenerated `flake.lock`
- WHEN `rg -n '"ghostty"' flake.lock` is run
- THEN it SHALL return zero matches

### Requirement: Evaluation Unaffected

After removal, `nix flake check --no-build` SHALL exit 0 for `rog`, `thinkcentre`, and `t14`, proving no consumer referenced the deleted input.

#### Scenario: flake check passes per host

- GIVEN `ghostty` input removed
- WHEN `nix flake check --no-build` runs
- THEN it SHALL exit 0 with no `inputs.ghostty` evaluation error

#### Scenario: no inputs.ghostty references

- GIVEN the repo after the change
- WHEN `rg -n 'inputs\.ghostty' --glob '!flake.lock'` is run
- THEN it SHALL return zero matches
