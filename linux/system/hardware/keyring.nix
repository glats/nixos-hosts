{ pkgs, ... }:

{
  # Install gnome-keyring
  environment.systemPackages = with pkgs; [
    gnome-keyring
    libsecret
  ];

  # Enable gnome-keyring service
  services.gnome.gnome-keyring.enable = true;

  # Configure PAM to unlock keyring automatically on login
  security.pam.services.lightdm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.xrdp-sesman.enableGnomeKeyring = true;
  security.pam.services.sshd.enableGnomeKeyring = true;

}
