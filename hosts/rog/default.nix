{
  config,
  pkgs,
  lib,
  ...
}:

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

    # Rog secrets
    ./secrets.nix

    # Rog conky config
    ./conky-config.nix

    # Conky module (options from features/conky)
    ../../modules/features/conky

    # Hardware (rog-specific)
    ../../modules/hardware/nvidia.nix
    ../../modules/hardware/rog-shutdown.nix
    ../../modules/hardware/asus-fan-control.nix
    ../../modules/hardware/keyring.nix

    # Desktop
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/i18n.nix
    ../../modules/desktop/kmscon.nix
    ../../modules/features/services/xrdp.nix
    ../../modules/features/services/github-mcp-server.nix

    # Services (rog-specific)
    ./services/arr-stack.nix
    ./services/authelia.nix
    ./services/cobalt.nix
    ./services/code-server.nix
    ./services/ddclient.nix
    ./services/dozzle.nix
    ./services/droppy.nix
    ./services/fileshelter.nix
    ./services/flaresolverr.nix
    ./services/ftp.nix
    ./services/gonic.nix
    ./services/guacamole.nix
    ./services/jellyfin.nix
    ./services/nginx.nix
    ./services/ollama.nix
    ./services/qbittorrent.nix
    ./services/samba.nix
    ./services/seerr.nix
    ./services/wetty.nix
    ./services/wireguard.nix

    # Virtualisation
    ../../modules/virtualisation/docker.nix
    ../../modules/virtualisation/libvirt.nix

    # Networking
    ../../modules/networking/avahi.nix
    ../../modules/networking/firewall.nix
    ../../modules/networking/openssh.nix
    ../../modules/networking/wol.nix

    # Boot shared config
    ../../modules/features/boot.nix
  ];

  boot-settings = {
    enable = true;
    includeAcpiOsi = true;
    includePoweroffFix = true;
  };

  boot = {
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

  # Fix 1: Extend timeouts to prevent exit status 4 in nixos-rebuild switch
  # See: investigation of intermittent systemd-run switch-to-configuration failures
  # Use mkForce to override the oci-containers module defaults
  systemd.services.nginx.serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."acme-glats.org".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-droppy".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-guacamoledb".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-jellyfin".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-jellyseerr".serviceConfig.TimeoutStartSec = lib.mkForce "300";

  # Prevent restart loops that consume time during switch
  # Use mkForce because nginx already defines this value
  systemd.services.nginx.startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-droppy".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-jellyfin".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-guacamoledb".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-jellyseerr".startLimitIntervalSec = lib.mkForce 0;

  # OpenCode LLM provider configuration is managed centrally in
  # shared/opencode/providers.nix (base providers)
  # home-darwin/opencode/providers-extra.nix (macOS extras)
  #
  # To change provider or model:
  # 1. Edit providers-base.nix to enable/disable providers or change models per phase
  # 2. Set activeProviderName to select which provider tier is active
  # 3. Both providers use OAuth via /connect command - no API keys needed
}
