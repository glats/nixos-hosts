{ inputs, pkgs, ... }:

{
  imports = [ "${inputs.sonic-de}/sonic-de.nix" ];

  _module.args.sonic-de = inputs.sonic-de;
  services.desktopManager.sonic-de.enable = true;
  services.xserver.enable = true;
  services.xserver.updateDbusEnvironment = true;

  environment.sonic-de.excludePackages = [
    inputs.sonic-de.packages.${pkgs.stdenv.hostPlatform.system}.sonic-workspace-wallpapers
  ];
}
