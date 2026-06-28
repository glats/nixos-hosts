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

  # Opacity override: omarchy's windows.nix sets opacity 0.97 0.90
  # via extraConfig (appended after settings). We append a final
  # override via mkAfter to keep everything fully opaque.
  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    windowrule = opacity 1.0 1.0, match:tag default-opacity
  '';
}
