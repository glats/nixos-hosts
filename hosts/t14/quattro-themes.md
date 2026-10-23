# t14 themes: glats from Nix, switcher disabled

The t14 theme is `glats`, defined in Nix and applied by Home Manager. The
Quattro theme switcher is disabled on purpose so nothing mutable overrides it.
This page explains why and how to make themes switchable later.

## Current design

| Piece | Owner |
|-------|-------|
| Color scheme | Fork `modules/custom-base16-schemes.nix` (`glats`), selected in `hosts/t14/omarchy-config.nix` |
| Theme files | Fork `modules/home-manager/theme-generator.nix` writes `~/.config/omarchy/themes/glats/*` (read-only, Home Manager) |
| Apps with baked colors | Read `config.colorScheme.palette` at build time: Hyprland `looknfeel`, hyprlock, btop, walker, tmux, superfile, ghostty, kitty |
| Apps that follow theme files | Symlink to `~/.config/omarchy/current/theme/*`: ghostty, kitty, alacritty, zellij, mako, waybar, swayosd |
| Quattro shell colors | Fork `quattro-shell.nix` writes `~/.local/state/omarchy/current/theme/{colors,shell}.toml` from the same palette |
| Menu `Style > Theme` and `SUPER SHIFT CTRL SPACE` | Hidden; the action only shows a notification pointing here (`hosts/t14/quattro.nix`) |

The menu entry is hidden *and* its action replaced, because the shell runs an
action route directly when a keybinding opens it, even when the row is hidden.

## Why not the Quattro switcher as is

- Quattro writes the theme to mutable state (`~/.local/state/omarchy/current/theme`)
  and deletes that directory on every switch, including the two files Home
  Manager manages there. Each rebuild would fight it.
- Apps with baked colors would stay `glats` after switching, so any other theme
  would be a mix.
- From the menu, the Quattro switcher currently ends in the fork's v3
  `omarchy-theme-set`, which repoints the config link and restarts v3 services.

## Making themes switchable later

Pick one path.

### Path A: Nix-native switcher (recommended)

All apps change together and the result stays reproducible.

1. Express each wanted Quattro theme as a base16 scheme in the fork
   (`custom-base16-schemes.nix`), deriving colors from the theme's
   `colors.toml` in the Quattro runtime `themes/<name>/`.
2. Let the switcher write only the selected name, then rebuild. The fork's
   `theme-switcher.nix` already does this with a path watcher; point its writer
   at the Quattro switcher output instead of the old Walker menu.
3. Unhide `style.theme` in `hosts/t14/quattro.nix` and set its action to that
   writer.
4. Update `menuOwnedByShell` in `tests/t14-quattro-compatibility.nix`, which
   asserts the theme entry is hidden and never runs `omarchy-theme-set`.

Cost: one rebuild per switch (tens of seconds).

### Path B: Quattro writes the theme

Fast switching, but apps with baked colors stay `glats`.

1. Add the Quattro theme scripts to `panelCommands` in the fork
   `quattro-shell.nix` so the shell runs them instead of the v3 copies:
   `omarchy-theme-set`, `omarchy-theme-switcher`, `omarchy-theme-list`,
   `omarchy-theme-dir`, `omarchy-theme-current`.
2. Stop Home Manager from managing files inside
   `~/.local/state/omarchy/current/theme`; generate `colors.toml` and
   `shell.toml` into `~/.config/omarchy/themes/glats/` instead, which Quattro
   copies on switch.
3. Repoint `~/.config/omarchy/current/theme` to the state directory once with
   an activation script, the same way `seedQuattroBackground` handles the
   background link.
4. Unhide `style.theme`, restore its upstream action, and update
   `menuOwnedByShell`.

## Checklist before switching designs

- [ ] `glats` is still the current theme after the first rebuild.
- [ ] Lock screen, bar, terminal and Hyprland borders show the same colors.
- [ ] A rebuild after switching does not revert or break the chosen theme.
- [ ] The t14 regression files pass (`tests/t14-quattro-*.nix`).
