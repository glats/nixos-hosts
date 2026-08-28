# macOS host configuration for mact2.
# Imports the darwin base profile (system modules) and retains only
# per-host concerns: nix-homebrew, home-manager, users, environment,
# and service enablements.
{ pkgs
, inputs
, self
, primaryUser
, javaVersion
, lib
, host
, ...
}:
{
  imports = [
    # Flattened from modules/darwin/profiles/base.nix
    ../../darwin/system/nix.nix
    ../../darwin/system/cachix.nix
    ../../darwin/system/homebrew.nix
    ../../darwin/system/settings.nix
    ../../darwin/system/mise.nix
    ../../darwin/system/zsh.nix
    ../../darwin/services/wsdd.nix
    ../../darwin/system/sing-box-tunnel.nix

    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
    inputs.sops-nix.darwinModules.sops
  ];

  # Host-specific settings
  networking.hostName = host;

  # Tunnel design gate: EDR/corporate-agent management traffic must stay
  # direct — if the tunnel dies, corporate telemetry must not go dark with
  # it. 163.116.0.0/16 = Netskope cloud (observed 163.116.131.x/.148.x).
  tunnel.directCidrs = [ "163.116.0.0/16" ];

  # homebrew installation manager
  nix-homebrew = {
    user = primaryUser;
    enable = true;
    autoMigrate = true;
  };

  # home-manager config
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # Back up conflicting dotfiles (e.g., ~/.zshrc) instead of failing
    backupFileExtension = "backup";
    users.${primaryUser} = {
      imports = [
        ../../darwin/home
      ];
      # Define stateVersion here to satisfy early Home Manager assertions
      home.stateVersion = "25.05";
      # Per-host provider override: mact2 routes through the `opencode-go`
      # gateway instead of native OpenAI (native is Netskope-blocked).
      # See `home.opencode.activeProviderName` in shared/opencode.nix and
      # the opencode-go-{full,medium,light} tiers in
      # shared/opencode/providers-base.nix.
      home.opencode.activeProviderName = "opencode-go-medium";
    };
    extraSpecialArgs = {
      inherit
        inputs
        self
        primaryUser
        javaVersion
        ;
    };
  };

  # macOS-specific settings
  system.primaryUser = primaryUser;
  users.users.${primaryUser} = {
    home = "/Users/${primaryUser}";
    shell = pkgs.zsh;

    # SSH authorized keys for remote access
    openssh.authorizedKeys.keys = [
      # rog machine (glats)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMigT6lscyISTW6jbk9c34gMYSaRQIq4tUxMvn7vd6K7 t14"
    ];
  };
  environment = {
    variables = {
      DISPLAY = ":0";
    };
    systemPackages = with pkgs; [ git ];
    # Intel uses /usr/local; Apple Silicon uses /opt/homebrew
    systemPath = [
      (if pkgs.stdenv.isAarch64 then "/opt/homebrew/bin" else "/usr/local/bin")
    ];
    pathsToLink = [ "/Applications" ];
  };

  services.wsdd.enable = true;
}
