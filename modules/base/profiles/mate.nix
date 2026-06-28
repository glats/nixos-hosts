# MATE desktop suite profile.
# Selected by: my.desktop.suite = "mate";
# Provides: MATE DE + X11/MATE apps + materia theme + CLI extras
# (cli-extra tools that omarchy-nix would have provided on t14, but
# MATE hosts do not run omarchy).
{ pkgs }:
(import ./cli-extra.nix { inherit pkgs; })
++ (with pkgs; [
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

  # X11 tools (MATE session only)
  scrot
  xclip
  flameshot
  copyq
  gpaste
  conky
  gtk-engine-murrine
  hexchat
])
