# Delta for Kitty Consolidation

## MODIFIED Requirements

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
- THEN the merged `programs.kitty.settings` contains keys from both attrsets, with `home-linux/kitty.nix` values winning on conflicts (mkForce on background_opacity overrides omarchy's mkDefault)

#### Scenario: rog/thinkcentre unaffected by omarchy-nix

- GIVEN rog and thinkcentre do NOT import omarchy-nix
- WHEN `home-linux/kitty.nix` evaluates
- THEN `lib.mkDefault` has no competing priority — settings are applied as-is

### Requirement: t14 Font Override

`hosts/t14/home/omarchy.nix` MUST add `omarchy.fonts.kitty = lib.mkForce "CaskaydiaCove Nerd Font"` alongside the existing per-component font overrides.

#### Scenario: t14 kitty uses CaskaydiaCove, other hosts use default

- GIVEN rog and thinkcentre do not set `omarchy.fonts.kitty`
- WHEN all three hosts evaluate
- THEN t14's kitty font is `"CaskaydiaCove Nerd Font"` and rog/thinkcentre's kitty font is whatever `home-linux/kitty.nix` declares in its `lib.mkDefault` block

(Previously: Referenced `lib.mkForce` block; now references `lib.mkDefault` block.)

## ADDED Requirements

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
| `background_opacity` | `"0.95"` | Overridden by nixos-hosts's `lib.mkForce "0.9"` on t14 |
| `ctrl+insert` | `copy_to_clipboard` | Merges in (additive keybinding) |
| `shift+insert` | `paste_from_clipboard` | Merges in (additive keybinding) |

#### Scenario: t14 uses nixos-hosts opacity 0.9

- GIVEN t14 evaluates its configuration
- WHEN `programs.kitty.settings.background_opacity` is inspected
- THEN the value is `"0.9"` (nixos-hosts's `lib.mkForce` overrides omarchy-nix's `"0.95"`)

#### Scenario: t14 has omarchy clipboard keybindings

- GIVEN t14 evaluates its configuration
- WHEN `programs.kitty.keybindings` is inspected
- THEN `kitty_mod+insert` maps to `copy_to_clipboard`
- AND `shift+insert` maps to `paste_from_clipboard`
