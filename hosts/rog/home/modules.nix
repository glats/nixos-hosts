{ inputs }:

let
  baseModules = import ../../../home-linux/shared-modules.nix { inherit inputs; };
in
baseModules
++ [
  ../../../home-linux/remote-desktop.nix
  ../../../home-linux/picom.nix
  ../../../home-linux/mate-rog-autostart.nix
  ../../../home-linux/conky-rog.nix
  ../../../home-linux/openfang.nix
  ../../../home-linux/webcam-rog.nix
  ../../../home-linux/shell-gpt.nix

  # Override active OpenCode provider for this host
  #{ home.opencode.activeProviderName = "nvidia"; }

  { home.shell-gpt.enable = true; }
]
