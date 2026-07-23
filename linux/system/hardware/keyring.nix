{ pkgs, ... }:

{
  # Install gnome-keyring
  environment.systemPackages = with pkgs; [
    gnome-keyring
    libsecret
  ];

  # Enable gnome-keyring service
  services.gnome.gnome-keyring.enable = true;

  # Configure PAM to unlock keyring automatically on login.
  # Each service below corresponds to a display manager or session entry
  # point used across hosts.  greetd is NOT here — it is configured by
  # omarchy-nix (greetd is an omarchy dependency, not a host-level one).
  security.pam.services.lightdm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.xrdp-sesman.enableGnomeKeyring = true;
  security.pam.services.sshd.enableGnomeKeyring = true;

}
