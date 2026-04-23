{ config, lib, pkgs, hostName, ... }:

let
  hexToRgb = hex:
    let
      r = lib.substring 0 2 hex;
      g = lib.substring 2 2 hex;
      b = lib.substring 4 2 hex;
      toDec = h: lib.fromHexString h;
    in
    "rgb(${toString (toDec r)},${toString (toDec g)},${toString (toDec b)})";
in
{
  # Cinnamon uses dconf for settings (same as MATE/GNOME)
  # GTK theme is shared via theme.nix

  dconf.settings = {
    "org/cinnamon/desktop/background" = {
      color-shading-type = "solid";
      picture-filename = "";
      picture-options = "none";
      primary-color = "${hexToRgb config.colorScheme.palette.base00}";
      secondary-color = "${hexToRgb config.colorScheme.palette.base00}";
    };

    "org/cinnamon/desktop/interface" = {
      gtk-theme = config.gtk.theme.name;
      icon-theme = "Papirus-Dark";
      cursor-theme = "mate-black";
      font-name = "Sans 10";
    };

    "org/cinnamon/desktop/wm/preferences" = {
      button-layout = "menu:minimize,maximize,close";
      theme = config.gtk.theme.name;
    };

    "org/cinnamon/desktop/peripherals/keyboard" = {
      numlock-state = true;
    };

    "org/cinnamon/desktop/session" = {
      idle-delay = 0;
    };

    "org/cinnamon/desktop/screensaver" = {
      lock-enabled = false;
      idle-activation-enabled = false;
    };
  };

  xdg.configFile = {
    # CopyQ clipboard manager
    "autostart/copyq.desktop".text = ''
      [Desktop Entry]
      Name=CopyQ
      Comment=Clipboard Manager with Advanced Features
      Icon=copyq
      Exec=${pkgs.copyq}/bin/copyq
      Terminal=false
      Type=Application
      Categories=GTK;Utility;
      OnlyShowIn=X-Cinnamon;
      X-GNOME-Autostart-enabled=true
    '';

    # Flameshot screenshot tool - use X11 legacy path for xrdp compatibility
    "autostart/org.flameshot.Flameshot.desktop".text = ''
      [Desktop Entry]
      Name=Flameshot
      GenericName=Screenshot tool
      Comment=Powerful yet simple to use screenshot software.
      Keywords=flameshot;screenshot;capture;shutter;
      Exec=${pkgs.flameshot}/bin/flameshot
      Icon=org.flameshot.Flameshot
      Terminal=false
      Type=Application
      Categories=Graphics;
      StartupNotify=false
      StartupWMClass=flameshot
      OnlyShowIn=X-Cinnamon;
      X-GNOME-Autostart-enabled=true
    '';

    # Disable cinnamon-screensaver in xrdp sessions
    "autostart/cinnamon-screensaver.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Screensaver
      Comment=Launch screensaver and locker program
      Icon=preferences-desktop-screensaver
      Exec=cinnamon-screensaver
      OnlyShowIn=X-Cinnamon;
      Hidden=true
    '';

    # Disable power manager in xrdp sessions
    "autostart/cinnamon-power-manager.desktop".text = ''
      [Desktop Entry]
      Name=Power Manager
      Comment=Power management daemon
      Icon=mate-power-manager
      Exec=mate-power-manager
      Terminal=false
      Type=Application
      OnlyShowIn=X-Cinnamon;
      Hidden=true
    '';
  } // lib.optionalAttrs (hostName == "rog") {
    "autostart/io.github.Hexchat.desktop".text = ''
      [Desktop Entry]
      Name=HexChat
      GenericName=IRC Client
      Comment=Chat with other people online
      Keywords=IM;Chat;
      Exec=${pkgs.hexchat}/bin/hexchat --existing %U
      Icon=io.github.Hexchat
      Terminal=false
      Type=Application
      Categories=GTK;Network;IRCClient;
      StartupNotify=true
      StartupWMClass=Hexchat
      MimeType=x-scheme-handler/irc;x-scheme-handler:ircs;
      OnlyShowIn=X-Cinnamon;
      X-GNOME-Autostart-enabled=true
    '';
  };
}