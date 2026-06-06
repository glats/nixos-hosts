{ lib, pkgs, ... }:

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
    ../../modules/base/users.nix
    ../../modules/base/zsh.nix

    # Hardware
    ../../modules/hardware/amd-laptop.nix

    # Desktop
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/i18n.nix
    ../../modules/desktop/kmscon.nix

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

  # Minimal T14 - just a TTY terminal
  # No display manager, no Hyprland, no Omarchy

  home-manager.users.glats = {
    imports = [
      ./home/minimal.nix
    ];
  };

  system.stateVersion = "25.05";
}
