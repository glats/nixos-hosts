{ inputs }:

let
  baseModules = import ../../../linux/home/shared-modules.nix { inherit inputs; };
in
baseModules
++ [
  ../../../linux/home/remote-desktop.nix

  ../../../linux/home/suites/mate/default.nix
  ../../../linux/home/suites/mate-rog/default.nix
  ../../../linux/home/conky-rog.nix
  ../../../linux/home/openfang.nix
  ../../../linux/home/webcam.nix
  ../../../linux/home/shell-gpt.nix
  { home.shell-gpt.enable = true; }

  # Override active OpenCode provider for this host
  { home.opencode.activeProviderName = "opencode-go-medium"; }
]
