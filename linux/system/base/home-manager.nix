{
  config,
  inputs,
  ...
}:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs;
      hostName = config.networking.hostName;
      conkyConfig = config.conky-config;
      username = "glats";
    };
    users.glats.imports = import ../../../hosts/${config.networking.hostName}/home/default.nix {
      inherit inputs;
    };
  };
}
