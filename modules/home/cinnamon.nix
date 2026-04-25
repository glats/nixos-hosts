{ config, lib, pkgs, ... }:

let
  # gnome-terminal palette uses #RRGGBB:RRGGBB:... format
  palette = builtins.concatStringsSep ":" [
    "#${config.colorScheme.palette.base00}"
    "#${config.colorScheme.palette.base08}"
    "#${config.colorScheme.palette.base0B}"
    "#${config.colorScheme.palette.base0A}"
    "#${config.colorScheme.palette.base0D}"
    "#${config.colorScheme.palette.base0E}"
    "#${config.colorScheme.palette.base0C}"
    "#${config.colorScheme.palette.base05}"
    "#${config.colorScheme.palette.base03}"
    "#${config.colorScheme.palette.base09}"
    "#${config.colorScheme.palette.brightGreen}"
    "#${config.colorScheme.palette.brightYellow}"
    "#${config.colorScheme.palette.brightBlue}"
    "#${config.colorScheme.palette.brightMagenta}"
    "#${config.colorScheme.palette.brightCyan}"
    "#${config.colorScheme.palette.base07}"
  ];
in
{
  # Cinnamon uses dconf for settings (same as MATE/GNOME)
  # GTK theme shared via theme.nix, Qt via theme.nix

  dconf.settings = {
    # Desktop background
    "org/cinnamon/desktop/background" = {
      color-shading-type = "solid";
      picture-filename = "";
      picture-options = "none";
      primary-color = "#${config.colorScheme.palette.base00}";
      secondary-color = "#${config.colorScheme.palette.base00}";
    };

    # Interface theme
    "org/cinnamon/desktop/interface" = {
      gtk-theme = config.gtk.theme.name;
      icon-theme = "Papirus-Dark";
      cursor-theme = "mate-black";
      font-name = "Sans 10";
      document-font-name = "Sans 10";
      monospace-font-name = "CaskaydiaCove Nerd Font 11";
      buttons-have-icons = true;
      menus-have-icons = true;
      gtk-color-scheme = "visited_link_color:#${config.colorScheme.palette.base0E}";
    };

    # Window manager (muffin)
    "org/cinnamon/desktop/wm/preferences" = {
      button-layout = "menu:minimize,maximize,close";
      theme = config.gtk.theme.name;
      action-double-click-titlebar = "toggle_maximize";
    };

    # Keyboard and mouse
    "org/cinnamon/desktop/peripherals/keyboard" = {
      numlock-state = true;
    };

    "org/cinnamon/desktop/peripherals/mouse" = {
      cursor-theme = "mate-black";
    };

    # Session and screensaver (xrdp: disable)
    "org/cinnamon/desktop/session" = {
      idle-delay = 0;
    };

    "org/cinnamon/desktop/screensaver" = {
      lock-enabled = false;
      idle-activation-enabled = false;
    };

    # Nemo file manager
    "org/nemo/preferences" = {
      show-hidden-files = false;
      show-location-entry = true;
      default-folder-viewer = "list-view";
      thumbnail-limit = 104857600; # 100MB
    };

    "org/nemo/window-state" = {
      geometry = "800x550";
      maximized = false;
      start-with-sidebar = true;
      start-with-status-bar = true;
      start-with-toolbar = true;
    };

    # gnome-terminal color profile matching Glats palette
    "org/gnome/terminal/legacy/profiles/:/b1defddd-5273-4a7e-b257-7a06eb8714e3" = {
      visible-name = "Default";
      foreground-color = "#${config.colorScheme.palette.base05}";
      background-color = "#${config.colorScheme.palette.base00}";
      bold-color-same-as-fg = true;
      cursor-colors-set = true;
      cursor-background-color = "#${config.colorScheme.palette.base05}";
      "use-theme-colors" = false;
      use-system-font = false;
      font-name = "CaskaydiaCove Nerd Font 11";
      palette = palette;
      scrolling-mode = "normal";
      default-show-menubar = false;
    };

    "org/gnome/terminal/legacy/profiles:" = {
      list = [ "b1defddd-5273-4a7e-b257-7a06eb8714e3" ];
    };

    # GPaste clipboard manager
    "org/gnome/GPaste" = {
      show-history = true;
      sync-clipboard-to-primary = true;
      track-changes = true;
      max-history-size = 50;
      save-history = true;
    };
  };

  xdg.configFile = {
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

    # Disable cinnamon-power-manager in xrdp sessions
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

    # devilspie2 autostart for Cinnamon
    "autostart/devilspie2.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Devil's Pie II
      Comment=Window manipulation daemon
      Exec=devilspie2
      Terminal=false
      Type=Application
      OnlyShowIn=X-Cinnamon;
    '';

    # GPaste clipboard manager autostart for Cinnamon
    "autostart/gpaste-daemon.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=GPaste
      Comment=Clipboard management daemon
      Exec=${pkgs.gpaste}/libexec/gpaste/gpaste-daemon
      Terminal=false
      OnlyShowIn=X-Cinnamon;
      X-Cinnamon-Autostart-phase=Panel;
    '';
  };

  xdg.dataFile."applications/xrdp-back-to-picker.desktop".text = ''
    [Desktop Entry]
    Name=Back to Session Picker
    Comment=Log out and return to XRDP session picker
    Exec=${pkgs.nixos-scripts}/bin/xrdp-back-to-picker
    Icon=system-log-out
    Type=Application
    Terminal=false
    Categories=System;
    OnlyShowIn=X-Cinnamon;
  '';

  # devilspie2 script for gnome-terminal transparency - use activation to create a real file
  home.activation.setupDevilspie2 = config.lib.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "${config.home.homeDirectory}/.config/devilspie2"
        ${pkgs.coreutils}/bin/tee "${config.home.homeDirectory}/.config/devilspie2/terminal-opacity.lua" > /dev/null << 'EOF'
    if (get_window_class() == "gnome-terminal-server") then
      set_window_opacity(0.92)
    end
    EOF
  '';
}
