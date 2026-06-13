# T14 kitty overlay — minimal non-theme settings.
#
# Omarchy supplies a complete kitty config (omarchy's
# modules/home-manager/kitty.nix).  This module drops a per-host
# overrides file that kitty will source at startup, mirroring the
# alacritty pattern.
#
# REQ-006 / T3-003: port kitty config to t14/home.
{ ... }:

{
  xdg.configFile."kitty/t14-local.conf".text = ''
    # T14-specific kitty overrides — applied after omarchy's
    # ~/.config/kitty/kitty.conf.  Same source-of-truth pattern as
    # the alacritty and ghostty t14 overlays.
    font_family      CaskaydiaCove Nerd Font
    font_size        11.0
    background_opacity 0.92
    scrollback_lines 100000
    enable_audio_bell no
    window_padding_width 6
  '';
}
