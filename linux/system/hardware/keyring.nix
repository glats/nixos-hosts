{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gnome-keyring
    libsecret
  ];

  services.gnome.gnome-keyring.enable = true;

  security.pam.services.lightdm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.xrdp-sesman.enableGnomeKeyring = true;
  security.pam.services.sshd.enableGnomeKeyring = true;

}
