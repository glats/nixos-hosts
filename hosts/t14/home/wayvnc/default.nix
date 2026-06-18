# wayvnc configuration — VNC server for wlroots-based Wayland compositors.
# wayvnc captures the actual screen via wlroots screencopy protocol.
# Auth uses PAM (unix password) as configured by programs.wayvnc.enable.
#
# Run as a systemd user service (not exec-once) so it:
#   - starts after the graphical session is ready (gets Wayland env)
#   - survives Hyprland restarts
#   - restarts automatically on failure
#   - is inspectable via `systemctl --user status wayvnc`
{ pkgs, ... }:

{
  xdg.configFile."wayvnc/config".source = ./config;

  # Systemd user service for wayvnc.
  systemd.user.services.wayvnc = {
    Unit = {
      Description = "wayvnc VNC server for Wayland";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.wayvnc}/bin/wayvnc";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
