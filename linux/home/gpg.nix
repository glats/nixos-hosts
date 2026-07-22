# Linux GPG configuration -- imports shared key logic, sets linux-specific packages.
{ pkgs, ... }:
{
  imports = [ ../../shared/gpg.nix ];

  home.packages = with pkgs; [
    gnupg
    pinentry-curses
  ];
}
