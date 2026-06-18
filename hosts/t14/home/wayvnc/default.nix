# wayvnc configuration — VNC server for wlroots-based Wayland compositors.
# wayvnc captures the actual screen via wlroots screencopy protocol.
# Auth uses PAM (unix password) as configured by programs.wayvnc.enable.
{ ... }:

{
  xdg.configFile."wayvnc/config".source = ./config;
}
