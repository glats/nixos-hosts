{ inputs }:

let
  baseModules = import ../../../linux/home/shared-modules.nix { inherit inputs; };
in
baseModules
++ [
  ../../../linux/home/remote-desktop.nix

  ../../../linux/home/suites/mate/default.nix
  ../../../linux/home/conky-thinkcentre.nix
  ../../../linux/home/shell-gpt.nix
  { home.shell-gpt.enable = false; }
]
