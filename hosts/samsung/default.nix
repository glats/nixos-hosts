{
  lib,
  pkgs,
  ...
}:

let
  cache = import ../../shared/nix-cache.nix;
  lanCache = "${cache.lanUrl}?priority=30";
in

{
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix
    ./desktop.nix

    ../../linux/system/base/cachix.nix
    ../../linux/system/base/users.nix
    ../../linux/system/base/zsh.nix
    ../../linux/system/base/sops.nix
    ../../linux/system/base/polkit.nix
    ../../linux/system/base/dconf.nix
    ../../linux/system/base/options.nix
    ../../linux/system/base/packages.nix
    ../../linux/system/base/home-manager.nix

    ../../linux/system/security/ca-blacklist.nix

    ../../linux/system/desktop/fonts.nix
    ../../linux/system/desktop/i18n.nix

    ../../linux/system/hardware/keyring.nix

    ../../linux/system/networking/openssh.nix
    ../../linux/system/networking/firewall.nix
    ../../linux/system/networking/avahi.nix

    ../../linux/system/services/xrdp.nix

    ../../linux/system/features/boot.nix
    ../../linux/system/features/conky/options.nix
  ];

  networking = {
    hostName = "samsung";
    networkmanager.enable = true;
  };

  boot-settings.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.systemd.enable = true;
  boot.kernelParams = [
    "acpi_backlight=video"
    "i915.enable_guc=3"
  ];

  my.desktop.suite = "mate";

  zramSwap.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePackages = [ "joypixels" ];
    joypixels.acceptLicense = true;
  };

  nix = {
    settings = (import ../../shared/nix-resilience.nix) // {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [ "glats" ];
      substituters = lib.mkBefore [ lanCache ];
      trusted-substituters = [ lanCache ];
      trusted-public-keys = [
        cache.ncps.publicKey
        cache.harmonia.publicKey
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  system.stateVersion = "25.11";

  environment.systemPackages = [ pkgs.nixos-scripts ];
}
