{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    inputs.omarchy-nix.homeManagerModules.default

    ./hypr/monitors.nix
    ./hypr/input.nix
    ./hypr/looknfeel.nix
    ./hypr/groups.nix
    ./hypr/hyprlock.nix
    ./hypr/hyprsunset.nix

    ./mouse-wiggle.nix
    ../../../linux/home/webcam.nix

    ./fcitx5.nix
    ./mpv.nix
    ./thinkfan-ui.nix

    ../../../linux/home/gaming.nix
  ];

  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  wayland.windowManager.hyprland.systemd.enable = false;

  home.hyprdynamicmonitors = {
    enable = lib.mkDefault true;
    configFile = ../hdm/config.toml;
    extraFiles = {
      "hyprdynamicmonitors/hyprconfigs/docked-lid-open.conf" = ../hdm/hyprconfigs/docked-lid-open.conf;
      "hyprdynamicmonitors/hyprconfigs/docked-lid-closed.conf" =
        ../hdm/hyprconfigs/docked-lid-closed.conf;
      "hyprdynamicmonitors/hyprconfigs/undocked-lid-open.conf" =
        ../hdm/hyprconfigs/undocked-lid-open.conf;
      "hyprdynamicmonitors/hyprconfigs/undocked-lid-closed.conf" =
        ../hdm/hyprconfigs/undocked-lid-closed.conf;
      "hyprdynamicmonitors/hyprconfigs/fallback.conf" = ../hdm/hyprconfigs/fallback.conf;
    };
    extraFlags = [ "--enable-lid-events" ];
    installExamples = false;
  };

  systemd.user.services.waybar = lib.mkIf (!(config.omarchy.quattro.shell.enable or false)) {
    Unit = {
      Description = "Waybar status bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = [ "WAYLAND_DISPLAY" ];
      StartLimitBurst = 5;
      StartLimitIntervalSec = "10s";
    };
    Service = {
      ExecStart = "${pkgs.waybar}/bin/waybar";
      Restart = "always";
      RestartSec = "100ms";
      StandardOutput = "null";
      StandardError = "journal";
      SyslogIdentifier = "waybar";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  home.file = {
    ".local/share/omarchy/bin/kb-toggle.sh" = {
      source = ./scripts/kb-toggle.sh;
      executable = true;
    };

    ".local/share/omarchy/bin/kb-layout.sh" = {
      source = ./scripts/kb-layout.sh;
      executable = true;
    };

    ".config/hypr/kb-layout.sh" = {
      source = ./scripts/kb-layout.sh;
      executable = true;
    };
    ".config/hypr/kb-toggle.sh" = {
      source = ./scripts/kb-toggle.sh;
      executable = true;
    };
  };

  programs.zsh.zplug.enable = lib.mkForce false;
  programs.starship.enable = lib.mkForce false;

  fonts.fontconfig.enable = lib.mkForce false;

  omarchy.fonts.waybar = lib.mkForce "Source Sans 3 Semibold";
  omarchy.fonts.swayosd = lib.mkForce "sans";
  omarchy.fonts.mako = lib.mkForce "sans";
  omarchy.fonts.rofi = lib.mkForce "sans";
  omarchy.fonts.kitty = lib.mkForce "CaskaydiaCove Nerd Font";

  omarchy.rotate_on_start = lib.mkForce false;

  gtk.iconTheme = {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme;
  };

  gtk.colorScheme = "dark";

  gtk.gtk4.extraConfig."gtk-interface-color-scheme" = "dark";

  gtk.theme = lib.mkForce {
    name = "Materia-dark-compact";
    package = pkgs.materia-theme;
  };

  xdg.configFile."gtk-3.0/gtk.css".text = ''
    /* Remove CSD decoration margin to eliminate transparent gap between
       Hyprland border and window content on floating GTK dialogs. */
    window decoration {
      margin: 0;
      border: 0;
    }
  '';

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style.name = "adwaita-dark";
  };

  wayland.windowManager.hyprland.settings.bind = [
    "SUPER CTRL, D, exec, wayvncctl output-cycle"
    "SUPER CTRL, R, exec, pkill -USR2 Hyprland"
  ];

  wayland.windowManager.hyprland.settings."$browser" =
    lib.mkForce "~/.local/share/omarchy/bin/omarchy-launch-or-focus microsoft-edge 'microsoft-edge-stable --new-window'";
  wayland.windowManager.hyprland.settings."$webapp" =
    lib.mkForce "~/.local/share/omarchy/bin/omarchy-launch-or-focus microsoft-edge 'microsoft-edge-stable --app'";

  xdg.mimeApps.defaultApplications = lib.mkForce {
    "text/html" = "microsoft-edge.desktop";
    "text/xml" = "microsoft-edge.desktop";
    "x-scheme-handler/http" = "microsoft-edge.desktop";
    "x-scheme-handler/https" = "microsoft-edge.desktop";
    "x-scheme-handler/ftp" = "microsoft-edge.desktop";
    "application/xhtml+xml" = "microsoft-edge.desktop";
    "image/png" = "org.gnome.Loupe.desktop";
    "image/jpeg" = "org.gnome.Loupe.desktop";
    "image/jpg" = "org.gnome.Loupe.desktop";
    "image/gif" = "org.gnome.Loupe.desktop";
    "image/webp" = "org.gnome.Loupe.desktop";
    "image/bmp" = "org.gnome.Loupe.desktop";
    "image/tiff" = "org.gnome.Loupe.desktop";
  };

  home.activation.copyScreensaverTxt = lib.mkForce (
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ ! -f "$HOME/.config/omarchy/branding/screensaver.txt" ]; then
        mkdir -p "$HOME/.config/omarchy/branding"
        cp "$HOME/.local/share/omarchy/logo.txt" "$HOME/.config/omarchy/branding/screensaver.txt"
      fi
    ''
  );

  xdg.configFile."teams-for-linux/config.json".text = builtins.toJSON {
    disableGpu = false;
    electronCLIFlags = [
      [
        "enable-features"
        "WebRTCPipeWireCapturer,WebRtcPipeWireCamera"
      ]
      [
        "disable-features"
        "HardwareMediaKeyHandling"
      ]
    ];
    notificationMethod = "electron";
    followSystemTheme = true;
    screenSharing.thumbnail.enabled = false;
    auth.keepMsalCacheEncryptionCookie.enabled = true;
  };
}
