# T14 Hyprland input -- keyboard layout override + optional full-opacity gate.
# All other input settings (touchpad, gestures, windowrules, opacity) are
# owned by omarchy-nix upstream.  The full-opacity override below is gated so
# it can be disabled to restore omarchy's per-app translucent opacity rules.
{ lib, ... }:

let
  # Force full opacity (1.0/1.0) on every window, overriding omarchy's
  # per-app opacity theme system.  Set to false to restore omarchy's
  # translucent window rules (0.97/0.9 etc).
  forceFullOpacity = true;
in
{
  wayland.windowManager.hyprland.settings.input = {
    kb_layout = lib.mkForce "es,latam";
    kb_options = lib.mkForce "grp:alt_shift_toggle";
  };

  # When enabled, mkAfter ensures this rule comes after ALL of omarchy's
  # extraConfig and wins.  omarchy's per-app rules tag windows with
  # `-default-opacity` to opt out, so a plain `match:tag default-opacity`
  # rule alone is insufficient -- the match-all is required to force every
  # window opaque.
  wayland.windowManager.hyprland.extraConfig =
    lib.optionalString forceFullOpacity (lib.mkAfter ''
      windowrule = opacity 1.0 1.0, match:class .*
    '');
}
