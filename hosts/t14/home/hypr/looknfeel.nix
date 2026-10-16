{ lib, ... }:

{
  wayland.windowManager.hyprland.settings = {

    general = {
      gaps_in = lib.mkForce 0;
      gaps_out = lib.mkForce 2.5;
    };

    decoration = lib.mkForce {
      rounding = 0;
      shadow.enabled = false;
      blur.enabled = false;
    };

    misc.initial_workspace_tracking = false;
  };

  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    windowrule = float on, match:class ^([Xx]dg-desktop-portal-gtk)$
    windowrule = center on, match:class ^([Xx]dg-desktop-portal-gtk)$
    windowrule = size 875 600, match:class ^([Xx]dg-desktop-portal-gtk)$
    windowrule = border_size 0, match:class ^([Xx]dg-desktop-portal-gtk)$

    windowrule = float on, match:modal 1
    windowrule = center on, match:modal 1
    windowrule = border_size 0, match:modal 1
  '';
}
