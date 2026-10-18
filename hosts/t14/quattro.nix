{ ... }:
{
  omarchy.quattro.enable = true;
  omarchy.quattro.shell = {
    enable = true;
    settings = {
      version = 1;
      bar = {
        id = "omarchy.bar";
        position = "top";
        transparent = false;
        centerAnchor = "omarchy.clock";
        layout = {
          left = [ { id = "omarchy.workspaces"; } ];
          center = [
            {
              id = "omarchy.indicators";
              items = [
                "ScreenRecording"
                "NightLight"
                "Dnd"
                "StayAwake"
              ];
            }
            {
              id = "omarchy.clock";
              format = "dddd HH:mm";
            }
            { id = "omarchy.weather"; }
          ];
          right = [
            { id = "omarchy.media"; }
            { id = "omarchy.tray"; }
            { id = "omarchy.audio"; }
            { id = "omarchy.bluetooth"; }
            { id = "omarchy.network"; }
            { id = "omarchy.power"; }
            { id = "omarchy.keyboard-layout"; }
          ];
        };
      };
      disabledPlugins = [
        "omarchy.menu"
        "omarchy.background"
        "omarchy.lock"
        "omarchy.idle"
        "omarchy.polkit"
        "omarchy.nightlight"
        "omarchy.reminders"
        "omarchy.agents"
        "omarchy.monitor"
        "omarchy.image-picker"
        "omarchy.dev-gallery"
        "omarchy.tailscale"
        "omarchy.dropbox"
        "omarchy.speedtest"
        "omarchy.disk-speedtest"
        "omarchy.wifiqr"
      ];
      plugins = [ ];
    };
  };
  home-manager.users.glats.wayland.windowManager.hyprland.configType = "hyprlang";
}
