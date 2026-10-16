{ inputs }:

let
  baseModules = import ../../../linux/home/shared-modules.nix { inherit inputs; };
in
baseModules
++ [
  ../../../linux/home/remote-desktop.nix

  ../../../linux/home/conky-rog.nix
  ../../../linux/home/openfang.nix
  ../../../linux/home/webcam.nix

  # Override active OpenCode provider for this host
  (
    { lib, ... }:
    {
      home.opencode.activeProviderName = "anthropic-openai-opencode";

      # Let SonicDE manage Qt appearance instead of the shared GTK override.
      qt.enable = lib.mkForce false;
      # KConfig is SonicDE's equivalent of dconf; add file/group/key values here.
      qt.kde.settings = { };
    }
  )
]
