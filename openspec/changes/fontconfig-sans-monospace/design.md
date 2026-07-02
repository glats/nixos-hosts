# Design: Omarchy-Nix Per-Component Font Override

## Technical Approach

Add 8 flat `omarchy.fonts.<component>` string options to omarchy-nix. Thread values through Nix module settings (alacritty, ghostty, hyprlock, hyprland groupbar) and extend the theme-generator to emit `font-family` into per-theme CSS (waybar, swayosd). Defaults preserve terminal fonts; GUI surfaces switch to generic `sans-serif`.

## Architecture Decisions

| Decision | Choice | Alternative | Rationale |
|----------|--------|-------------|-----------|
| Option shape | Flat strings (`omarchy.fonts.waybar = "sans-serif"`) | Submodule `{ family, size, weight }` | Only family is needed today; flat = simpler UX, matches existing `primary_font` pattern |
| CSS threading | Extend theme-generator `mkWaybar`/`mkSwayosd` to emit `* { font-family: ...; }` | Convert static CSS to full Nix generation | Minimal change — keeps existing static+import pattern, only adds font line to generated theme CSS |
| Hyprlock font | Nix string interpolation in `settings.font_family` | Hyprlock `$variable` in .conf | `font_family` lives in structured `settings` (not `extraConfig`), so interpolation is needed. Same pattern as `looknfeel.nix` border colors |
| Walker font | Keep hardcoded `monospace` in static CSS | Add to fonts options + generate | User decided mono for TUI aesthetic; CSS already says `monospace` which resolves correctly via fontconfig. No change needed |
| Mako font | Keep `sans-serif` in `default/mako/core.ini` | Generate via theme-generator | Already correct; core.ini is deployed as static source file. Making it configurable requires structural change with no benefit today |

## Data Flow

```
User HM config
  omarchy.fonts.waybar = "Source Sans 3";
         │
         ▼
config.nix (omarchyOptions.fonts.*)
         │
    ┌────┴────────────────────┐
    ▼                         ▼
Nix modules              theme-generator.nix
(alacritty.nix,          (mkWaybar, mkSwayosd,
 ghostty.nix,             mkHyprlock)
 hyprlock.nix,                │
 hyprland/looknfeel.nix)      ▼
    │                   ~/.config/omarchy/
    ▼                   themes/<theme>/{waybar.css,
~/.config/...            swayosd.css, hyprlock.conf}
direct config
files
```

## File Changes — omarchy-nix

| File | Action | Description |
|------|--------|-------------|
| `config.nix` | Modify | Add `fonts` attrset to `omarchyOptions` with 8 `lib.types.str` options |
| `modules/home-manager/swayosd.nix` | Modify | `font-family: 'JetBrainsMono Nerd Font'` → `cfg.fonts.swayosd` |
| `modules/home-manager/alacritty.nix` | Modify | All `family = "JetBrainsMono Nerd Font"` → `cfg.fonts.alacritty` |
| `modules/home-manager/ghostty.nix` | Modify | `font-family = "JetBrainsMono Nerd Font"` → `cfg.fonts.ghostty` |
| `modules/home-manager/hyprlock.nix` | Modify | Both `font_family = "CaskaydiaMono Nerd Font"` → `cfg.fonts.hyprlock` |
| `modules/home-manager/hyprland/looknfeel.nix` | Modify | `font_family = monospace` → `font_family = ${cfg.fonts.hyprland}` |
| `modules/home-manager/theme-generator.nix` | Modify | `mkWaybar`: add `* { font-family: ${cfg.fonts.waybar}; }`. `mkSwayosd`: add `* { font-family: ${cfg.fonts.swayosd}; }`. `mkHyprlock`: add `$font_family = "${cfg.fonts.hyprlock}";` |
| `config/waybar/style.css` | Modify | Remove `font-family: 'JetBrainsMono Nerd Font';` from `*` block (now in generated theme CSS) |

## File Changes — nixos-hosts

| File | Action | Description |
|------|--------|-------------|
| `flake.nix` | Modify | Bump `omarchy-nix` input to new commit |
| `home-linux/alacritty.nix` | Modify | Add `settings.font.normal.family = "CaskaydiaCove Nerd Font"` (fix fragile fontconfig fallback) |

## Option Defaults

| Component | Default | Category | Current hardcoded value |
|-----------|---------|----------|------------------------|
| `waybar` | `"sans-serif"` | GUI | `'JetBrainsMono Nerd Font'` |
| `swayosd` | `"sans-serif"` | GUI | `'JetBrainsMono Nerd Font'` |
| `mako` | `"sans-serif"` | GUI | `sans-serif` (core.ini, unchanged) |
| `walker` | `"monospace"` | TUI | `monospace` (unchanged) |
| `rofi` | `"sans-serif"` | GUI | N/A (not in omarchy-nix) |
| `hyprlock` | `"monospace"` | Lock | `"CaskaydiaMono Nerd Font"` |
| `alacritty` | `"monospace"` | Terminal | `"JetBrainsMono Nerd Font"` |
| `ghostty` | `"monospace"` | Terminal | `"JetBrainsMono Nerd Font"` |
| `hyprland` | `"monospace"` | WM | `monospace` (groupbar) |

## Interfaces / Contracts

New option path in `config.nix`:

```nix
fonts = {
  waybar    = lib.mkOption { type = lib.types.str; default = "sans-serif"; };
  swayosd   = lib.mkOption { type = lib.types.str; default = "sans-serif"; };
  mako      = lib.mkOption { type = lib.types.str; default = "sans-serif"; };
  walker    = lib.mkOption { type = lib.types.str; default = "monospace"; };
  rofi      = lib.mkOption { type = lib.types.str; default = "sans-serif"; };
  hyprlock  = lib.mkOption { type = lib.types.str; default = "monospace"; };
  alacritty = lib.mkOption { type = lib.types.str; default = "monospace"; };
  ghostty   = lib.mkOption { type = lib.types.str; default = "monospace"; };
  hyprland  = lib.mkOption { type = lib.types.str; default = "monospace"; };
};
```

## Template Changes — Waybar (before/after)

**Before** — `config/waybar/style.css`:
```css
@import "../omarchy/current/theme/waybar.css";
* {
  background-color: @background;
  color: @foreground;
  font-family: 'JetBrainsMono Nerd Font';
  font-size: 12px;
}
```

**After** — `config/waybar/style.css`:
```css
@import "../omarchy/current/theme/waybar.css";
* {
  background-color: @background;
  color: @foreground;
  font-size: 12px;
}
```

**After** — `theme-generator.nix` `mkWaybar`:
```nix
mkWaybar = p: ''
  @define-color foreground #${p.base05};
  @define-color background #${p.base00};
  @define-color warning #${p.base08};
  * { font-family: ${cfg.fonts.waybar}; }
'';
```

## Migration / Rollout

**Terminal fonts**: Default `"monospace"` resolves to JetBrainsMono Nerd Font (omarchy-nix package set) — no visual change.

**GUI surfaces (waybar, swayosd)**: Default changes from JetBrainsMono Nerd Font → `sans-serif` (resolves to Source Sans 3 via fontconfig). This is the intended improvement.

**Backward compat**: Existing omarchy-nix users who want the old mono bar can set `omarchy.fonts.waybar = "JetBrainsMono Nerd Font"`.

**nixos-hosts**: `home-linux/ghostty.nix` already uses `lib.mkForce` on the entire ghostty settings attrset, overriding omarchy-nix. No change needed. `home-linux/kitty.nix` sets its own font. No change needed.

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Build | Eval passes | `nix flake check --no-build` on nixos-hosts |
| Visual | Waybar/swayosd render sans | Screenshot after `nixos-build switch` on t14 |
| Override | Custom font propagates | Set `omarchy.fonts.waybar = "Source Sans 3"`, verify in rendered CSS |
| Regression | Terminal fonts unchanged | `fc-match monospace` + visual check ghostty/alacritty |

## Open Questions

None.
