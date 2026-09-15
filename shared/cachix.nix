{ lib, ... }:

{
  nix.settings = lib.mapAttrs (_: value: lib.mkAfter value) (import ./cachix-settings.nix);
}
