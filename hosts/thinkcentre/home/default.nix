{ inputs }:

let
  baseModules = import ../../../linux/home/shared-modules.nix { inherit inputs; };
in
baseModules
++ [
  ../../../linux/home/remote-desktop.nix

  ../../../linux/home/conky.nix
  ../../../linux/home/suites/sonicde
  { home.opencode.activeProviderName = "anthropic-openai-ollama"; }
  ({ lib, ... }: {
    qt.enable = lib.mkForce false;
  })
]
