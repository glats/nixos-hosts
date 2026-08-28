# docs-hygiene Specification

## Purpose

`AGENTS.md` and codebase comments SHALL match repo reality. The conky/openfang per-host rule, the Flake Inputs table, and the structure block are corrected; four Spanish comment clusters are translated to English preserving all technical facts.

## Requirements

### Requirement: conky/openfang Rule Correct

`AGENTS.md` SHALL state that `conky-rog`/`openfang` are appended in `hosts/rog/home/default.nix` (lines 12-13), NOT in `flake.nix` `homeConfigurations`.

#### Scenario: stale phrase removed

- GIVEN the repo after the change
- WHEN `rg -n 'appended per-host in flake.nix .homeConfigurations' AGENTS.md` runs
- THEN it SHALL return zero matches

#### Scenario: correct location documented

- GIVEN the repo after the change
- WHEN `rg -n 'hosts/rog/home/default.nix' AGENTS.md` runs
- THEN it SHALL match within the conky/openfang rule (rule 9)

### Requirement: Flake Inputs Table Complete

`AGENTS.md` Flake Inputs table SHALL list every input declared in `flake.nix` `inputs = { ... }` (after `ghostty` removal).

#### Scenario: every input present in table

- GIVEN the repo after the change
- WHEN for each name in `flake.nix` inputs block, `rg -n "\`$name\`" AGENTS.md` runs
- THEN every declared input name SHALL appear in the table (no omission)

### Requirement: Structure Block Accurate

`AGENTS.md` structure block SHALL NOT contain the stale subdirectory descriptions that understate file counts.

#### Scenario: stale descriptions removed

- GIVEN the repo after the change
- WHEN `rg -n 'hardware/.*# nvidia, amd-laptop, asus-fan-control$|network/.*# wireguard, ddclient, samba, ftp$|media/.*# arr-stack, jellyfin, qbittorrent$' AGENTS.md` runs
- THEN it SHALL return zero matches (each line updated to reflect actual file counts: hardware 8, network 7, media 5)

### Requirement: Spanish Comment Clusters Translated

Four comment clusters SHALL be English-only: `flake.nix` ~108-116 (homebrew-brew), `shared/opencode/providers-base.nix` 172-214 (free-tier audit), `shared/nix-resilience.nix` 15-25 (resilience), `linux/system/services/web/code-server.nix` 18-26 (bind mounts).

#### Scenario: Spanish lexical markers absent in scoped ranges

- GIVEN the repo after the change
- WHEN each scoped range is grepped for `Resiliencia|requerido|su ele funcionar|Reservar|Re-auditar|el retry|para los datos|Bind mounts para`
- THEN every `sed -n '<range>p' <file> | rg '<markers>'` SHALL return zero matches

#### Scenario: technical facts preserved

- GIVEN the translations applied
- WHEN `rg -n '#41236' shared/opencode/providers-base.nix` and `rg -n 'falla rápido|falla rapido' shared/nix-resilience.nix` run
- THEN issue reference `#41236` SHALL remain present and the resilience benchmark intent (fast-fail timeouts) SHALL be preserved in English
