{ config, ... }:

{
  wayland.windowManager.hyprland.settings = {
    env = [ "GDK_SCALE,1" ];
  };

  wayland.windowManager.hyprland.extraConfig = ''
    source = ${config.home.homeDirectory}/.config/hypr/monitors.conf
  '';
}
