# Omarchy-Fonts Specification

## Purpose

Define configurable per-component font options for omarchy-nix so consumers can customize fonts for each UI surface independently, replacing hardcoded `JetBrainsMono Nerd Font` with sensible generic defaults resolved by fontconfig.

## Requirements

### Requirement: Per-Component Font Options

omarchy-nix SHALL expose a `fonts` submodule under the `omarchy` namespace with one string option per UI component: `waybar`, `swayosd`, `mako`, `walker`, `rofi`, `hyprlock`, `alacritty`, `ghostty`. Each option SHALL accept a font family string (e.g., `"Source Sans 3"`, `"JetBrainsMono Nerd Font"`, `"monospace"`, `"sans-serif"`).

Default values SHALL match each component's nature:

| Option | Default | Rationale |
|--------|---------|-----------|
| `waybar` | `"sans-serif"` | GUI status bar |
| `swayosd` | `"sans-serif"` | GUI volume/brightness OSD |
| `mako` | `"sans-serif"` | GUI notification daemon |
| `rofi` | `"sans-serif"` | GUI application launcher |
| `walker` | `"monospace"` | TUI-style launcher (aesthetic choice) |
| `hyprlock` | `"monospace"` | Lock screen input field |
| `alacritty` | `"monospace"` | Terminal emulator |
| `ghostty` | `"monospace"` | Terminal emulator |

#### Scenario: Consumer uses defaults

- GIVEN an omarchy-nix consumer sets no font options
- WHEN the system builds
- THEN waybar, swayosd, mako, and rofi render with `sans-serif` (resolved by fontconfig to Source Sans 3 / Noto Sans)
- AND walker, hyprlock, alacritty, and ghostty render with `monospace` (resolved to CaskaydiaCove Nerd Font / Noto Sans Mono)

#### Scenario: Consumer overrides a single component

- GIVEN a consumer sets `omarchy.fonts.waybar = "Source Sans 3"`
- WHEN waybar renders
- THEN waybar uses `"Source Sans 3"` explicitly
- AND all other components remain at their defaults

#### Scenario: Consumer overrides terminal font

- GIVEN a consumer sets `omarchy.fonts.ghostty = "JetBrainsMono Nerd Font"`
- WHEN ghostty renders
- THEN ghostty uses `"JetBrainsMono Nerd Font"`
- AND all other components remain at their defaults

### Requirement: CSS and Config Generation

All generated configs SHALL use their respective `omarchy.fonts.<component>` option value instead of hardcoded font family strings.

| File | Current hardcoded value | Source |
|------|------------------------|--------|
| `config/waybar/style.css` | `'JetBrainsMono Nerd Font'` | `omarchy.fonts.waybar` |
| `modules/home-manager/swayosd.nix` | `'JetBrainsMono Nerd Font'` | `omarchy.fonts.swayosd` |
| `default/mako/core.ini` | `sans-serif 14px` | `omarchy.fonts.mako` |
| `walker-theme/style.css` | `monospace` | `omarchy.fonts.walker` |
| `modules/home-manager/hyprlock.nix` | `"CaskaydiaMono Nerd Font"` | `omarchy.fonts.hyprlock` |
| `modules/home-manager/alacritty.nix` | `"JetBrainsMono Nerd Font"` | `omarchy.fonts.alacritty` |
| `modules/home-manager/ghostty.nix` | `"JetBrainsMono Nerd Font"` | `omarchy.fonts.ghostty` |

Static CSS files (waybar, walker) SHALL be converted to generated templates with Nix string interpolation.

#### Scenario: Waybar CSS uses option value

- GIVEN `omarchy.fonts.waybar = "DejaVu Sans"`
- WHEN the waybar style.css is generated
- THEN the CSS contains `font-family: 'DejaVu Sans'`
- AND no reference to `JetBrainsMono Nerd Font` remains in the generated file

#### Scenario: Swayosd CSS uses option value

- GIVEN default font options
- WHEN swayosd style.css is generated
- THEN the CSS contains `font-family: 'sans-serif'`

#### Scenario: Alacritty config uses option value

- GIVEN `omarchy.fonts.alacritty = "Fira Code"`
- WHEN alacritty.toml is generated
- THEN `font.normal.family`, `font.bold.family`, and `font.italic.family` are all `"Fira Code"`

### Requirement: NixOS-Hosts Integration

The nixos-hosts configuration SHALL integrate the new omarchy-nix font options without modifying the system-level fontconfig policy.

- `home-linux/alacritty.nix` SHALL set `programs.alacritty.settings.font.normal.family = "CaskaydiaCove Nerd Font"` explicitly (not relying on omarchy defaults)
- `flake.nix` SHALL update the `omarchy-nix` input to point to the commit containing the font options
- `modules/desktop/fonts.nix` SHALL NOT be modified (already correct)

#### Scenario: Alacritty has explicit font on all hosts

- GIVEN the nixos-hosts flake is built for any Linux host (rog, thinkcentre, t14)
- WHEN alacritty configuration is generated
- THEN `font.normal.family` is `"CaskaydiaCove Nerd Font"` regardless of omarchy defaults

#### Scenario: System fontconfig unchanged

- GIVEN the fontconfig-sans-monospace change is applied
- WHEN `modules/desktop/fonts.nix` is inspected
- THEN the file is identical to its pre-change state

### Requirement: Web Browser Exclusion

fontconfig SHALL NOT include any per-application rules targeting web browsers (Firefox, Chromium, Brave, Chrome). Web content font resolution SHALL remain under browser engine control.

#### Scenario: No browser-targeted fontconfig rules

- GIVEN the fontconfig localConf XML
- WHEN inspected for `<test name="application">` entries
- THEN no entries match browser process names (firefox, chromium, brave, chrome)

### Requirement: Backward Compatibility

Existing omarchy-nix consumers that do not set any `omarchy.fonts.*` options SHALL see no breaking changes. The module SHALL evaluate successfully with all defaults.

#### Scenario: Zero-config upgrade

- GIVEN an existing omarchy-nix consumer with no font options set
- WHEN they update to the version with font options
- THEN `nix flake check` passes
- AND all components render with their default fonts
- AND no evaluation errors occur

#### Scenario: Unset options use defaults

- GIVEN `omarchy.fonts` is not referenced in consumer config
- WHEN any module reads `cfg.fonts.<component>`
- THEN the value is the documented default for that component

### Requirement: Validation

The following validation checks SHALL pass after implementation.

#### Scenario: Flake check passes

- GIVEN all changes are applied to nixos-hosts
- WHEN `nix flake check --no-build` runs
- THEN the command exits with status 0

#### Scenario: Formatting passes

- GIVEN all `.nix` files are modified
- WHEN `format-nix` runs on the repository
- THEN no files are reformatted (all files already conform)
