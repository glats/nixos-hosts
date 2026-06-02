# T14 waybar local additions.
#
# Omarchy owns the waybar config and theme CSS.
# This module is reserved for t14-specific waybar customisation.
# Currently omarchy's theme CSS is used as-is; local CSS overrides
# can be added here in future by providing waybar/style.css.
#
# NOTE: To add CSS overrides without losing omarchy theme switching:
#   1. Add your overrides to waybar/style.css using @import to pull in
#      the omarchy theme from ~/.config/omarchy/current/theme/waybar.css
#   2. Set source = ./waybar/style.css in the home.file override below
#
# For now: no override — omarchy theme is used unchanged.
{ ... }:

{
  # Placeholder — no local waybar overrides active yet.
  # Uncomment and create waybar/style.css to add t14-specific tweaks.
  # home.file = {
  #   ".config/waybar/style.css" = {
  #     source = ./waybar/style.css;
  #   };
  # };
}
