# Rog Hyprland monitor configuration.
# Static config -- no HDM on rog (lid-switch disabled, HandleLidSwitch=ignore).
# Intel iGPU drives eDP-1 (internal laptop panel).
# NVIDIA drives HDMI-1 via xrdp headless Xorg only (not Hyprland).
{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    monitor = [
      "eDP-1,preferred,auto,1"
      # "HDMI-1,preferred,auto,1"  # External monitor (if connected to Intel iGPU)
    ];

    env = [ "GDK_SCALE,1" ];
  };
}
