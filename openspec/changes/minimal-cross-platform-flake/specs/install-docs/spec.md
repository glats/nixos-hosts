# install-docs Specification

## Purpose

Define requirements for English post-install and manual UEFI GPT partitioning documentation.

## Requirements

### Requirement: English-Only Documentation

All documentation files SHALL be written exclusively in English. No Spanish or other language sections, translations, or inline comments SHALL be present.

#### Scenario: Documents are monolingual English

- GIVEN any `.md` documentation file in the repo
- WHEN the file content is inspected
- THEN no Spanish or non-English paragraph, heading, or code comment block is found

### Requirement: Post-Install Guide

A `POST_INSTALL.md` file MUST cover: installing and bootstrapping nix-darwin + Determinate Nix on a fresh macOS; running `darwin-rebuild switch` to activate `minimal-mac`; and completing Codex CLI interactive authentication on both hosts.

#### Scenario: macOS bootstrap is documented

- GIVEN `POST_INSTALL.md`
- WHEN read
- THEN it includes steps to install Determinate Nix on aarch64-darwin
- AND it covers running `darwin-rebuild switch --flake /home/glats/minimal-nix#minimal-mac`
- AND default hostname `minimal-mac` is noted with instructions to replace if desired

#### Scenario: Codex authentication is documented

- GIVEN `POST_INSTALL.md`
- WHEN the Codex section is read
- THEN it documents `codex login --device-auth` for headless/console hosts
- AND it documents `codex login` (browser OAuth) for macOS
- AND it documents `codex login --with-api-key` via stdin
- AND no automated `codex login` call is prescribed
- AND no API key value is embedded

### Requirement: Manual Partitioning Guide

A `PARTITIONING.md` file MUST document manual UEFI GPT partitioning: creating an EFI system partition and a root partition with `gdisk`, formatting with `mkfs.fat` and `mkfs.ext4`, and mounting under `/mnt` before `nixos-generate-config`.

#### Scenario: Disk layout is documented

- GIVEN `PARTITIONING.md`
- WHEN read
- THEN it describes a GPT partition table with at minimum: an EFI System Partition (type `EF00`) and a Linux root partition (type `8300`)
- THEN recommended partition sizes are stated
- THEN commands for `gdisk`, `mkfs.fat` (ESP), and `mkfs.ext4` (root) are provided
- AND mounting paths are `/mnt` and `/mnt/boot` respectively

#### Scenario: No declarative partitioning tool is documented

- GIVEN `PARTITIONING.md`
- WHEN inspected
- THEN no mention of `disko` or declarative disk configuration is present
- AND the guide covers purely manual `gdisk`+mount workflow

### Requirement: Hostname Defaults Documented

Both install documents SHALL note the default hostnames (`minimal-linux`, `minimal-mac`) as sed-replaceable and explain where to change them (`flake.nix` outputs key).

#### Scenario: Hostname defaults are changeable

- GIVEN any install documentation
- WHEN hostname defaults are mentioned
- THEN a note explains they are replaceable in `flake.nix`
- AND the relevant key path (`nixosConfigurations.*` or `darwinConfigurations.*`) is cited
