# Proposal: Fontconfig Sans/Monospace Separation + Omarchy-Nix Font Override

## Intent

omarchy-nix hardcodes `JetBrainsMono Nerd Font` in waybar, swayosd, alacritty, and ghostty — forcing a monospace terminal font on GUI surfaces (bar, OSD) and preventing consumers from customizing fonts without forking. We add a `fonts` option to omarchy-nix with sensible defaults (generic families for CSS surfaces, configurable specific font for terminals), then fix the nixos-hosts alacritty gap.

## Scope

### In Scope
- Add `omarchy.fonts` option submodule to omarchy-nix (`config.nix`) with `monospace` and `sans` fields
- Replace hardcoded font names in waybar CSS, swayosd CSS, alacritty, ghostty, hyprlock, walker, and hyprland groupbar with option references
- Set defaults: `monospace` → `"JetBrainsMono Nerd Font"`, `sans` → `"sans-serif"` (generic, resolved by fontconfig)
- Fix `home-linux/alacritty.nix` in nixos-hosts to set explicit `font.family` (currently missing — fragile)
- Update omarchy-nix flake input pin in nixos-hosts

### Out of Scope
- System-level fontconfig changes (`modules/desktop/fonts.nix` — already correct)
- Per-app fontconfig test rules (future follow-up)
- Walker font-family change (currently `monospace` — open question, keep as-is for now)
- mako changes (already uses `sans-serif` — correct)

## Capabilities

### New Capabilities
- `omarchy-fonts`: Configurable font options (`omarchy.fonts.monospace`, `omarchy.fonts.sans`) that propagate to all font-referencing modules in omarchy-nix

### Modified Capabilities
None (no existing specs)

## Approach

**Two-repo change, omarchy-nix first:**

**A. omarchy-nix** — Add to `config.nix`:
```nix
fonts = lib.mkOption {
  type = lib.types.submodule {
    options = {
      monospace = lib.mkOption { type = lib.types.str; default = "JetBrainsMono Nerd Font"; };
      sans = lib.mkOption { type = lib.types.str; default = "sans-serif"; };
    };
  };
  default = {};
};
```

Then update font references across modules:
| File | Current | New |
|------|---------|-----|
| `config/waybar/style.css` | `'JetBrainsMono Nerd Font'` | `cfg.fonts.sans` (via template) |
| `modules/home-manager/swayosd.nix` | `'JetBrainsMono Nerd Font'` | `cfg.fonts.sans` |
| `modules/home-manager/alacritty.nix` | `"JetBrainsMono Nerd Font"` | `cfg.fonts.monospace` |
| `modules/home-manager/ghostty.nix` | `"JetBrainsMono Nerd Font"` | `cfg.fonts.monospace` |
| `modules/home-manager/hyprlock.nix` | `"CaskaydiaMono Nerd Font"` | `cfg.fonts.monospace` |
| `modules/home-manager/hyprland/looknfeel.nix` | `monospace` | `cfg.fonts.monospace` |
| `walker-theme/style.css` | `monospace` | Keep (resolves correctly via fontconfig) |

Waybar/swayosd CSS must become generated (template-substituted) rather than static files, since they now reference Nix options. The theme-generator pattern already exists for other files.

**B. nixos-hosts** — Minimal changes:
- Bump `omarchy-nix` flake input to new commit
- Add `programs.alacritty.settings.font.normal.family = "CaskaydiaCove Nerd Font"` in `home-linux/alacritty.nix`
- Optionally set `omarchy.fonts.sans = "Source Sans 3"` in `hosts/t14/home/omarchy.nix` (or accept default `sans-serif` which resolves identically via fontconfig)

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `omarchy-nix:config.nix` | Modified | Add `fonts` submodule option |
| `omarchy-nix:modules/home-manager/swayosd.nix` | Modified | Replace hardcoded font with `cfg.fonts.sans` |
| `omarchy-nix:modules/home-manager/alacritty.nix` | Modified | Replace hardcoded font with `cfg.fonts.monospace` |
| `omarchy-nix:modules/home-manager/ghostty.nix` | Modified | Replace hardcoded font with `cfg.fonts.monospace` |
| `omarchy-nix:modules/home-manager/hyprlock.nix` | Modified | Replace hardcoded font with `cfg.fonts.monospace` |
| `omarchy-nix:modules/home-manager/hyprland/looknfeel.nix` | Modified | Replace `monospace` with `cfg.fonts.monospace` |
| `omarchy-nix:config/waybar/style.css` | Modified | Convert to generated template with `cfg.fonts.sans` |
| `omarchy-nix:modules/home-manager/waybar.nix` | Modified | Generate style.css from template |
| `nixos-hosts:home-linux/alacritty.nix` | Modified | Add explicit font.family |
| `nixos-hosts:flake.nix` | Modified | Bump omarchy-nix input |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Waybar CSS generation breaks existing static file deployment | Low | Follow existing theme-generator pattern; test with `nixos-build dry` |
| Existing omarchy-nix users see font changes on upgrade | Low | Defaults preserve current behavior for terminals; CSS surfaces change from JetBrainsMono to `sans-serif` (improvement) |
| `cfg.fonts` not accessible in static CSS files | Medium | Convert waybar style.css to generated file (like theme-generator already does for other CSS) |

## Rollback Plan

Revert the omarchy-nix flake input to the previous commit in nixos-hosts. The fonts option is additive — removing it restores all hardcoded defaults.

## Dependencies

- omarchy-nix PR merged and committed before nixos-hosts flake bump

## Success Criteria

- [ ] `omarchy.fonts.monospace` and `omarchy.fonts.sans` options exist and are documented
- [ ] Waybar renders with `sans-serif` (not JetBrainsMono) by default
- [ ] Swayosd renders with `sans-serif` by default
- [ ] Terminals (alacritty, ghostty) use `cfg.fonts.monospace` — overridable
- [ ] Alacritty in nixos-hosts has explicit font family set
- [ ] `nix flake check --no-build` passes on nixos-hosts
- [ ] Setting `omarchy.fonts.sans = "Source Sans 3"` in t14 changes waybar/swayosd font

## Open Questions

1. **Walker font**: Keep `monospace` (TUI-like launcher aesthetic) or switch to `sans-serif` (GUI launcher consistency with waybar/swayosd)?
2. **Override granularity**: The current design uses two global categories (monospace/sans). Is per-component override needed (e.g., separate font for lock screen vs terminals)?
3. **Default sans value**: `"sans-serif"` (generic, fontconfig-resolved) vs a specific font like `"Source Sans 3"`?
