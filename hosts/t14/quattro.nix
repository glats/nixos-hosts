{ lib, ... }:
{
  omarchy.quattro.enable = true;
  security.pam.services.omarchy-lock-password = { };
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
          left = [
            { id = "omarchy.menu"; }
            { id = "omarchy.workspaces"; }
          ];
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
      idle = {
        screensaver = 150;
        lock = 151;
      };
      disabledPlugins = [
        "omarchy.nightlight"
        "omarchy.agents"
        "omarchy.monitor"
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
  home-manager.users.glats.xdg.configFile."omarchy/extensions/omarchy-menu.jsonc".text =
    builtins.toJSON
      (
        builtins.listToAttrs (
          map (id: lib.nameValuePair id { when = "false"; }) [
            "install"
            "remove"
            "setup.reset"
            "update.channel"
            "setup.direct-boot"
            "setup.security.passwordless-sudo"
            "update.config"
            "update.firmware"
            "trigger.tests"
            "setup.network.qr"
            "setup.plugin"
            "setup.default"
            "style.font"
            "style.bar"
            "style.unlock"
            "style.hyprland"
            "setup.monitors"
            "setup.keybindings"
            "setup.input"
          ]
        )
        // {
          "learn.arch" = {
            icon = "󱄅";
            label = "NixOS";
            action = "omarchy-launch-webapp 'https://nixos.org/manual/nixos/stable/'";
          };
          "style.theme" = {
            when = "false";
            action = "omarchy-notification-send \"Theme\" \"glats is managed by Nix. See hosts/t14/quattro-themes.md to make themes switchable.\"";
          };
        }
      );
}
