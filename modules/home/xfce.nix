{ config, lib, ... }:

let
  hexToRgb = hex:
    let
      r = lib.substring 0 2 hex;
      g = lib.substring 2 2 hex;
      b = lib.substring 4 2 hex;
      toDec = h: lib.fromHexString h;
    in
    "${toString (toDec r)},${toString (toDec g)},${toString (toDec b)}";
in
{
  # XFCE uses xfconf for settings (Home Manager: programs.xfconf)
  # GTK theme shared via theme.nix, Qt via theme.nix

  xfconf.settings = {
    # Terminal colors matching Glats palette
    "xfce4-terminal" = {
      "color-foreground" = "#${config.colorScheme.palette.base05}";
      "color-background" = "#${config.colorScheme.palette.base00}";
      "color-palette" = "${config.colorScheme.palette.base00};${config.colorScheme.palette.base08};${config.colorScheme.palette.base0B};${config.colorScheme.palette.base0A};${config.colorScheme.palette.base0D};${config.colorScheme.palette.base0E};${config.colorScheme.palette.base0C};${config.colorScheme.palette.base05};${config.colorScheme.palette.base03};${config.colorScheme.palette.base09};${config.colorScheme.palette.brightGreen};${config.colorScheme.palette.brightYellow};${config.colorScheme.palette.brightBlue};${config.colorScheme.palette.brightMagenta};${config.colorScheme.palette.brightCyan};${config.colorScheme.palette.base07}";
      "color-bold" = "#${config.colorScheme.palette.base05}";
      "color-cursor" = "#${config.colorScheme.palette.base05}";
      "color-bold-is-bright" = false;
      "background-mode" = "none";
      "font-name" = "CaskaydiaCove Nerd Font 11";
      "misc-menubar-default" = false;
      "misc-toolbar-default" = false;
      "scrolling-bar" = "normal";
      "scrolling-on-output" = false;
      "scrolling-unlimited" = true;
    };

    # Window manager
    "xfwm4" = {
      "theme" = config.gtk.theme.name;
      "button-layout" = "menu:minimize,maximize,close";
      "title-font" = "Sans Bold 9";
    };

    # Panel background matching base00
    "xfce4-panel" = {
      "panel-background-style" = 1; # solid color
      "panel-background-alpha" = 100;
      "panel-background-rgba" = "rgba(${hexToRgb config.colorScheme.palette.base00},1.0)";
    };

    };

  xdg.configFile = {
    # Disable xfce4-screensaver in xrdp sessions
    "autostart/xfce4-screensaver.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Screensaver
      Comment=Launch screensaver and locker program
      Icon=preferences-desktop-screensaver
      Exec=xfce4-screensaver
      OnlyShowIn=XFCE;
      Hidden=true
    '';

    # Disable xfce4-power-manager in xrdp sessions
    "autostart/xfce4-power-manager.desktop".text = ''
      [Desktop Entry]
      Name=Power Manager
      Comment=Power management daemon
      Icon=xfce4-power-manager
      Exec=xfce4-power-manager
      Terminal=false
      Type=Application
      OnlyShowIn=XFCE;
      Hidden=true
    '';
  };
}