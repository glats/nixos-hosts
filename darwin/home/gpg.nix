{ pkgs, ... }:
{
  imports = [ ../../shared/gpg.nix ];

  home.packages = with pkgs; [
    gnupg
    pinentry_mac
    nix-index
  ];

  home.file.".gnupg/gpg-agent.conf".text = ''
    pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac
  '';
}
