{ lib, ... }:

let
  forceFullOpacity = true;
in
{
  wayland.windowManager.hyprland.settings.input = {
    kb_layout = lib.mkForce "es,latam";
    kb_options = lib.mkForce "grp:alt_shift_toggle";
  };

  wayland.windowManager.hyprland.extraConfig = lib.optionalString forceFullOpacity (
    lib.mkAfter ''
      windowrule = opacity 1.0 1.0, match:class .*
    ''
  );
}
