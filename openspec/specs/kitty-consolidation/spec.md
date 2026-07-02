# Kitty Consolidation Specification

## Purpose

Constraint spec for consolidating kitty terminal configuration into a single source of truth (`home-linux/kitty.nix`) that produces byte-identical config across all three Linux hosts (rog, thinkcentre, t14). Mirrors the proven `ghostty.nix` `lib.mkForce` pattern.

## Requirements

### Requirement: Host Uniformity

The kitty terminal configuration MUST be byte-identical across rog and thinkcentre after evaluation. On t14, omarchy-nix settings MAY merge into the kitty config via attrset union (e.g., `include`, `background_opacity`, keybindings). No host other than t14 MAY contribute additional kitty settings beyond what `home-linux/kitty.nix` declares.

(Previously: Required byte-identical config across all three hosts including t14, with no omarchy-nix contributions allowed.)

#### Scenario: rog and thinkcentre produce same kitty.conf

- GIVEN rog and thinkcentre evaluate their home-manager configurations
- WHEN `programs.kitty.settings` is serialized to `~/.config/kitty/kitty.conf`
- THEN the resulting file content is byte-identical on both hosts

#### Scenario: t14 merges omarchy-nix defaults

- GIVEN t14 imports omarchy-nix's `homeManagerModules.default` which includes `modules/home-manager/kitty.nix`
- WHEN `home-linux/kitty.nix` evaluates with `lib.mkDefault` on `programs.kitty.settings`
- THEN omarchy-nix's `mkDefault` keys (include, background_opacity, keybindings) merge via attrset union alongside nixos-hosts's keys

### Requirement: mkDefault Override Pattern

`home-linux/kitty.nix` MUST wrap `programs.kitty.settings` in `lib.mkDefault { ... }`. The default attrset MUST contain user preferences, color definitions, and padding/delay settings. On t14, omarchy-nix's `mkDefault` keys that are NOT re-declared in this block (e.g., `include`) SHALL merge in. On rog/thinkcentre, no omarchy-nix is imported, so `mkDefault` is the effective priority.

(Previously: Used `lib.mkForce` which replaced the entire attrset, dropping all omarchy-nix defaults not explicitly re-declared.)

#### Scenario: mkDefault merges with omarchy on t14

- GIVEN omarchy-nix's kitty.nix sets `settings = lib.mkDefault { include = "~/.config/omarchy/current/theme/kitty.conf"; background_opacity = "0.95"; ... }`
- WHEN `home-linux/kitty.nix` evaluates with `settings = lib.mkDefault { background_opacity = lib.mkForce "0.9"; ... }`
- THEN the merged `programs.kitty.settings` contains keys from both attrsets; keys unique to omarchy-nix (`include`) survive, keys unique to nixos-hosts survive, keys with matching values in both (`window_padding_width`, `repaint_delay`, `input_delay`, `sync_to_monitor`) merge cleanly, and `background_opacity` resolves to `"0.9"` via the inline `lib.mkForce`

#### Scenario: rog/thinkcentre unaffected by omarchy-nix

- GIVEN rog and thinkcentre do NOT import omarchy-nix
- WHEN `home-linux/kitty.nix` evaluates
- THEN `lib.mkDefault` has no competing priority — settings are applied as-is

### Requirement: Color Derivation

Exactly 26 color entries MUST be derived from `config.colorScheme.palette` inside the `lib.mkForce` block: background, foreground, cursor, selection_background, selection_foreground, color0–color7 (normal), color8–color15 (bright), and color16–color21 (extended 256-color space). All values MUST use base16 mapping consistent with `home-linux/ghostty.nix`.

#### Scenario: Colors match ghostty palette mapping

- GIVEN `config.colorScheme.palette` provides base00–base0F
- WHEN colors are derived inside `lib.mkForce`
- THEN color0 = base00, color1 = base08, ..., color7 = base05, color8 = base03, color9–color14 reuse base08/0B/0A/0D/0E/0C, color15 = base07, color16 = base09, color17 = base0F, color18 = base01, color19 = base02, color20 = base04, color21 = base06

### Requirement: omarchy-nix Font Wiring

omarchy-nix's `modules/home-manager/kitty.nix` MUST replace the hardcoded `font.name = lib.mkDefault "JetBrainsMono Nerd Font"` with `font.name = lib.mkDefault cfg.fonts.kitty`, where `cfg = config.omarchy`. This mirrors the pattern already used by `cfg.fonts.ghostty` and `cfg.fonts.alacritty` in the same directory.

#### Scenario: Default font resolves to omarchy.fonts.kitty

- GIVEN `config.omarchy.fonts.kitty` defaults to `"monospace"` in `config.nix`
- WHEN omarchy-nix's kitty module evaluates without any override
- THEN `programs.kitty.font.name` resolves to `"monospace"`

#### Scenario: t14 overrides kitty font to CaskaydiaCove

- GIVEN `hosts/t14/home/omarchy.nix` sets `omarchy.fonts.kitty = lib.mkForce "CaskaydiaCove Nerd Font"`
- WHEN omarchy-nix's kitty module evaluates on t14
- THEN `programs.kitty.font.name` resolves to `"CaskaydiaCove Nerd Font"`

### Requirement: t14 Font Override

`hosts/t14/home/omarchy.nix` MUST add `omarchy.fonts.kitty = lib.mkForce "CaskaydiaCove Nerd Font"` alongside the existing per-component font overrides (waybar, swayosd, mako, rofi).

#### Scenario: t14 kitty uses CaskaydiaCove, other hosts use default

- GIVEN rog and thinkcentre do not set `omarchy.fonts.kitty`
- WHEN all three hosts evaluate
- THEN t14's kitty font is `"CaskaydiaCove Nerd Font"` and rog/thinkcentre's kitty font is whatever `home-linux/kitty.nix` declares in its `lib.mkDefault` block

### Requirement: Runtime Theme Recoloring on t14

On t14, the kitty config MUST include omarchy-nix's `include` directive so that `omarchy-theme-set` can recolor kitty at runtime without a NixOS rebuild.

#### Scenario: omarchy-theme-set recolors kitty on t14

- GIVEN t14 has run `omarchy-theme-set <theme>` which places a symlink at `~/.config/omarchy/current/theme/kitty.conf`
- WHEN kitty reads `~/.config/kitty/kitty.conf`
- THEN the config contains `include ~/.config/omarchy/current/theme/kitty.conf`
- AND kitty renders the palette from the omarchy theme file

#### Scenario: kitty.conf on t14 contains include directive

- GIVEN t14 evaluates its home-manager configuration
- WHEN `~/.config/kitty/kitty.conf` is inspected
- THEN the file contains an `include` line pointing to `~/.config/omarchy/current/theme/kitty.conf`

### Requirement: Omarchy Merge Acceptance on t14

On t14, the following omarchy-nix values SHALL be accepted via mkDefault merge (not overridden by nixos-hosts):

| Key | Omarchy Value | Behavior |
|-----|---------------|----------|
| `include` | `"~/.config/omarchy/current/theme/kitty.conf"` | Merges in (not declared in kitty.nix) |
| `ctrl+insert` | `copy_to_clipboard` | Merges in (additive keybinding) |
| `shift+insert` | `paste_from_clipboard` | Merges in (additive keybinding) |

`background_opacity` is NOT accepted from omarchy-nix on t14 — nixos-hosts forces `"0.9"` via inline `lib.mkForce` so the value is `"0.9"` on all three hosts. The four other overlapping keys (`window_padding_width`, `repaint_delay`, `input_delay`, `sync_to_monitor`) have identical values in both modules, so they merge cleanly with no explicit priority.

#### Scenario: t14 background_opacity is 0.9

- GIVEN t14 evaluates its configuration
- WHEN `programs.kitty.settings.background_opacity` is inspected
- THEN the value is `"0.9"` (from nixos-hosts, via inline `lib.mkForce`)

#### Scenario: t14 has omarchy clipboard keybindings

- GIVEN t14 evaluates its configuration
- WHEN `programs.kitty.keybindings` is inspected
- THEN `ctrl+insert` maps to `copy_to_clipboard`
- AND `shift+insert` maps to `paste_from_clipboard`
