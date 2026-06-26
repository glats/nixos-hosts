{ config
, pkgs
, lib
, ...
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
  # To change the active provider tier per host, set the HM option:
  #   home.opencode.activeProviderName = "github-copilot";
  # in the host's default.nix (e.g. darwin/default.nix for mact2).
  # Both providers use OAuth via /connect command - no API keys needed.
}
