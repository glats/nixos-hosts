{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix
    ./conky-config.nix

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

    ../../linux/system/desktop/fonts.nix
    ../../linux/system/desktop/i18n.nix
    ../../linux/system/desktop/kmscon.nix
    ../../linux/system/desktop/sonicde.nix

    ../../linux/system/hardware/keyring.nix
    ../../linux/system/hardware/adb.nix

    ../../linux/system/networking/openssh.nix
    ../../linux/system/networking/firewall.nix
    ../../linux/system/networking/avahi.nix
    ../../linux/system/networking/wol.nix

    ../../linux/system/features/boot.nix
    ../../linux/system/features/conky/options.nix

    ../../linux/system/services/maquilinux-mounts.nix

    ../../linux/system/services/nix/nix-cache.nix

    ../../linux/system/virtualisation/docker.nix
  ];

  boot-settings = {
    enable = true;
  };

  boot.kernelPackages = pkgs.linuxPackages;

  my.desktop.suite = null;
  services.displayManager.sddm.enable = false;
  services.xserver.displayManager.lightdm.enable = false;
  services.xrdp = {
    enable = true;
    defaultWindowManager = "${
      inputs.sonic-de.packages.${pkgs.stdenv.hostPlatform.system}.sonic-workspace
    }/bin/startplasma-x11";
  };

  zramSwap.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePackages = [ "joypixels" ];
    joypixels.acceptLicense = true;
  };

  networking = {
    hostName = "thinkcentre";
    networkmanager.enable = true;

    networkmanager.settings.main.no-auto-default = "enp0s31f6";

    networkmanager.ensureProfiles.profiles.enp0s31f6-static = {
      connection = {
        id = "enp0s31f6-static";
        type = "ethernet";
        interface-name = "enp0s31f6";
        autoconnect = true;
        autoconnect-priority = 100;
      };
      ipv4 = {
        method = "manual";
        addresses = "172.16.0.11/24";
        gateway = "172.16.0.1";
        dns = "172.16.0.1";
        dns-search = "lan";
      };
    };
  };

  systemd.services.netconsole-log = {
    description = "Netconsole UDP kernel log receiver";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.nixos-scripts}/bin/netconsole-log";
      DynamicUser = true;
      LogsDirectory = "netconsole";
      ReadWritePaths = [ "/var/log/netconsole" ];
      Restart = "always";
      RestartSec = "2s";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };

  services.logrotate.settings.netconsole = {
    files = [ "/var/log/netconsole/*.log" ];
    frequency = "weekly";
    rotate = 8;
    compress = true;
  };

  services.wol-custom.interface = "enp0s31f6";

  system.stateVersion = "25.05";

  environment.systemPackages =
    (import ../../linux/system/base/profiles/cli-extra.nix { inherit pkgs; })
    ++ (with pkgs; [
      microsoft-edge
      nixos-scripts
      pipewire-module-xrdp
      intel-vaapi-driver
      libva-vdpau-driver
    ]);

}
