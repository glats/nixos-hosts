# Proposal: OpenCode Glats Theme for Grey Contrast on t14

## Intent

OpenCode TUI greys (#333333, #444444, etc.) are invisible on t14 because:
1. Both hosts use ghostty with identical config → OpenCode receives bg=`#000000` on both
2. `theme = "system"` enters `generateGrayScale`'s `luminance < 10` branch → produces #08–#66 greys
3. On rog, **XRDP color compression** accidentally lightens these greys, making them visible
4. On t14, Wayland native rendering delivers pixel-exact colors, revealing the true problem

The glats palette already has adequate greys (base03=#767676, base04=#a0a0a0);
they just need to be mapped explicitly into OpenCode's ThemeJson tokens so the
`system` theme's dynamic greys are bypassed entirely.

## Scope

### In Scope
- Create a `glats.json` custom OpenCode theme that maps the full glats base16 palette to ThemeJson tokens.
- Deploy the theme file via Home Manager (`xdg.configFile`).
- Change `shared/opencode.nix` to set `theme = "glats"` in `tui.json`.
- Verify contrast is adequate on t14 without regressing rog.

### Out of Scope
- Changing the glats `base00` value (would affect every app across all hosts).
- Switching to a built-in non-glats theme.
- Modifying ghostty opacity, palette, or any other terminal config.

## Capabilities

### New Capabilities
- `opencode-glats-theme`: Custom OpenCode ThemeJson that uses the glats base16 palette for all UI tokens.

### Modified Capabilities
- `opencode-tui-config`: The `theme` field in `tui.json` changes from `"system"` to `"glats"`.

## Approach

1. Add a new HM module `home-linux/opencode-theme.nix` that writes `~/.config/opencode/themes/glats.json` with explicit ThemeJson mappings:
   - `text` → base05 (#e0e0e0)
   - `textMuted` → base04 (#a0a0a0)
   - `backgroundPanel` → base01 (#1a1a1a)
   - `border` → base03 (#767676)
   - `borderActive` → base04 (#a0a0a0)
   - `diffContext` → base03 (#767676)
   - ANSI slots → base08..base0F
2. Import `home-linux/opencode-theme.nix` into `home-linux/shared-modules.nix` so all Linux hosts get the theme file.
3. Change `theme = "system"` to `theme = "glats"` in `shared/opencode.nix` (`tui.json`).
4. Run `nix flake check --no-build` to validate.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `home-linux/opencode-theme.nix` | New | HM module deploying `~/.config/opencode/themes/glats.json`. |
| `home-linux/shared-modules.nix` | Modified | Imports the new opencode-theme module. |
| `shared/opencode.nix` | Modified | `tui.json` theme field changes to `"glats"`. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| OpenCode ThemeJson schema drifts in a future version. | Low | Pin opencode version (currently 1.17.11); document schema dependency in a comment. |
| Theme change affects rog/thinkcentre negatively. | Low | The custom theme uses the same glats palette already active on all hosts; only greys become more explicit. Verify on rog after deploy. |
| User-level `tui.json` edits are overwritten. | Med | `tui.json` is already managed with `force = true`; the change makes the default deterministic. |

## Rollback Plan

1. Revert `shared/opencode.nix` to `theme = "system"`.
2. Remove `home-linux/opencode-theme.nix` and its import from `shared-modules.nix`.
3. Rebuild and switch. OpenCode will fall back to the previous system-theme behavior.

## Dependencies

- None external. The glats palette is already defined in `shared/palette.nix` and mirrored in omarchy-nix.

## Success Criteria

- [ ] `nix flake check --no-build` passes.
- [ ] OpenCode TUI on t14 shows visible borders, panels, and muted text.
- [ ] OpenCode TUI on rog continues to render correctly (no regression).
- [ ] Theme persists across `nixos-rebuild switch` and `home-manager switch`.
