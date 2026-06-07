{
  config,
  lib,
  pkgs,
  ...
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
  environment.systemPackages = basePkgs ++ devPkgs ++ mediaPkgs ++ virtPkgs ++ browserPkgs;
}
