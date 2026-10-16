{ inputs }:

let
  baseModules = import ../../../linux/home/shared-modules.nix { inherit inputs; };
in
baseModules
++ [
  ../../../linux/home/remote-desktop.nix

  ../../../linux/home/conky-thinkcentre.nix
  { home.opencode.activeProviderName = "anthropic-openai-opencode"; }
  ({ lib, ... }: {
    qt.enable = lib.mkForce false;
    # KConfig settings remain opt-in; SonicDE manages Qt appearance.
    qt.kde.settings = { };
  })
]
