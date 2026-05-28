{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix

    # Base (transversal modules)
    ../../modules/base/cachix.nix
    ../../modules/base/home-manager.nix
    ../../modules/base/logind.nix
    ../../modules/base/nh.nix
    ../../modules/base/nix.nix
    ../../modules/base/packages.nix
    ../../modules/base/polkit.nix
    ../../modules/base/shutdown-fix.nix
    ../../modules/base/sops.nix
    ../../modules/base/users.nix
    ../../modules/base/zsh.nix

    # T14 secrets
    ./secrets.nix

    # Hardware
    ../../modules/hardware/amd-laptop.nix
    ../../modules/hardware/keyring.nix

    # Desktop
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/i18n.nix

    # Networking
    ../../modules/networking/avahi.nix
    ../../modules/networking/firewall.nix
    ../../modules/networking/openssh.nix

    # Boot shared config
    ../../modules/features/boot.nix
  ];

  boot-settings = {
    enable = true;
    includeAcpiOsi = false;
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePackages = [ "joypixels" ];
    joypixels.acceptLicense = true;
  };

  networking.hostName = "t14";

  omarchy = {
    username = "glats";
    full_name = "Glats";
    email_address = "glats@glats.org";
    theme = "tokyo-night";
    browser = "chromium";
    terminal = "ghostty";
    firewall.enable = false;
  };

  home-manager.users.glats = {
    imports = [
      ./home
    ];
    wayland.windowManager.hyprland.configType = "hyprlang";
    xdg.userDirs.setSessionVariables = true;
  };

  # Preserve the expected login stack for this host:
  # SDDM -> UWSM -> Hyprland.
  programs.uwsm.enable = true;
  programs.hyprland.withUWSM = lib.mkForce true;

  services.greetd.enable = lib.mkForce false;
  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
    defaultSession = "hyprland-uwsm";
  };
  services.xserver.enable = true;

  security.pam.services.sddm.enableGnomeKeyring = true;

  system.stateVersion = "25.05";
}
