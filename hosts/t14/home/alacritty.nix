# T14 alacritty overlay — minimal non-theme settings.
#
# Omarchy supplies a complete alacritty config (omarchy's
# modules/home-manager/alacritty.nix) that includes the theme palette
# and the glats-style decorations.  This module adds ONLY the
# laptop-specific non-visual settings that should persist across
# theme switches:
#
#   * font: CaskaydiaCove Nerd Font (matches the ghostty module)
#   * font size: 11 (matches the ghostty module)
#   * padding: 6 (slightly tighter than desktop default)
#   * opacity: 0.92 (matches the ghostty module)
#
# REQ-006 / T3-003: port alacritty config to t14/home.
{ ... }:

{
  # The actual config is supplied by the omarchy HM module.  We don't
  # redefine the full schema here; instead, we extend the theme-aware
  # omarchy defaults with a per-host file drop.  This is the same
  # pattern used by t14/home/default.nix for ghostty.
  xdg.configFile."alacritty/t14-local.toml".text = ''
    # T14-specific alacritty overrides — applied after omarchy's config
    # via the [import] chain in alacritty.toml.
    [font]
    normal.family = "CaskaydiaCove Nerd Font"
    normal.style = "Regular"
    size = 11.0

    [window]
    opacity = 0.92
    padding = { x = 6, y = 6 }

    [scrolling]
    history = 100000
    multiplier = 3
  '';
}
