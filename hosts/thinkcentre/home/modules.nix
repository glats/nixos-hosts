{ inputs }:

let
  baseModules = import ../../../home-linux/shared-modules.nix { inherit inputs; };
in
baseModules
++ [
  ../../../home-linux/remote-desktop.nix
  ../../../home-linux/picom-x11.nix
  ../../../home-linux/conky-thinkcentre.nix
]
