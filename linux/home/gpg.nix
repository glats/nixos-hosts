{ pkgs, ... }:
{
  imports = [ ../../shared/gpg.nix ];

  home.packages = with pkgs; [
    gnupg
    pinentry-qt
  ];
}
