{ inputs }:

let
  baseModules = import ../../../linux/home/shared-modules.nix { inherit inputs; };
in
baseModules
++ [
  ../../../linux/home/remote-desktop.nix

  ../../../linux/home/conky-thinkcentre.nix
  ../../../linux/home/suites/sonicde
  { home.opencode.activeProviderName = "anthropic-openai-opencode"; }
  ({ lib, ... }: {
    qt.enable = lib.mkForce false;
  })
]
