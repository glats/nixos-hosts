{ config
, pkgs
, lib
, ...
}:

{
  imports = [
    ./hardware-configuration.nix

    # Hardware
    ../../modules/hardware/keyring.nix

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

    # Desktop
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/i18n.nix
    ../../modules/desktop/kmscon.nix
    ../../modules/features/services/xrdp.nix
    ./services/github-mcp-server.nix

    # Virtualisation
    ../../modules/virtualisation/docker.nix

    # Thinkcentre secrets
    ./secrets.nix

    # Thinkcentre conky config
    ./conky-config.nix

    # Conky module (options from features/conky)
    ../../modules/features/conky

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
    includeAcpiOsi = false;
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
  };

  system.stateVersion = "25.05";

  # OpenCode LLM provider configuration is managed centrally in
  # modules/home/opencode/providers.nix
  #
  # To change provider or model:
  # 1. Edit providers.nix to enable/disable providers or change models per phase
  # 2. Set activeProviderName to select which provider tier is active
  # 3. Both providers use OAuth via /connect command - no API keys needed
}
