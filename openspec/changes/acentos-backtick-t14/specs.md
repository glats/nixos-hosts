# fcitx5-ime-t14 Specification

## Purpose

fcitx5 input method for t14 — split across two repos. The **omarchy-nix** upstream provides a reusable `omarchy.fcitx5` home-manager module (packages, env vars, config, systemd autostart). The **nixos-hosts** repo enables it on t14 and removes the dead `compose:caps` XKB option from Hyprland and ReGreet.

## Scope

| Repo | Change | Files |
|------|--------|-------|
| omarchy-nix | New `omarchy.fcitx5` option + module | `config.nix`, `modules/home-manager/fcitx5.nix`, `modules/home-manager/default.nix`, `flake.nix` |
| nixos-hosts | Enable module + remove compose:caps | `hosts/t14/home/omarchy.nix`, `hosts/t14/home/hypr/input.nix`, `hosts/t14/default.nix` |

## Requirements (Summary)

| ID | Area | Requirement |
|----|------|-------------|
| R1 | omarchy-nix | Module installs `fcitx5`, `fcitx5-qt`, `fcitx5-gtk`, `fcitx5-configtool` via `home.packages` |
| R2 | omarchy-nix | Module sets `GTK_IM_MODULE`, `QT_IM_MODULE`, `XMODIFIERS` via `home.sessionVariables` |
| R3 | omarchy-nix | Module deploys `~/.config/fcitx5/profile` and `config` via `xdg.configFile` (content from commit `84f88a8`) |
| R4 | omarchy-nix | Module provides systemd user service (`PartOf=graphical-session.target`, NOT `exec-once`) |
| R5 | nixos-hosts | `hosts/t14/home/hypr/input.nix`: `kb_options = lib.mkForce "grp:alt_shift_toggle"` (no compose:caps) |
| R6 | nixos-hosts | `hosts/t14/default.nix`: greeter keyboard options have no `compose:caps` |
| R7 | both | `es,latam` layouts with `grp:alt_shift_toggle` preserved on t14 |
| R8 | both | No regression on rog, thinkcentre, mact2 (module defaults to `enable = false`) |
| R9 | omarchy-nix | Option declared in `config.nix` with `lib.mkOption` (not `mkEnableOption`), submodule pattern, `default = { }` |
| R10 | omarchy-nix | Module is self-contained — no `inputs` dependency, direct path import in `default.nix`, standalone `homeManagerModules.fcitx5` in `flake.nix` |

## Scenarios (Summary)

| ID | Scenario | Key assertion |
|----|----------|---------------|
| S1 | Packages available when enabled | `which fcitx5` resolves |
| S2 | GTK/Qt/XIM apps detect fcitx | env vars are `fcitx`/`@im=fcitx` |
| S3 | Profile and config files exist | `~/.config/fcitx5/{profile,config}` deployed |
| S4 | Daemon running after login | systemd service active, tray visible |
| S5 | Hyprland kb_options clean | no `compose:caps` on t14 |
| S6 | Greeter keyboard options clean | no `compose:caps` on t14 |
| S7 | Standalone module works | `homeManagerModules.fcitx5` works without full omarchy |
| S8 | Disabled by default | no fcitx5 artifacts when `enable` is not set |
| S9 | Layout toggle works | Alt+Shift toggles es/latam |
| S10 | Other hosts build cleanly | rog/thinkcentre/mact2 unaffected |
| S11 | Module follows conventions | matches voxtype.nix/wayvnc.nix pattern |
| S12 | Service stops with session | PartOf=graphical-session.target |

Full delta spec with GIVEN/WHEN/THEN: see `specs/fcitx5-ime-t14/spec.md`.
