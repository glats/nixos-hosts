{ config
, lib
, pkgs
, ...
}:

let
  # Profile composition. Each profile is a function `{ pkgs }: [ ... ]` that
  # returns a flat list of packages. Hosts can opt-out of specific profiles
  # in their own configuration (out of scope for the current change).
  basePkgs = import ./profiles/base.nix { inherit pkgs; };
  devPkgs = import ./profiles/dev.nix { inherit pkgs; };
  mediaPkgs = import ./profiles/media.nix { inherit pkgs; };
  virtPkgs = import ./profiles/virt.nix { inherit pkgs; };
  browserPkgs = import ./profiles/browsers.nix { inherit pkgs; };
in
{
  # Import the my.* option declarations so every host that pulls in
  # packages.nix (rog, thinkcentre, t14) sees them — t14 does not go
  # through modules/profiles/base.nix and would otherwise miss the
  # my.desktop.suite option declared in modules/base/options.nix.
  imports = [ ./options.nix ];

  environment.systemPackages = basePkgs ++ devPkgs ++ mediaPkgs ++ virtPkgs ++ browserPkgs;
}
