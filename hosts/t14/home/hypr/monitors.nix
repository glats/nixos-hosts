# T14 Hyprland monitor configuration.
# Primary display: built-in 14" 1920x1200 panel.
# External monitors are hot-plugged via monitor-hotplug-handler.sh.
{ lib, ... }:

{
  wayland.windowManager.hyprland.settings = {
    # T14 built-in display — 1920x1200 @ 60Hz
    # This is the laptop panel that should always be active.
    monitor =
      let
        builtin = "DP-2,preferred,auto,1";
      in
      lib.mkDefault builtin;
  };
}