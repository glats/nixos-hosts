# Delta Spec: NixOS Host Pattern Refactor

## Purpose

Eliminate the last `hostName` conditional from `home-linux/` by decomposing `btop.nix` into focused fragments imported per-host. This is a pure structural refactor — no behavioral change.

## ADDED Requirements

### Requirement: No host conditionals in shared home modules

The `home-linux/` directory MUST NOT contain any `hostName` conditionals. All host-specific branching MUST occur at the import site in each host's module list.

#### Scenario: Grep returns zero hostName matches

- GIVEN the refactor is complete
- WHEN `grep -r 'hostName' home-linux/` is executed
- THEN zero matches are returned

#### Scenario: New shared module has no conditionals

- GIVEN a developer adds a new module to `home-linux/`
- WHEN the module is reviewed
- THEN it MUST NOT contain `hostName` branching logic

### Requirement: Shared btop theme fragment

`home-linux/btop-theme.nix` MUST write `~/.config/btop/themes/nix-colors.theme` using `config.colorScheme.palette` base16 colors. It MUST NOT reference `hostName`. It MUST be included in `home-linux/shared-modules.nix`.

#### Scenario: All linux hosts receive the theme file

- GIVEN any linux host (rog, thinkcentre, t14) evaluates its home configuration
- WHEN the home-manager build completes
- THEN `~/.config/btop/themes/nix-colors.theme` exists with the correct base16 color mappings

### Requirement: File-based btop config for rog and thinkcentre

`home-linux/btop-file.nix` MUST write `~/.config/btop/btop.conf` via `home.file` with the full btop configuration (color_theme, presets, shown_boxes, gpu settings, etc.). It MUST NOT reference `hostName`. It MUST be imported by `hosts/rog/home/modules.nix` and `hosts/thinkcentre/home/modules.nix`.

#### Scenario: rog produces identical btop.conf as before refactor

- GIVEN the rog host evaluates its home configuration after the refactor
- WHEN `~/.config/btop/btop.conf` is generated
- THEN the file content matches the pre-refactor output exactly

#### Scenario: thinkcentre produces identical btop.conf as before refactor

- GIVEN the thinkcentre host evaluates its home configuration after the refactor
- WHEN `~/.config/btop/btop.conf` is generated
- THEN the file content matches the pre-refactor output exactly

### Requirement: HM settings-based btop config for t14

`home-linux/btop-settings.nix` MUST set `programs.btop.settings` with `lib.mkForce` on each key, matching the current `mkIf (hostName == "t14")` block. It MUST NOT reference `hostName`. It MUST be imported by `hosts/t14/home/omarchy.nix`.

#### Scenario: t14 btop settings override omarchy defaults

- GIVEN the t14 host evaluates its home configuration after the refactor
- WHEN `programs.btop.settings` is resolved
- THEN every key uses `lib.mkForce` and the values match the pre-refactor output exactly

#### Scenario: t14 theme file is still deployed

- GIVEN the t14 host includes `btop-settings.nix`
- WHEN the home-manager build completes
- THEN `~/.config/btop/themes/nix-colors.theme` is present (provided by `btop-theme.nix` via shared-modules or explicit import)

### Requirement: Import list correctness

`home-linux/shared-modules.nix` MUST replace `./btop.nix` with `./btop-theme.nix`. The original `./btop.nix` MUST be deleted. Each host's module list MUST import exactly the btop fragment that matches its pre-refactor behavior.

#### Scenario: shared-modules.nix no longer references btop.nix

- GIVEN the refactor is complete
- WHEN `home-linux/shared-modules.nix` is read
- THEN it contains `./btop-theme.nix` and does NOT contain `./btop.nix`

#### Scenario: Flake evaluation passes

- GIVEN the refactor is complete
- WHEN `nix flake check --no-build` is executed
- THEN it passes with exit code 0

## REMOVED Requirements

### Requirement: Monolithic btop.nix with host branching

`home-linux/btop.nix` is removed. Its theme logic moves to `btop-theme.nix`; its rog/thinkcentre config moves to `btop-file.nix`; its t14 settings moves to `btop-settings.nix`.

(Reason: Single source of host-conditional logic violates the per-host import pattern used by all other modules.)
(Migration: Three replacement files, each imported at the appropriate host's module list.)
