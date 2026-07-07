# Darwin GPG configuration -- imports shared key logic, sets darwin-specific packages.
{ pkgs, ... }:
{
  imports = [ ../shared/gpg.nix ];

  home.packages = with pkgs; [
    gnupg
    pinentry_mac
    nix-index
  ];
}
