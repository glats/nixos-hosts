{
  config,
  pkgs,
  lib,
  home,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix
    ./conky-config.nix

    ../../linux/system/base/cachix.nix
    ../../linux/system/base/nix-cache-client.nix
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
    ../../linux/system/base/shutdown-debug.nix

    ../../linux/system/security/ca-blacklist.nix

    ../../linux/system/desktop/fonts.nix
    ../../linux/system/desktop/i18n.nix
    ../../linux/system/desktop/kmscon.nix

    ../../linux/system/hardware/nvidia-custom.nix
    ../../linux/system/hardware/keyring.nix
    ../../linux/system/hardware/asus-fan-control.nix
    ../../linux/system/hardware/rog-poweroff.nix
    ../../linux/system/hardware/adb.nix

    ../../linux/system/networking/openssh.nix
    ../../linux/system/networking/firewall.nix
    ../../linux/system/networking/avahi.nix
    ../../linux/system/networking/wol.nix

    ../../linux/system/features/boot.nix
    ../../linux/system/features/conky/options.nix

    ../../linux/system/services/xrdp.nix
    ../../linux/system/services/printing/brother.nix

    ../../linux/system/services/media/arr-stack.nix
    ../../linux/system/services/media/jellyfin.nix
    ../../linux/system/services/media/qbittorrent.nix
    ../../linux/system/services/media/flaresolverr.nix
    ../../linux/system/services/media/romm.nix

    ../../linux/system/services/web/nginx.nix
    ../../linux/system/services/web/authelia.nix
    ../../linux/system/services/web/seerr.nix
    ../../linux/system/services/web/dozzle.nix
    ../../linux/system/services/web/fileshelter.nix
    ../../linux/system/services/web/code-server.nix
    ../../linux/system/services/web/wetty.nix
    ../../linux/system/services/web/cobalt.nix
    ../../linux/system/services/web/droppy.nix

    ../../linux/system/services/network/wireguard.nix
    ../../linux/system/services/network/sing-box-link.nix
    ../../linux/system/services/network/ddclient.nix
    ../../linux/system/networking/cloudflare-cli.nix
    ../../linux/system/services/network/samba.nix
    ../../linux/system/services/network/ftp.nix
    ../../linux/system/services/network/guacamole.nix
    ../../linux/system/services/network/gonic.nix
    ../../linux/system/services/network/ollama.nix
    ../../linux/system/services/network/ssh-relay.nix

    ../../linux/system/virtualisation/libvirt.nix
    ../../linux/system/virtualisation/docker.nix

    ./systemd-timeouts.nix
  ];

  boot-settings = {
    enable = true;
    includeDiagLogging = true;
  };

  my.shutdownDebug.enable = true;

  my.shutdownDebug.efiPstore = true;

  hardware.rog.s5-recovery.diagnostics.enable = true;
  hardware.rog.s5-recovery.s5Write.enable = false;

  hardware.rog.s5-recovery.efiFallback.enable = true;

  boot.blacklistedKernelModules = [
    "asus_nb_wmi"
    "asus_armoury"
  ];

  my.desktop.suite = "mate";

  boot = {
    kernelPackages = pkgs.linuxPackages_7_1;
    extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];
    kernelModules = [ "acpi_call" ];
  };

  zramSwap.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [ ];
    allowUnfreePackages = [ "joypixels" ];
    joypixels.acceptLicense = true;
  };

  networking = {
    hostName = "rog";
    networkmanager.enable = true;
  };

  services.avahi.allowInterfaces = [ "enp3s0" ];

  services.wol-custom.interface = "enp3s0";

  fileSystems."/run/media/library" = {
    device = "/dev/disk/by-uuid/608cd7cf-3cb4-4589-8f36-c558fb4e32a3";
    fsType = "ext4";
    options = [ "defaults" ];
  };

  fileSystems."/run/media/stuff" = {
    device = "/dev/disk/by-uuid/ec889a15-ee5a-4b41-b3a0-60b16257026a";
    fsType = "xfs";
    options = [
      "rw"
      "relatime"
      "attr2"
      "inode64"
      "logbufs=8"
      "logbsize=32k"
      "noquota"
    ];
  };

  fileSystems."/run/media/archlinux" = {
    device = "/dev/disk/by-uuid/3188527d-b895-460a-b754-c396b876d8bf";
    fsType = "xfs";
    options = [
      "rw"
      "relatime"
      "attr2"
      "inode64"
      "logbufs=8"
      "logbsize=32k"
      "noquota"
    ];
  };

  system.stateVersion = "25.05";

  services.sing-box-link.enable = true;

  services.ssh-relay = {
    enable = true;
    restrictionsFile = "/var/lib/ssh-relay/restrictions.yaml";
  };

  systemd.services.nginx.serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."acme-glats.org".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-droppy".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-guacamoledb".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-jellyfin".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-jellyseerr".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-romm-db".serviceConfig.TimeoutStartSec = lib.mkForce "300";

  systemd.services.nginx.startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-droppy".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-jellyfin".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-guacamoledb".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-jellyseerr".startLimitIntervalSec = lib.mkForce 0;

  environment.systemPackages = with pkgs; [
    microsoft-edge
    asus-fan-control
    pipewire-module-xrdp
    intel-vaapi-driver
    libva-vdpau-driver
    qrencode
  ];
}
