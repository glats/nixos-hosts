# MATE desktop suite profile.
# Selected by: my.desktop.suite = "mate";
# Provides: MATE DE packages + materia theme (consumed by home-linux/theme.nix).
{ pkgs }:
with pkgs;
[
  # MATE desktop
  atril
  caja
  engrampa
  eom
  marco
  pluma
  mate-panel
  mate-sensors-applet
  mate-user-share

  # Theme (consumed by home-linux/theme.nix on MATE hosts)
  materia-theme
]
