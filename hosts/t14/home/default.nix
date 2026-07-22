# T14-specific Home Manager overlays on top of omarchy-nix.
# Omarchy's theme runtime owns the visual layer (waybar theme, mako theme,
# ghostty theme).  This module adds only the non-visual delta:
#   - Hyprland t14-specific config fragments (monitor, input, bindings, looknfeel)
#   - Helper scripts (kb-toggle, kb-layout)
#   - Ghostty + kitty settings (imported directly from linux/home/ because
#     t14's curated import list omits linux/home/shared-modules.nix)
#   - mouse-wiggle launcher
{ config
, lib
, pkgs
, ...
}:

{
  imports = [
    ./hypr/monitors.nix
    ./hypr/input.nix
    ./hypr/looknfeel.nix
    ./hypr/hyprlock.nix
    ./hypr/hyprsunset.nix
    ../../../linux/home/ghostty.nix
    ../../../linux/home/superfile.nix
    ../../../linux/home/kitty.nix
    ./mouse-wiggle.nix
    ../../../linux/home/webcam-rog.nix
  ];

  # ------------------------------------------------------------------
  # Helper scripts (deployed to ~/.local/bin via home.file, accessible
  # from PATH via home.sessionPath in base.nix)
  # ------------------------------------------------------------------

  # HyprDynamicMonitors — event-driven monitor profile daemon.
  # Detects lid state via UPower D-Bus and monitor hotplug via
  # native Hyprland IPC. Profiles + hyprconfigs deployed from ./hdm/.
  home.hyprdynamicmonitors = {
    enable = lib.mkDefault true;
    configFile = ../hdm/config.toml;
    extraFiles = {
      "hyprdynamicmonitors/hyprconfigs/docked-lid-open.conf" = ../hdm/hyprconfigs/docked-lid-open.conf;
      "hyprdynamicmonitors/hyprconfigs/docked-lid-closed.conf" = ../hdm/hyprconfigs/docked-lid-closed.conf;
      "hyprdynamicmonitors/hyprconfigs/undocked-lid-open.conf" = ../hdm/hyprconfigs/undocked-lid-open.conf;
      "hyprdynamicmonitors/hyprconfigs/undocked-lid-closed.conf" = ../hdm/hyprconfigs/undocked-lid-closed.conf;
      "hyprdynamicmonitors/hyprconfigs/fallback.conf" = ../hdm/hyprconfigs/fallback.conf;
    };
    extraFlags = [ "--enable-lid-events" ];
    installExamples = false;
  };

  # Waybar systemd user service.
  # omarchy-nix's waybar HM module installs only the package + static config
  # files -- it does NOT ship a systemd unit -- so this is the sole service
  # definition and cannot be removed.  Restart=always + a short RestartSec
  # recover waybar quickly when it crashes on monitor hotplug (a known
  # Hyprland multi-monitor race).  The previous StartLimitBurst=20 in 5s was
  # overly permissive (would hammer-restart 20 times); 5 in 10s still recovers
  # fast but gives systemd a sane back-off before the unit is stopped.
  systemd.user.services.waybar = {
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
    # Keyboard layout toggle (es <-> latam)
    ".local/share/omarchy/bin/kb-toggle.sh" = {
      source = ./scripts/kb-toggle.sh;
      executable = true;
    };

    # Keyboard layout set (es or latam)
    ".local/share/omarchy/bin/kb-layout.sh" = {
      source = ./scripts/kb-layout.sh;
      executable = true;
    };

    # ------------------------------------------------------------------
    # kb-layout.sh / kb-toggle.sh — the symlink copies into
    # ~/.config/hypr/ are kept for any waybar module / hyprland plugin
    # that resolves helper scripts at that path.  The canonical
    # source lives in scripts/; the bin copies above expose them on
    # PATH.  Both paths point to the same source file (no duplicate
    # content).
    # ------------------------------------------------------------------
    ".config/hypr/kb-layout.sh" = {
      source = ./scripts/kb-layout.sh;
      executable = true;
    };
    ".config/hypr/kb-toggle.sh" = {
      source = ./scripts/kb-toggle.sh;
      executable = true;
    };
  };
}
