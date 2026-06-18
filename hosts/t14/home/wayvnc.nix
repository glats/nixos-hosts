# wayvnc configuration — VNC server for wlroots-based Wayland compositors.
# wayvnc captures the actual screen via wlroots screencopy protocol.
# Auth uses PAM (unix password) as configured by programs.wayvnc.enable.
{ ... }:

{
  xdg.configFile."wayvnc/config".text = ''
    use_relative_paths=true
    address=0.0.0.0
    port=5900
    enable_pam=true
  '';
}
