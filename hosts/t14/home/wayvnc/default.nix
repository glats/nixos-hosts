# wayvnc configuration — VNC server for wlroots-based Wayland compositors.
# wayvnc captures the actual screen via wlroots screencopy protocol.
#
# Auth uses VeNCrypt + PAM (enable_pam=true) for secure connections.
# Clients (e.g. TigerVNC's vncviewer on macOS) negotiate TLS with
# username/password over the encrypted channel; wayvnc validates the
# credentials against the host's PAM stack. macOS Screen Sharing.app
# does NOT support VeNCrypt — use TigerVNC on the Mac side.
#
# Run as a systemd user service (not exec-once) so it:
#   - starts after the graphical session is ready (gets Wayland env)
#   - survives Hyprland restarts
#   - restarts automatically on failure
#   - is inspectable via `systemctl --user status wayvnc`
{ pkgs, ... }:

{
  # Config file generated declaratively by Nix.
  # wayvnc reads this at startup (default location: ~/.config/wayvnc/config).
  xdg.configFile."wayvnc/config".text = ''
    use_relative_paths=true
    address=0.0.0.0
    port=5900
    enable_pam=true
  '';

  # Systemd user service for wayvnc.
  # Passes Wayland env vars so wayvnc can attach to the compositor.
  systemd.user.services.wayvnc = {
    Unit = {
      Description = "wayvnc VNC server for Wayland";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      PassEnvironment = [
        "WAYLAND_DISPLAY"
        "XDG_RUNTIME_DIR"
        "DISPLAY"
      ];
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'pkill wayvnc 2>/dev/null || true'";
      ExecStart = "${pkgs.wayvnc}/bin/wayvnc";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
