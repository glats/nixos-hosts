{ pkgs, ... }:

{
  imports = [
    ../../../shared/cachix.nix
  ];

  environment.systemPackages = with pkgs; [ cachix ];
}
