{ inputs }:

let
  baseModules = import ../../../home-linux/shared-modules.nix { inherit inputs; };
in
baseModules
++ [
  ../../../home-linux/remote-desktop.nix
  ../../../home-linux/picom.nix
  ../../../home-linux/conky-thinkcentre.nix
  ../../../home-linux/shell-gpt.nix

  # Uncomment to enable shell-gpt (nvidia NIM nemotron-3-ultra)
  #{ home.shell-gpt.enable = true; }
]
