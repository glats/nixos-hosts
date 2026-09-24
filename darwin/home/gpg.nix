# Darwin GPG configuration -- imports shared key logic, sets darwin-specific packages.
{ pkgs, ... }:
{
  imports = [ ../../shared/gpg.nix ];

  home.packages = with pkgs; [
    gnupg
    pinentry_mac
    nix-index
  ];

  # git invokes gpg non-interactively; gpg-agent needs an explicit pinentry
  # program on darwin or signing fails with "Inappropriate ioctl for device".
  home.file.".gnupg/gpg-agent.conf".text = ''
    pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac
  '';
}
