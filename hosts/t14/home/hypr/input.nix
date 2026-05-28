# T14 Hyprland input configuration.
# Tweaked for the ThinkPad keyboard / touchpad.
#
# NOTE: omarchy's hyprland/input.nix sets kb_layout = "us" via lib.mkDefault.
# T14 uses es+latam layout, so we must use lib.mkForce here to override.
{ lib, ... }:

{
  wayland.windowManager.hyprland.settings = {
    input = {
      # T14 keyboard: Spanish primary, LatAm as secondary; Alt-Shift toggles.
      # mkForce required because omarchy's input.nix also sets kb_layout.
      kb_layout = lib.mkForce "es,latam";
      kb_options = lib.mkForce "grp:alt_shift_toggle,compose:caps";

      # Touchpad: clickfinger (physical click).
      # omarchy's touchpad.clickfinger_behavior = true already; omit to avoid
      # unnecessary override.  Natural scroll stays at omarchy default (false)
      # since ThinkPad buttons provide their own scroll feel.
      # touchpad.natural_scroll = false (omarchy default — keep it)

      repeat_rate    = 40;
      repeat_delay   = 250;
      follow_mouse   = 1;
      sensitivity    = 0;
      numlock_by_default = true;
    };
  };
}