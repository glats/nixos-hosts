{ pkgs
, inputs
, self
, primaryUser
, javaVersion
, lib
, ...
}:
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
    ./mise.nix
    ./cachix.nix
    ./homebrew.nix
    ./settings.nix
    ./wsdd.nix
  ];

  # nix config
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # disabled due to https://github.com/NixOS/nix/issues/7273
      # auto-optimise-store = true;
    };
    enable = false; # using Determinate installer
  };

  nixpkgs.config.allowUnfree = true;

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
        ../home-darwin
      ];
      # Define stateVersion here to satisfy early Home Manager assertions
      home.stateVersion = "25.05";
      # Per-host provider override: mact2 uses GitHub Copilot tier.
      # See `home.opencode.activeProviderName` in shared/opencode.nix.
      home.opencode.activeProviderName = "github-copilot";
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
