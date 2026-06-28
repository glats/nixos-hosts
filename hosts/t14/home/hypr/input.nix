# T14 Hyprland input — keyboard layout override only.
# All other input settings (touchpad, gestures, windowrules, opacity)
# are owned by omarchy-nix upstream and match t14's needs.
{ lib, ... }:

{
  wayland.windowManager.hyprland.settings.input = {
    # Chile: es (Spain) + latam (Latin America); Alt+Shift toggles.
    # mkForce required because omarchy's input.nix sets kb_layout = "us".
    kb_layout = lib.mkForce "es,latam";
    kb_options = lib.mkForce "grp:alt_shift_toggle,compose:caps";
  };
}
