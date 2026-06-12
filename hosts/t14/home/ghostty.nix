# T14 Ghostty configuration — non-theme settings.
#
# Theme is owned by omarchy's theme runtime
# (ghostty loads it from ~/.config/omarchy/current/theme/ghostty.conf).
# This module sets only the structural / performance / font options
# that should persist across theme switches.
#
# Key choices (Phase 2 corrections from the spec):
#   * font-family    = CaskaydiaCove Nerd Font  (matches fontconfig mono
#                       alias and the glats theme waybar.css).
#   * font-size      = 11  (slightly larger than omarchy default 10
#                       for the 14" 1920x1200 panel).
#   * scrollback    = unlimited  (was 10000; long log analysis benefits
#                       from no cap).
#   * async-backend = epoll  (best performance on Linux for input and
#                       render; was thread before).
#   * renderer      = OpenGL  (AMD Phoenix 3 APU native).
#   * background-opacity = 0.92  (slight translucency for the laptop
#                       panel; matches pre-migration feel).
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
      background-opacity = 0.92;

      # OpenGL backend for AMD Phoenix 3 APU
      renderer = "OpenGL";

      # Async epoll backend (best for Linux input + render throughput)
      async-backend = "epoll";

      # Unlimited scrollback — long log analysis without a cap.
      # Ghostty defaults to 10000; we lift the limit to match tmux-style
      # expectation of "scroll forever, ctrl+shift+k to clear".
      scrollback-limit = 0;

      # GTK theming follows omarchy dark theme
      gtk-theme = "dark";
    };
  };
}
