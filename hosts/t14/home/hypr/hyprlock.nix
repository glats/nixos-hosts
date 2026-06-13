# T14 Hyprlock configuration.
#
# This module overrides specific upstream omarchy hyprlock settings
# with the user's t14-specific values.
#
# - Sources the active omarchy theme's hyprlock.conf at the top of the
#   file.  This is the key difference from upstream: the theme file
#   provides $color, $inner_color, $outer_color, $font_color, and
#   $check_color variables.  All five are referenced below.
# - ignore_empty_input = true (matches upstream, not overridden).
# - background: blur_passes = 3, path = current background image.
#   Color comes from the theme's $color variable (overrides upstream's
#   rgba(26, 27, 38, 0.8) base00 colour).
# - animations disabled (matches upstream, not overridden).
# - input-field: size 650x100 (overrides upstream's 600x100), centered.
#   Uses theme variables for inner/outer/font/check colors (overrides
#   upstream's hard-coded base02/base04/base05 colours).  font_family
#   = "Source Sans Pro" (overrides upstream's "CaskaydiaMono Nerd
#   Font").  placeholder_text = "Enter Password" (overrides upstream's
#   "Enter Password  " with Nerd Font icon).
# - auth.fingerprint.enabled = false (overrides upstream's true).
#
# Because `programs.hyprlock.settings` is an attrset that deep-merges
# (sub-keys are unioned by key), t14's per-key definitions OVERRIDE
# the upstream values for keys both modules set.  lib.mkForce is used
# to win against upstream's same-priority values.
#
# The `source` line is declared as a top-level setting rather than
# via extraConfig so that toHyprconf's `sourceFirst` (the HM default
# = true) places it before any other block.  The theme variables
# ($color, $inner_color, etc.) must be defined before the
# background/input-field blocks that reference them.
{ lib, ... }:

{
  programs.hyprlock = {
    enable = true;
    settings = {
      # Source the active omarchy theme at the top of the file.  The
      # toHyprconf generator emits this line first because "source" is
      # in the default `importantPrefixes` list when sourceFirst=true.
      # The theme provides $color, $inner_color, $outer_color,
      # $font_color, and $check_color variables used below.
      source = "~/.config/omarchy/current/theme/hyprlock.conf";

      background = {
        color = lib.mkForce "$color";
      };

      input-field = {
        size = lib.mkForce "650, 100";
        inner_color = lib.mkForce "$inner_color";
        outer_color = lib.mkForce "$outer_color";
        font_family = lib.mkForce "Source Sans Pro";
        font_color = lib.mkForce "$font_color";
        placeholder_text = lib.mkForce "Enter Password";
        check_color = lib.mkForce "$check_color";
      };

      auth = {
        fingerprint.enabled = lib.mkForce false;
      };
    };
  };
}
