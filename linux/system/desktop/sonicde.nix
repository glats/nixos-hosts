{ inputs, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  sonicPackages = inputs.sonic-de.packages.${system};
in
{
  imports = [ "${inputs.sonic-de}/sonic-de.nix" ];

  _module.args.sonic-de = inputs.sonic-de // {
    packages = inputs.sonic-de.packages // {
      ${system} = sonicPackages // {
        sonic-win = sonicPackages.sonic-win.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./patches/sonic-win-unwrap-serviceutils.patch ];
        });
      };
    };
  };
  services.desktopManager.sonic-de.enable = true;
  services.xserver.enable = true;
  services.xserver.updateDbusEnvironment = true;

  environment.sonic-de.excludePackages = [
    inputs.sonic-de.packages.${pkgs.stdenv.hostPlatform.system}.sonic-workspace-wallpapers
  ];
}
