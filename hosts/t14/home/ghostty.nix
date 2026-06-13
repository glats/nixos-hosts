# T14 Ghostty configuration — non-theme settings.
#
# Theme is owned by omarchy's theme runtime
# (ghostty loads it from ~/.config/omarchy/current/theme/ghostty.conf).
# This module sets only the structural / performance / font options
# that should persist across theme switches.
#
# Key choices:
#   * font-family    = CaskaydiaCove Nerd Font  (matches fontconfig mono
#                       alias and the glats theme waybar.css).
#   * font-size      = 11  (slightly larger than omarchy default 10
#                       for the 14" 1920x1200 panel).
#   * scrollback    = 4294967295  (effectively unlimited; 32-bit max so
#                       ghostty's u32-typed config field accepts it).
#   * async-backend = epoll  (best performance on Linux for input and
#                       render; was thread before).
#   * background-opacity = 0.9  (slight translucency for the laptop
#                       panel; matches pre-migration feel).
#   * mouse-scroll-multiplier = 0.95  (slightly slower scroll for finer
#                       control on the laptop touchpad).
#   * font-feature = "liga"  (enable programming ligatures; pairs with
#                       CaskaydiaCove Nerd Font which ships liga gs).
#
# REMOVED keys (rejected by Ghostty 1.3.1 as unknown INI fields):
#   * `renderer` — the OpenGL renderer is selected at build time and
#       exposed by `ghostty +show-config`; it is not user-configurable
#       in the INI file. AMD Phoenix 3 GPU is covered by the default.
#   * `gtk-theme = "dark"` — superseded by the single `theme = "name"`
#       option. The active theme is injected by omarchy's runtime
#       symlink (~/.config/omarchy/current/theme/ghostty.conf), which
#       sets `theme = glats`; specifying `gtk-theme` here would
#       conflict and is rejected by the config validator.
{ lib, ... }:

{
  programs.ghostty = {
    enable = true;
    settings = {
      # Font: CaskaydiaCove Nerd Font — matches modules/desktop/fonts.nix
      # monoForceNames alias and the glats theme.  Slightly larger for
      # the laptop display.
      font-family = "CaskaydiaCove Nerd Font";
      font-size = 11;

      # Opacity tuned for the built-in display
      background-opacity = 0.9;

      # Async epoll backend (best for Linux input + render throughput)
      async-backend = "epoll";

      # Effectively unlimited scrollback — long log analysis without
      # a cap.  0 is "no scrollback" in ghostty (rejected as a request
      # to disable), so we use the u32 max (4294967295) which behaves
      # as "scroll forever, ctrl+shift+k to clear".
      scrollback-limit = 4294967295;

      # Slightly slower scroll speed for finer control on the touchpad
      mouse-scroll-multiplier = 0.95;

      # Enable programming ligatures (CaskaydiaCove Nerd Font ships
      # ligature glyphs for =>, ->, !=, etc.)
      font-feature = "liga";
    };
  };
}
