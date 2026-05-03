{ config
, pkgs
, lib
, ...
}:

{
  imports = [
    ./hardware-configuration.nix

    # Base (transversal modules)
    ../../modules/base/cachix.nix
    ../../modules/base/home-manager.nix
    ../../modules/base/logind.nix
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
    ../../modules/hardware/asus-fan-control.nix
    ../../modules/hardware/keyring.nix

    # Desktop
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/i18n.nix
    ../../modules/desktop/kmscon.nix
    ../../modules/desktop/xfce-defaults.nix
    ./services/xrdp.nix

    # Services (rog-specific)
    ./services/arr-stack.nix
    ./services/cobalt.nix
    ./services/code-server.nix
    ./services/ddclient.nix
    ./services/dozzle.nix
    ./services/fileshelter.nix
    ./services/flaresolverr.nix
    ./services/ftp.nix
    ./services/github-mcp-server.nix
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
  };

  boot = {
    extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];
    kernelModules = [ "acpi_call" ];
  };

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

  # Fix 1: Extender timeouts para prevenir exit status 4 en nixos-rebuild switch
  # Ver: investigación de fallos intermitentes systemd-run switch-to-configuration
  # Usar mkForce para override los defaults del módulo oci-containers
  systemd.services.nginx.serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."acme-glats.org".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-guacamoledb".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-jellyfin".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-jellyseerr".serviceConfig.TimeoutStartSec = lib.mkForce "300";

  # Prevenir restart loops que consumen tiempo durante switch
  # Usar mkForce porque nginx ya define este valor
  systemd.services.nginx.startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-jellyfin".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-guacamoledb".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-jellyseerr".startLimitIntervalSec = lib.mkForce 0;

  # OpenCode LLM provider configuration is managed centrally in
  # modules/home/opencode/providers.nix
  #
  # To change provider or model:
  # 1. Edit providers.nix to enable/disable providers or change models per phase
  # 2. The first enabled provider in the list becomes the primary provider
  # 3. Both providers use OAuth via /connect command - no API keys needed
  #
  # Example - to enable GitHub Copilot:
  # providers = [
  #   { name = "github-copilot"; enabled = true; phases = { ... }; }
  #   { name = "opencode-go"; enabled = false; ... }
  # ];
}
