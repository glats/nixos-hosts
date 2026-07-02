# Delta Spec: Wallpaper Rotation Toggle

## ADDED Requirements

### Requirement: Rotation Toggle Option Declaration

The omarchy-nix module SHALL declare `omarchy.rotate_on_start` as a `types.bool` option with default `true`, declared as a sibling to `omarchy.theme` in `config.nix`.

#### Scenario: Option defaults to true when unset

- GIVEN a NixOS configuration importing omarchy-nix
- AND `omarchy.rotate_on_start` is not explicitly set
- THEN `config.omarchy.rotate_on_start` evaluates to `true`

#### Scenario: Option accepts explicit false

- GIVEN a NixOS configuration importing omarchy-nix
- AND `omarchy.rotate_on_start = false` is set in the user config
- THEN `config.omarchy.rotate_on_start` evaluates to `false`

#### Scenario: Option rejects non-boolean values

- GIVEN a NixOS configuration importing omarchy-nix
- AND `omarchy.rotate_on_start` is set to a non-boolean value (e.g. `"yes"`, `1`)
- THEN Nix evaluation fails with a type error

### Requirement: Conditional Wallpaper Rotation on Session Start

The omarchy-nix module SHALL include `omarchy-theme-bg-next` in Hyprland's `exec-once` list only when `omarchy.rotate_on_start` is `true`.

#### Scenario: Default — wallpaper advances on session start

- GIVEN `omarchy.rotate_on_start` is `true` (or unset, using default)
- WHEN a Hyprland session starts
- THEN `omarchy-theme-bg-next` is present in `exec-once` and advances the wallpaper to the next image

#### Scenario: Disabled — wallpaper persists across session start

- GIVEN `omarchy.rotate_on_start = false`
- WHEN a Hyprland session starts
- THEN `omarchy-theme-bg-next` is NOT present in `exec-once`
- AND the wallpaper displayed is whatever `current/background` symlink points to (unchanged from previous session)

### Requirement: Backward Compatibility

Existing omarchy-nix configurations that do not set `omarchy.rotate_on_start` SHALL observe zero behavior change.

#### Scenario: Existing user without option set

- GIVEN an existing omarchy-nix user who has `omarchy.theme = "tokyo-night"` configured
- AND `omarchy.rotate_on_start` is not set in their configuration
- WHEN they rebuild and restart their Hyprland session
- THEN wallpaper rotates on session start, identical to behavior before this change

### Requirement: Manual Wallpaper Selection Independence

The manual wallpaper selection mechanisms (`Super+Ctrl+Space` walker and `omarchy-theme-bg-set`) SHALL function regardless of the `rotate_on_start` toggle value.

#### Scenario: Manual selection with rotation enabled

- GIVEN `omarchy.rotate_on_start = true`
- WHEN the user invokes `omarchy-theme-bg-set` to choose a specific wallpaper
- THEN the selected wallpaper is applied immediately
- AND the next session start advances to the next wallpaper (rotation continues)

#### Scenario: Manual selection with rotation disabled

- GIVEN `omarchy.rotate_on_start = false`
- WHEN the user invokes `omarchy-theme-bg-set` to choose a specific wallpaper
- THEN the selected wallpaper is applied immediately
- AND the next session start displays the same wallpaper (no rotation)

### Requirement: Initial Wallpaper Load Unaffected

The `swaybg` process launched by `autostart.nix` SHALL start on every Hyprland session start and display whatever image `current/background` points to, regardless of `rotate_on_start`.

#### Scenario: swaybg launches with rotation disabled

- GIVEN `omarchy.rotate_on_start = false`
- AND `current/background` symlink points to a valid image
- WHEN a Hyprland session starts
- THEN `swaybg -i current/background` launches and displays that image

#### Scenario: No backgrounds available for theme

- GIVEN `omarchy.rotate_on_start` is any value
- AND no background images exist for the current theme
- WHEN a Hyprland session starts
- THEN `swaybg` launches with `--color '#000000'` (existing fallback behavior, unchanged)

### Requirement: Lock Screen Unaffected

`hyprlock` reads the `current/background` symlink to display the lock screen wallpaper. This behavior SHALL remain unchanged regardless of `rotate_on_start`.

#### Scenario: Lock screen with rotation disabled

- GIVEN `omarchy.rotate_on_start = false`
- AND the user has manually set a wallpaper via `omarchy-theme-bg-set`
- WHEN the screen locks
- THEN `hyprlock` displays the manually selected wallpaper from `current/background`
