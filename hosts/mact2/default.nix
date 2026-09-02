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
    ../../darwin/system/sing-box-link.nix

    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
    inputs.sops-nix.darwinModules.sops
  ];

  # Host-specific settings
  networking.hostName = host;

  # Link design gate: EDR/corporate-agent management traffic must stay
  # direct — if the link dies, corporate telemetry must not go dark with
  # it. 163.116.0.0/16 = endpoint security agent cloud (observed
  # 163.116.131.x/.148.x).
  link.directCidrs = [ "163.116.0.0/16" ];

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
      # Per-host provider override: mact2 uses native OpenAI (ChatGPT
      # OAuth) through the sing-box private link — reachability comes
      # from the scoped bin/opencode-home launcher (proxy env exported
      # only while 127.0.0.1:2080 listens; MCP children stay scrubbed
      # via mcp.environment in shared/opencode/runtime-config.nix). See
      # `home.opencode.activeProviderName` in shared/opencode.nix and
      # the openai-{full,medium,light} tiers in
      # shared/opencode/providers-base.nix.
      home.opencode.activeProviderName = "anthropic-copilot";
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
    # nixos-scripts (linkctl) at the SYSTEM level too: linkctl
    # start/stop/restart re-exec via sudo with an absolute path, and a
    # /run/current-system/sw/bin/linkctl copy guarantees a stable
    # resolution even in shells whose PATH lacks the user's HM profile.
    systemPackages = with pkgs; [ git nixos-scripts ];
    # Intel uses /usr/local; Apple Silicon uses /opt/homebrew
    systemPath = [
      (if pkgs.stdenv.isAarch64 then "/opt/homebrew/bin" else "/usr/local/bin")
    ];
    pathsToLink = [ "/Applications" ];
  };

  services.wsdd.enable = true;
}
