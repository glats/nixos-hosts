{ config
, pkgs
, lib
, ...
}:

{
  imports = [
    ./hardware-configuration.nix

    # Hardware
    ../../modules/hardware/default.nix

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

    # Desktop
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/i18n.nix
    ../../modules/desktop/kmscon.nix
    ../../modules/desktop/xfce-defaults.nix
    ../../modules/features/desktop/xrdp.nix

    # Virtualisation
    ../../modules/virtualisation/docker.nix

    # Services
    ../../modules/features/services/github-mcp-server.nix

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
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "vt.global_cursor_default=0"
    ];
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePackages = [ "joypixels" ];
    joypixels.acceptLicense = true;
  };

  networking = {
    hostName = "thinkcentre";
    networkmanager.enable = true;
  };

  system.stateVersion = "25.05";

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
