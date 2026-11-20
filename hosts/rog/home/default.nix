{ inputs }:

let
  baseModules = import ../../../linux/home/shared-modules.nix { inherit inputs; };
in
baseModules
++ [
  ../../../linux/home/remote-desktop.nix

  ../../../linux/home/suites/mate/default.nix
  ../../../linux/home/suites/mate-rog/default.nix
  ../../../linux/home/conky.nix
  ../../../linux/home/openfang.nix
  ../../../linux/home/gastown-campaigns.nix
  ../../../linux/home/webcam.nix

  {
    home.opencode.activeProviderName = "personal";
    home.opencode.compactionBuffer = "80%";
    home.gastown.campaigns.maquilinux = { };
    home.ghostty.xrdp-optimized = true;
  }

  ({ config, ... }: {
    home.file."Guacamole".source = config.lib.file.mkOutOfStoreSymlink "/srv/glats/guacamole/drive";
  })
]
