# T14-specific colorScheme module.
#
# Sets `config.colorScheme` from `shared/palette.nix` (the project's
# glats palette).  This is a NARROWER version of the shared
# `home-linux/theme.nix`: we deliberately omit the GTK/Qt/dconf
# blocks because omarchy's own home-manager module sets
# `gtk.theme.name = "Adwaita-dark"` and the two definitions would
# abort evaluation.
#
# Why this is needed:
#   * `t14/home/ghostty.nix`, `t14/home/kitty.nix`, and
#     `shared/tmux.nix` all read `config.colorScheme.palette` to
#     resolve their colors.
#   * Without this module, `config.colorScheme` falls back to
#     whatever omarchy's `inputs.nix-colors.colorSchemes.${theme}`
#     produces (currently tokyo-night), so the terminal palettes and
#     tmux status colors do not match the project's glats palette.
#
# Why `lib.mkForce` on the whole attrset:
#   Omarchy's `homeManagerModules.default` already sets
#   `colorScheme = selectedColorScheme` for the active omarchy theme
#   (e.g. tokyo-night).  When we ALSO set `colorScheme` here at the
#   same priority, Nix's per-key attribute merging concatenates the
#   string values inside `palette` (e.g. `1A1B26` from tokyo-night +
#   `000000` from glats = `1A1B26000000`, 12 chars) — which then
#   breaks every consumer that calls
#   `nix-colors.lib.conversions.hexToRGB` on the result.  `lib.mkForce`
#   bumps our definition's priority above omarchy's, so the merge
#   short-circuits and the whole `colorScheme` attrset is replaced
#   by our glats palette.
#
# Tradeoffs vs. importing `home-linux/theme.nix`:
#   * rog/thinkcentre (MATE/GNOME hosts) use the shared module
#     unchanged, so they keep their GTK icon theming and unfocused-
#     selection CSS.  t14 does not, because Hyprland's GTK theming
#     runs through omarchy's `~/.config/omarchy/current/theme/` and
#     we ship a `glats` theme directory for that.
#   * Anything in the shared `theme.nix` that reads
#     `config.colorScheme.palette` still works the same way on t14
#     (e.g. `home-linux/rofi.nix`, `home-linux/conky-*.nix`),
#     because this module sets the same `colorScheme` attribute.
{ lib, ... }:

{
  colorScheme = lib.mkForce (import ../../../shared/palette.nix);
}
