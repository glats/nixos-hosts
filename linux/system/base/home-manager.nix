{ config
, inputs
, ...
}:

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
    };
    users.glats.imports = import ../../../hosts/${config.networking.hostName}/home/default.nix {
      inherit inputs;
    };
  };
}
