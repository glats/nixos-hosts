# T14 Hyprland monitor configuration.
# Primary display: built-in 14" 1920x1080 panel.
# External monitors are hot-plugged via monitor-hotplug-handler.sh.
{ lib, ... }:

{
  wayland.windowManager.hyprland.settings = {
    # T14 built-in display — 1920x1080 @ 60Hz
    # This is the laptop panel that should always be active.
    # External monitors added with desc: matching for stable identification
    # across reconnects (connector names like DP-3/DP-4/DP-5 shift on hot-plug).
    monitor = lib.mkForce [
      "eDP-1,preferred,auto,1"
      "desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x0,1,transform,1"
      "desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x0,1"
      "desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x0,1"
    ];

    # Explicit GDK_SCALE=1 to prevent GTK apps from using default scaling.
    # The T14 panel is 1920x1080 @ 1x — no HiDPI scaling needed.
    # This list merges with looknfeel.nix's env via Nix attrset union.
    env = [ "GDK_SCALE,1" ];
  };
}
