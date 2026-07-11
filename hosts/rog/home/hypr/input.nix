# Rog Hyprland input -- keyboard layout "es" (rog's current layout).
# All other input settings owned by omarchy-nix upstream.
{ lib, ... }:

{
  wayland.windowManager.hyprland.settings.input = {
    kb_layout = lib.mkForce "es";
  };
}
