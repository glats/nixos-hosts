# T14 Ghostty configuration — non-theme settings.
#
# Theme is owned by omarchy's theme runtime
# (ghostty loads it from ~/.config/omarchy/current/theme/ghostty.conf).
# This module sets only the structural/performance options:
#   - font size tuned for the 14" 1920x1200 panel
#   - background opacity for the laptop display
#   - OpenGL backend for AMD iGPU
{ lib, ... }:

{
  programs.ghostty = {
    enable = true;
    settings = {
      # Font — slightly larger than omarchy default for the laptop panel
      font-family = "JetBrainsMono Nerd Font";
      font-size   = 10;

      # Opacity tuned for the built-in display
      background-opacity = 0.92;

      # OpenGL backend for AMD Phoenix 3 APU
      renderer = "OpenGL";

      # GTK theming follows omarchy dark theme
      gtk-theme = "dark";
    };
  };
}