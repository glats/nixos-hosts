# macOS host configuration for macm5 (Apple Silicon).
# Imports the darwin base profile (system modules) and retains only
# per-host concerns: nix-homebrew, home-manager, users, environment,
# and service enablements.
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

  # Keep corporate EDR traffic direct if the private link is unavailable.
  link.directCidrs = [ "163.116.0.0/16" ];

  nix-homebrew = {
    user = primaryUser;
    enable = true;
    autoMigrate = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.${primaryUser} = {
      imports = [
        ../../darwin/home
      ];
      home.stateVersion = "25.05";
      home.opencode.activeProviderName = "anthropic-opencode-free";
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

  system.primaryUser = primaryUser;
  users.users.${primaryUser} = {
    home = "/Users/${primaryUser}";
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      # rog machine (glats)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMigT6lscyISTW6jbk9c34gMYSaRQIq4tUxMvn7vd6K7 t14"
    ];
  };
  environment = {
    variables = {
      DISPLAY = ":0";
    };
    systemPackages = with pkgs; [ git nixos-scripts ];
    # Intel uses /usr/local; Apple Silicon uses /opt/homebrew.
    systemPath = [
      (if pkgs.stdenv.isAarch64 then "/opt/homebrew/bin" else "/usr/local/bin")
    ];
    pathsToLink = [ "/Applications" ];
  };

  services.wsdd.enable = true;
}
