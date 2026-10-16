{ pkgs }:
(import ./cli-extra.nix { inherit pkgs; })
++ (with pkgs; [
  atril
  caja
  engrampa
  eom
  librsvg
  marco
  pluma
  mate-panel
  mate-sensors-applet
  mate-user-share

  materia-theme

  scrot
  xclip
  flameshot
  copyq
  gpaste
  conky
  gtk-engine-murrine
  hexchat
  networkmanagerapplet
  gdk-pixbuf
])
