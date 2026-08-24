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
    ../../darwin/services/wsdd.nix

    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  # Host-specific settings
  networking.hostName = host;

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
      # Per-host provider override: mact2 uses the native built-in
      # `openai` provider (ChatGPT OAuth) with the `openai-medium`
      # tier. Runtime HTTPS egress is routed through the rog tinyproxy
      # at 10.13.13.1:3128 over the existing WireGuard tunnel — see
      # extraInitContent below. Change: mact2-openai-transport-proxy-via-rog.
      home.opencode.activeProviderName = "openai-medium";
      # OpenCode-shell-only proxy environment. The native macOS network
      # stack is untouched: HTTPS_PROXY is read by OpenCode (and the
      # zsh shell it runs in) and ignored by every other macOS app.
      home.opencode.extraInitContent = ''
        # WireGuard-bound forward proxy on rog (services.tinyproxy,
        # Listen=10.13.13.1, Allow=10.13.13.3, ConnectPort=443).
        # HTTP_PROXY + HTTPS_PROXY use the same URL — many HTTPS libs
        # honour HTTPS_PROXY but a few fall back to HTTP_PROXY.
        export HTTP_PROXY="http://10.13.13.1:3128"
        export HTTPS_PROXY="http://10.13.13.1:3128"
        # Loopback must stay direct so local OpenCode/Codex helpers
        # that listen on 127.0.0.1 still work.
        export NO_PROXY="localhost,127.0.0.1"
      '';
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
