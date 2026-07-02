# Delta for fcitx5-ime-t14

## ADDED Requirements

### Requirement: omarchy-nix fcitx5 Module — Packages

The omarchy-nix `modules/home-manager/fcitx5.nix` module MUST install `fcitx5`, `fcitx5-qt`, `fcitx5-gtk`, and `fcitx5-configtool` via `home.packages` when `omarchy.fcitx5.enable` is true.

#### Scenario: Packages available when enabled

- GIVEN `omarchy.fcitx5.enable = true`
- WHEN the home configuration is activated
- THEN all four fcitx5 binaries resolve in PATH

### Requirement: omarchy-nix fcitx5 Module — Environment Variables

The module MUST set `GTK_IM_MODULE=fcitx`, `QT_IM_MODULE=fcitx`, `XMODIFIERS=@im=fcitx` via `home.sessionVariables` when enabled.

#### Scenario: IM apps detect fcitx

- GIVEN `omarchy.fcitx5.enable = true` and session is active
- WHEN any app reads IM env vars
- THEN values are `fcitx`, `fcitx`, `@im=fcitx` respectively

### Requirement: omarchy-nix fcitx5 Module — User Config

The module MUST deploy `~/.config/fcitx5/profile` and `~/.config/fcitx5/config` via `xdg.configFile` with content from deleted nixos-hosts commit `84f88a8`.

#### Scenario: Config files deployed

- GIVEN `omarchy.fcitx5.enable = true`
- WHEN home configuration is activated
- THEN both files exist under `~/.config/fcitx5/`

### Requirement: omarchy-nix fcitx5 Module — Systemd Autostart

The module MUST provide a systemd user service `PartOf=graphical-session.target` and `WantedBy=graphical-session.target`. MUST NOT use Hyprland `exec-once`.

#### Scenario: Daemon running after login

- GIVEN enabled and graphical session active
- WHEN session is fully loaded
- THEN fcitx5 daemon runs and tray icon is visible

#### Scenario: Service stops with session

- GIVEN fcitx5 service is running
- WHEN graphical session ends
- THEN service stops (PartOf dependency)

### Requirement: omarchy-nix Option Declaration

`omarchy.fcitx5` MUST be declared in `config.nix` using `lib.types.submodule` with `enable` field (`lib.types.bool`, default `false`). MUST use `lib.mkOption` directly, NOT `mkEnableOption`.

#### Scenario: Option default is false

- GIVEN a consumer imports omarchy-nix
- WHEN inspecting `omarchy.fcitx5.enable`
- THEN default is `false`

### Requirement: Module Wiring and Standalone Access

The module MUST be imported in `modules/home-manager/default.nix`. A standalone `homeManagerModules.fcitx5` MUST be exposed in `flake.nix` (btop pattern).

#### Scenario: Standalone import works

- GIVEN consumer imports `homeManagerModules.fcitx5` directly
- WHEN home configuration is activated
- THEN fcitx5 packages, env vars, config, and service are deployed

### Requirement: compose:caps Removed from t14

`hosts/t14/home/hypr/input.nix` MUST set `kb_options = lib.mkForce "grp:alt_shift_toggle"` (no compose:caps). `hosts/t14/default.nix` greeter keyboard options MUST NOT contain `compose:caps`.

#### Scenario: Hyprland and greeter clean

- GIVEN t14 configuration is applied
- WHEN inspecting kb_options and greeter options
- THEN neither contains `compose:caps`

### Requirement: Layouts Preserved and No Regression

t14 MUST maintain `es,latam` with `grp:alt_shift_toggle`. Other hosts (rog, thinkcentre, mact2) MUST NOT be affected — module defaults to `enable = false`.

#### Scenario: Layout toggle and isolation

- GIVEN fcitx5 running on t14
- WHEN Alt+Shift pressed
- THEN layout toggles es/latam
- AND `nix flake check --no-build` passes for all hosts

### Requirement: Disabled by Default

When `omarchy.fcitx5.enable` is not set, the module MUST NOT install packages, set env vars, deploy config, or create a service.

#### Scenario: No artifacts when disabled

- GIVEN `omarchy.fcitx5.enable` is not set
- WHEN home configuration is activated
- THEN zero fcitx5 artifacts exist

### Requirement: Convention Compliance

Module MUST follow omarchy patterns: options only in `config.nix`, `lib.mkOption` not `mkEnableOption`, submodule with `default = { }`, `let cfg = config.omarchy.fcitx5;` alias, `lib.mkIf cfg.enable` gate, header comment.

#### Scenario: Matches voxtype/wayvnc pattern

- GIVEN the module file is reviewed
- WHEN compared to voxtype.nix and wayvnc.nix
- THEN structure matches: header comment, cfg alias, mkIf gate, no option declarations
