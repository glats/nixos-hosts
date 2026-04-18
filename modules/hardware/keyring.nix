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

  # Environment variables so apps can find the keyring
  environment.sessionVariables = {
    SSH_AUTH_SOCK = "/run/user/1000/keyring/ssh";
  };
}
