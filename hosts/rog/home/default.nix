{ inputs }:

let
  baseModules = import ../../../linux/home/shared-modules.nix { inherit inputs; };
in
baseModules
++ [
  ../../../linux/home/remote-desktop.nix

  ../../../linux/home/mate-rog-autostart.nix
  ../../../linux/home/conky-rog.nix
  ../../../linux/home/openfang.nix
  ../../../linux/home/webcam-rog.nix
  ../../../linux/home/shell-gpt.nix

  # Override active OpenCode provider for this host
  { home.opencode.activeProviderName = "opencode-go-medium"; }

  { home.shell-gpt.enable = true; }
]
