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
  doubleHex = hex: lib.concatStrings (lib.concatMap (c: [ c c ]) (lib.stringToCharacters hex));
  byteDoubleHex = hex:
    let
      r = lib.substring 0 2 hex;
      g = lib.substring 2 2 hex;
      b = lib.substring 4 2 hex;
    in
    "${r}${r}${g}${g}${b}${b}";
in
{
  dconf.settings = {
    "org/mate/caja/list-view" = {
      default-column-order = [ "name" "size" "type" "date_modified" "date_accessed" "date_created" "extension" "group" "where" "mime_type" "octal_permissions" "owner" "permissions" "size_on_disk" ];
      default-visible-columns = [ "name" "size" "type" "date_modified" ];
    };

    "org/mate/caja/window-state" = {
      geometry = "800x550+555+218";
      maximized = false;
      start-with-sidebar = true;
      start-with-status-bar = true;
      start-with-toolbar = true;
    };

    "org/mate/desktop/accessibility/keyboard" = {
      bouncekeys-beep-reject = true;
      bouncekeys-delay = 300;
      bouncekeys-enable = false;
      enable = false;
      feature-state-change-beep = false;
      mousekeys-accel-time = 1200;
      mousekeys-enable = false;
      mousekeys-init-delay = 160;
      mousekeys-max-speed = 750;
      slowkeys-beep-accept = true;
      slowkeys-beep-press = true;
      slowkeys-beep-reject = false;
      slowkeys-delay = 300;
      slowkeys-enable = false;
      stickykeys-enable = false;
      stickykeys-latch-to-lock = true;
      stickykeys-modifier-beep = true;
      stickykeys-two-key-off = true;
      timeout = 120;
      timeout-enable = false;
      togglekeys-enable = false;
    };

    "org/mate/desktop/applications/calculator" = {
      exec = "mate-calc";
    };

    "org/mate/desktop/applications/terminal" = {
      exec = "mate-terminal";
    };

    "org/mate/desktop/background" = {
      color-shading-type = "solid";
      picture-filename = "";
      picture-options = "none";
      primary-color = "#000000";
      secondary-color = "#000000";
      show-desktop-icons = false;
    };

    "org/mate/desktop/interface" = {
      buttons-have-icons = true;
      gtk-color-scheme = "visited_link_color:#${config.colorScheme.palette.base0E}";
      gtk-decoration-layout = "menu:minimize,maximize,close";
      gtk-theme = config.gtk.theme.name;
      icon-theme = "Papirus-Dark";
      menus-have-icons = true;
    };

    "org/mate/desktop/peripherals/keyboard" = {
      numlock-state = "on";
    };

    "org/mate/desktop/peripherals/mouse" = {
      cursor-theme = "mate-black";
    };

    "org/mate/desktop/session" = {
      idle-delay = 0;
      session-start = 1773706877;
    };

    "org/mate/marco/general" = {
      action-double-click-titlebar = "toggle_maximize";
      button-layout = "menu:minimize,maximize,close";
      theme = config.gtk.theme.name;
    };

    "org/mate/marco/global-keybindings" = {
      run-command-1 = "<Control>space";
    };

    "org/mate/marco/keybinding-commands" = {
      command-1 = "${pkgs.rofi}/bin/rofi -show drun";
    };

    "org/mate/notification-daemon" = {
      popup-location = "top_right";
      theme = "slider";
    };

    "org/mate/panel/general" = {
      history-mate-run = [ "conky" "pkill conky" "pkill config" "mate-control-center" "scrot -d 3" "flameshot" "brave" "rofi" ];
      object-id-list = [ "object-0" "notification-area" "clock" "object-3" ];
      toplevel-id-list = [ "bottom" ];
    };

    "org/mate/panel/objects/clock" = {
      applet-iid = "ClockAppletFactory::ClockApplet";
      locked = true;
      object-type = "applet";
      panel-right-stick = true;
      position = 10;
      toplevel-id = "bottom";
    };

    "org/mate/panel/objects/clock/prefs" = {
      cities = [ "<location name=\"\" city=\"Santiago\" timezone=\"America/Santiago\" latitude=\"-33.383331\" longitude=\"-70.783333\" code=\"SCEL\" current=\"true\"/>" ];
      show-temperature = true;
      show-weather = true;
    };

    "org/mate/panel/objects/notification-area" = {
      applet-iid = "NotificationAreaAppletFactory::NotificationArea";
      locked = true;
      object-type = "applet";
      panel-right-stick = true;
      position = 20;
      toplevel-id = "bottom";
    };

    "org/mate/panel/objects/object-0" = {
      locked = true;
      object-type = "menu";
      panel-right-stick = false;
      position = 0;
      tooltip = "Compact Menu";
      toplevel-id = "bottom";
      use-menu-path = false;
    };

    #    "org/mate/panel/objects/object-2" = {
    #      object-type = "separator";
    #      panel-right-stick = false;
    #      position = 1515;
    #      toplevel-id = "bottom";
    #    };

    "org/mate/panel/objects/object-3" = {
      applet-iid = "WnckletFactory::WindowListApplet";
      object-type = "applet";
      panel-right-stick = false;
      position = 24;
      toplevel-id = "bottom";
    };

    "org/mate/panel/toplevels/bottom" = {
      expand = true;
      orientation = "bottom";
      screen = 0;
      size = 24;
      y = 1096;
      y-bottom = 0;
    };

    "org/mate/panel/toplevels/bottom/background" = {
      color = "${hexToRgb config.colorScheme.palette.base00}";
      type = "color";
    };

    "org/mate/pluma" = {
      bottom-panel-size = 140;
      side-panel-active-page = 827629879;
      side-panel-size = 200;
      size = "(650, 500)";
      state = 128;
      statusbar-visible = true;
    };

    "org/mate/power-manager" = {
      button-power = "interactive";
      button-lid-ac = "suspend";
      button-lid-battery = "suspend";
      button-suspend = "suspend";
    };

    "org/mate/screenshot" = {
      border-effect = "none";
      delay = 0;
      include-border = true;
      include-pointer = true;
    };

    "org/mate/screensaver" = {
      idle-activation-enabled = false;
      lock-enabled = false;
    };

    "org/mate/terminal/profiles/default" = {
      background-color = "#${doubleHex config.colorScheme.palette.base00}";
      background-darkness = 0.92139737991266379;
      background-type = "transparent";
      bold-color-same-as-fg = true;
      cursor-color = "#${doubleHex config.colorScheme.palette.base05}";
      default-show-menubar = false;
      font = "CaskaydiaCove Nerd Font 11";
      foreground-color = "#${doubleHex config.colorScheme.palette.base05}";
      palette = "#${doubleHex config.colorScheme.palette.base00}:#${doubleHex config.colorScheme.palette.base08}:#${doubleHex config.colorScheme.palette.base0B}:#${doubleHex config.colorScheme.palette.base0A}:#${doubleHex config.colorScheme.palette.base0D}:#${doubleHex config.colorScheme.palette.base0E}:#${doubleHex config.colorScheme.palette.base0C}:#${doubleHex config.colorScheme.palette.base05}:#${doubleHex config.colorScheme.palette.base03}:#${byteDoubleHex config.colorScheme.palette.base09}:#${byteDoubleHex config.colorScheme.palette.brightGreen}:#${byteDoubleHex config.colorScheme.palette.brightYellow}:#${byteDoubleHex config.colorScheme.palette.brightBlue}:#${byteDoubleHex config.colorScheme.palette.brightMagenta}:#${byteDoubleHex config.colorScheme.palette.brightCyan}:#${doubleHex config.colorScheme.palette.base07}";
      show-menubar = false;
      use-system-font = false;
      use-theme-colors = false;
      visible-name = "Default";
    };
  };



  xdg.dataFile."applications/mate-terminal.desktop".text = ''
    [Desktop Entry]
    Name=Terminal
    Comment=Use the command line
    Exec=${pkgs.mate-terminal}/bin/mate-terminal --maximize
    Icon=utilities-terminal
    Type=Application
    Terminal=false
    Categories=GNOME;GTK;Utility;TerminalEmulator;System;
    Keywords=command line;execute;interpret;MATE;
    OnlyShowIn=MATE;
    StartupNotify=true
  '';

  xdg.dataFile."applications/xrdp-back-to-picker.desktop".text = ''
    [Desktop Entry]
    Name=Back to Session Picker
    Comment=Log out and return to XRDP session picker
    Exec=sh -c "XRDP_SESSION=1 ${pkgs.nixos-scripts}/bin/xrdp-back-to-picker"
    Icon=system-log-out
    Type=Application
    Terminal=false
    Categories=System;
    OnlyShowIn=MATE;
  '';

  xdg.configFile = {
    "autostart/copyq.desktop".text = ''
      [Desktop Entry]
      Name=CopyQ
      Comment=Clipboard Manager with Advanced Features
      Icon=copyq
      Exec=${pkgs.copyq}/bin/copyq
      Terminal=false
      Type=Application
      Categories=GTK;GNOME;Application;Utility;
      OnlyShowIn=MATE;
      X-MATE-Autostart-enabled=true
    '';


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
      OnlyShowIn=MATE;
      X-MATE-Autostart-enabled=true
    '';

    # Disable mate-screensaver in xrdp sessions - causes disconnection issues
    "autostart/mate-screensaver.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Screensaver
      Comment=Launch screensaver and locker program
      Icon=preferences-desktop-screensaver
      Exec=mate-screensaver
      OnlyShowIn=MATE;
      Hidden=true
    '';

    # Disable mate-power-manager in xrdp sessions - not needed in remote sessions
    "autostart/mate-power-manager.desktop".text = ''
      [Desktop Entry]
      Name=Power Manager
      Comment=Power management daemon
      Icon=mate-power-manager
      Exec=mate-power-manager
      Terminal=false
      Type=Application
      OnlyShowIn=MATE;
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
      OnlyShowIn=MATE;
      X-MATE-Autostart-enabled=true
    '';
  };
}
