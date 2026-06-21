{ config
, lib
, pkgs
, inputs
, ...
}:

let
  # Canonical base list of shared Home Manager modules (see
  # home-linux/shared-modules.nix). flake.nix uses the same list to keep
  # NixOS-integrated and standalone home-manager setups in sync.
  baseModules = import ../../home-linux/shared-modules.nix { inherit inputs; };
in

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # Pre-existing unmanaged files block HM's symlink activation with
    # "would be clobbered" errors. Rename colliding files to <path>.backup.
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs;
      hostName = config.networking.hostName;
      conkyConfig = config.conky-config;
      # Pass the active login user so parameterized modules
      # (e.g. home-linux/base.nix) can derive home.username and
      # home.homeDirectory without hardcoding the name.
      username = "glats";
      # Force rebuild: 2026-05-03
    };
    users.glats.imports =
      baseModules
      ++ [
        ../../home-linux/remote-desktop.nix
      ]
      ++ lib.optionals (config.networking.hostName == "rog") [
        ../../home-linux/conky-rog.nix
        ../../home-linux/openfang.nix
      ]
      ++ lib.optionals (config.networking.hostName == "thinkcentre") [
        ../../home-linux/conky-thinkcentre.nix
      ];
  };
}
