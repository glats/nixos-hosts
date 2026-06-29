# T14 Hyprland input — keyboard layout override only.
# All other input settings (touchpad, gestures, windowrules, opacity)
# are owned by omarchy-nix upstream and match t14's needs.
{ lib, ... }:

{
  wayland.windowManager.hyprland.settings.input = {
    # Chile: es (Spain) + latam (Latin America); Alt+Shift toggles.
    # mkForce required because omarchy's input.nix sets kb_layout = "us".
    # compose:caps is removed: it would remap CAPS LOCK to the Compose key,
    # breaking the dead-key sequence (backtick+letter) that produces accented
    # characters in GTK apps. fcitx5 supplies the accented IME layer.
    kb_layout = lib.mkForce "es,latam";
    kb_options = lib.mkForce "grp:alt_shift_toggle";
  };

  # Opacity override: omarchy's windows.nix + apps.conf set per-app
  # opacity rules (0.97/0.9 for most windows, 1.0/0.97 for browsers,
  # 0.97/0.9 for terminals, etc).  Those rules use `tag -default-opacity`
  # to opt out of the default tag, so a `match:tag default-opacity` rule
  # alone is insufficient.  This final match-all rule is appended via
  # lib.mkAfter to ensure it comes after ALL of omarchy's extraConfig
  # and forces full opacity on every window.
  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    windowrule = opacity 1.0 1.0, match:class .*
  '';
}
