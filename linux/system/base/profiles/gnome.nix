# GNOME desktop suite profile.
# Selected by: my.desktop.suite = "gnome";
# Provides: GNOME apps not already supplied by omarchy-nix.
# omarchy-nix baseline (already on t14 via flake input):
#   nautilus, gnome-calculator, evince, loupe, sushi, pavucontrol,
#   blueman, gnome-themes-extra, gnome-keyring, ffmpegthumbnailer
{ pkgs }:
with pkgs;
[
  gnome-system-monitor
]
