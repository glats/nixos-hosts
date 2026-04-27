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
    ../../modules/base/nix.nix
    ../../modules/base/packages.nix
    ../../modules/base/polkit.nix
    ../../modules/base/shutdown-fix.nix
    ../../modules/base/sops.nix
    ../../modules/base/users.nix
    ../../modules/base/zsh.nix

    # Hardware (rog-specific)
    ../../modules/hardware/default.nix
    ../../modules/hardware/nvidia.nix
    ../../modules/hardware/asus-fan-control.nix

    # Desktop
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/i18n.nix
    ../../modules/desktop/kmscon.nix
    ../../modules/desktop/xfce-defaults.nix
    ../../modules/features/desktop/xrdp.nix

    # Services
    ../../modules/features/services/arr-stack.nix
    ../../modules/features/services/cobalt.nix
    ../../modules/features/services/code-server.nix
    ../../modules/features/services/ddclient.nix
    ../../modules/features/services/dozzle.nix
    ../../modules/features/services/fileshelter.nix
    ../../modules/features/services/flaresolverr.nix
    ../../modules/features/services/ftp.nix
    ../../modules/features/services/github-mcp-server.nix
    ../../modules/features/services/gonic.nix
    ../../modules/features/services/guacamole.nix
    ../../modules/features/services/jellyfin.nix
    ../../modules/features/services/nginx.nix
    ../../modules/features/services/ollama.nix
    ../../modules/features/services/qbittorrent.nix
    ../../modules/features/services/samba.nix
    ../../modules/features/services/seerr.nix
    ../../modules/features/services/wetty.nix
    ../../modules/features/services/wireguard.nix

    # Virtualisation
    ../../modules/virtualisation/docker.nix
    ../../modules/virtualisation/libvirt.nix

    # Networking
    ../../modules/networking/avahi.nix
    ../../modules/networking/firewall.nix
    ../../modules/networking/openssh.nix
    ../../modules/networking/wol.nix
  ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    plymouth.enable = true;
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelPackages = pkgs.linuxPackages_zen;
    extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];
    kernelModules = [ "acpi_call" ];
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "vt.global_cursor_default=0"
      "acpi_osi=!"
      "acpi_osi=\"Windows 2018\""
    ];
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

  system.stateVersion = "24.11";

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

  # OpenCode LLM provider configuration (SDD agents)
  # Default: OpenCode Go (useGithubCopilot = false)
  # Both providers use OAuth via /connect command - no API keys needed
  #
  # To use GitHub Copilot instead:
  # home.opencode.useGithubCopilot = true;
}
