{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix

    # Shared profile (base + desktop + server)
    ../../modules/profiles/server.nix

    # Thinkcentre secrets
    ./secrets.nix

    # Thinkcentre conky config
    ./conky-config.nix

    # Conky module (options from features/conky)
    ../../modules/features/conky

    # Host-specific service
    ./services/maquilinux-mounts.nix
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

  services.wol-custom.interface = "enp0s31f6";

  system.stateVersion = "25.05";

  # OpenCode LLM provider configuration is managed centrally in
  # shared/opencode/providers.nix (base providers)
  # home-darwin/opencode/providers-extra.nix (macOS extras)
  #
  # To change provider or model:
  # 1. Edit providers-base.nix to enable/disable providers or change models per phase
  # 2. Set activeProviderName to select which provider tier is active
  # 3. Both providers use OAuth via /connect command - no API keys needed
}
