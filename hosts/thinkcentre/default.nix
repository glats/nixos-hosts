{ config
, pkgs
, lib
, ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix
    ./conky-config.nix

    # Base system (all 14)
    ../../linux/system/base/cachix.nix
    ../../linux/system/base/nix.nix
    ../../linux/system/base/users.nix
    ../../linux/system/base/zsh.nix
    ../../linux/system/base/sops.nix
    ../../linux/system/base/polkit.nix
    ../../linux/system/base/logind.nix
    ../../linux/system/base/nh.nix
    ../../linux/system/base/dconf.nix
    ../../linux/system/base/options.nix
    ../../linux/system/base/packages.nix
    ../../linux/system/base/home-manager.nix
    ../../linux/system/base/shutdown-fix.nix

    # Desktop (all 3)
    ../../linux/system/desktop/fonts.nix
    ../../linux/system/desktop/i18n.nix
    ../../linux/system/desktop/kmscon.nix

    # Hardware (keyring only)
    ../../linux/system/hardware/keyring.nix
    ../../linux/system/hardware/adb.nix

    # Networking (all 4)
    ../../linux/system/networking/openssh.nix
    ../../linux/system/networking/firewall.nix
    ../../linux/system/networking/avahi.nix
    ../../linux/system/networking/wol.nix

    # Features
    ../../linux/system/features/boot.nix
    ../../linux/system/features/conky/options.nix

    # Services
    ../../linux/system/services/xrdp.nix
    ../../linux/system/services/maquilinux-mounts.nix

    # Virtualisation
    ../../linux/system/virtualisation/docker.nix
  ];

  boot-settings = {
    enable = true;
    includeAcpiOsi = false;
  };

  boot.kernelPackages = pkgs.linuxPackages;

  # Desktop suite — thinkcentre uses MATE via XRDP
  my.desktop.suite = "mate";

  zramSwap.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePackages = [ "joypixels" ];
    joypixels.acceptLicense = true;
  };

  networking = {
    hostName = "thinkcentre";
    networkmanager.enable = true;
  };

  services.wol-custom.interface = "enp0s31f6";

  system.stateVersion = "25.05";

  environment.systemPackages = with pkgs; [
    microsoft-edge
    pipewire-module-xrdp
    intel-vaapi-driver
    libva-vdpau-driver
  ];

}
