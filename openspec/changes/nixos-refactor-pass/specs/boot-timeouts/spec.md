# boot-timeouts Specification

## Purpose

rog host systemd timeout overrides SHALL have a single source of truth in `hosts/rog/systemd-timeouts.nix`. The inline duplicate block in `hosts/rog/default.nix` (which diverged by adding `docker-romm-db`) is removed.

## Requirements

### Requirement: Single Source of Truth Module

`hosts/rog/systemd-timeouts.nix` SHALL define `TimeoutStartSec` (mkForce "300") and `startLimitIntervalSec` (mkForce 0) for ALL rog systemd services, including `docker-romm-db`, which previously existed only inline.

#### Scenario: romm-db present in module

- GIVEN the repo after the change
- WHEN `rg -n 'docker-romm-db' hosts/rog/systemd-timeouts.nix` runs
- THEN it SHALL match exactly one line defining `TimeoutStartSec = lib.mkForce "300"`

### Requirement: Inline Duplicate Block Removed

`hosts/rog/default.nix` SHALL NOT inline the timeout override block. All `systemd.services.*.serviceConfig.TimeoutStartSec/startLimitIntervalSec` definitions for these services move into the module.

#### Scenario: no inline timeout overrides

- GIVEN the repo after the change
- WHEN `rg -n 'systemd\.services\.(nginx|"acme-glats\.org"|"docker-droppy"|"docker-guacamoledb"|"docker-jellyfin"|"docker-jellyseerr"|"docker-romm-db")\.serviceConfig\.(TimeoutStartSec|startLimitIntervalSec)' hosts/rog/default.nix` runs
- THEN it SHALL return zero matches

### Requirement: Module Import Intact

`hosts/rog/default.nix` SHALL continue to import `./systemd-timeouts.nix` so the single source remains wired.

#### Scenario: import present

- GIVEN the repo after the change
- WHEN `rg -n '\./systemd-timeouts\.nix' hosts/rog/default.nix` runs
- THEN it SHALL match (the import line, currently :92)

### Requirement: docker-romm-db Evaluated Exactly Once

`docker-romm-db` `TimeoutStartSec` SHALL be defined exactly once across the rog configuration — in the module, never inline.

#### Scenario: single definition

- GIVEN the repo after the change
- WHEN `rg -c 'docker-romm-db' hosts/rog/systemd-timeouts.nix` and `rg -c 'docker-romm-db' hosts/rog/default.nix` run
- THEN the module SHALL have exactly 1 match and `default.nix` SHALL have 0 matches

#### Scenario: rog builds

- GIVEN the consolidation applied
- WHEN `nix build .#nixosConfigurations.rog.config.system.build.toplevel --no-build` runs
- THEN it SHALL succeed with the romm-db timeout still effective
