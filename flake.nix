{
  description = "Unified NixOS configuration for multiple hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors.url = "github:misterio77/nix-colors";

    omarchy-nix = {
      url = "github:glats/omarchy-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # gentle-ai upstream (for skills, commands, plugins)
    # Must match version in pkgs/gentle-ai/default.nix
    gentle-ai-src = {
      url = "github:Gentleman-Programming/gentle-ai/v1.30.3";
      flake = false; # No es un flake, es repo normal
    };

    asus-fan-control-src = {
      url = "github:dominiksalvet/asus-fan-control";
      flake = false;
    };

    pipewire-module-xrdp-src = {
      url = "github:neutrinolabs/pipewire-module-xrdp";
      flake = false;
    };

    nvim-config = {
      url = "github:j1cs/nvim";
      flake = false;
    };

    # TUI plugins for OpenCode
    sub-agent-statusline = {
      url = "github:Joaquinvesapa/sub-agent-statusline";
      flake = false;
    };

    sdd-engram-plugin = {
      url = "github:j0k3r-dev-rgl/sdd-engram-plugin";
      flake = false;
    };

    # engram upstream (for OpenCode plugin)
    # Must match version in pkgs/engram/default.nix
    engram-src = {
      url = "github:Gentleman-Programming/engram/v1.15.13";
      flake = false;
    };
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , home-manager
    , sops-nix
    , nix-colors
    , omarchy-nix
    , gentle-ai-src
    , asus-fan-control-src
    , pipewire-module-xrdp-src
    , nvim-config
    , sub-agent-statusline
    , sdd-engram-plugin
    , engram-src
    , ...
    }:
    let
      inherit (import ./lib/mkHost.nix { inherit inputs self; }) mkHost;

      system = "x86_64-linux";
      overlay = import ./modules/base/overlays.nix {
        inherit self inputs; # Pasar inputs para los nuevos src
      };
      pkgsFor =
        s:
        import nixpkgs {
          system = s;
          overlays = [ overlay ];
        };
      pkgs = pkgsFor system;

      # Custom packages
      nixos-scripts = pkgs.callPackage ./pkgs/nixos-scripts { };
      gentle-ai = pkgs.callPackage ./pkgs/gentle-ai { };
      engram = pkgs.callPackage ./pkgs/engram { };
      gentle-ai-assets-vanilla = pkgs.callPackage ./pkgs/gentle-ai-assets/vanilla.nix {
        inherit gentle-ai-src;
      };
      gentle-ai-assets = pkgs.callPackage ./pkgs/gentle-ai-assets/default.nix {
        inherit (pkgs) writeText;
        vanilla = gentle-ai-assets-vanilla;
        extraSkills = ./modules/home/opencode/skills;
        extraCommands = ./modules/home/opencode/commands;
      };
      engram-assets-vanilla = pkgs.callPackage ./pkgs/engram-assets/vanilla.nix {
        inherit engram-src;
      };
      engram-assets = pkgs.callPackage ./pkgs/engram-assets/default.nix {
        inherit engram;
        vanilla = engram-assets-vanilla;
      };

      secret-guard-assets = pkgs.callPackage ./pkgs/secret-guard-assets { };

      opencode-npm-packages = pkgs.callPackage ./pkgs/opencode-npm-packages { };
      openfang = pkgs.callPackage ./pkgs/openfang { };

      # verify-models: Test LLM model availability across free-tier providers
      verify-models = pkgs.writers.writePython3Bin "verify-models"
        {
          libraries = [ pkgs.python3Packages.openai ];
          flakeIgnore = [
            "E501"
            "W503"
            "E265"
            "E266"
            "F702"
          ];
        }
        (builtins.readFile ./scripts/verify-models.py);

      # verify-tiers: Test every model in every OpenCode tier list (raw API)
      verify-tiers = pkgs.writers.writePython3Bin "verify-tiers"
        {
          libraries = [ pkgs.python3Packages.openai ];
          flakeIgnore = [
            "E501"
            "W503"
            "E265"
            "E266"
            "E226"
            "F702"
          ];
        }
        (builtins.readFile ./scripts/verify-tiers.py);

      # verify-opencode: Test models through opencode run (catches SDK/integration bugs)
      verify-opencode = pkgs.writers.writePython3Bin "verify-opencode"
        {
          flakeIgnore = [
            "E501"
            "W503"
            "E265"
            "E266"
            "E226"
            "F702"
          ];
        }
        (builtins.readFile ./scripts/verify-opencode.py);

      # Library functions for external use (non-NixOS portability)
      opencode-config-lib = import ./pkgs/opencode-config { inherit (pkgs) lib writeText; };
    in
    {
      packages.${system} = {
        inherit
          nixos-scripts
          gentle-ai
          engram
          gentle-ai-assets-vanilla
          gentle-ai-assets
          engram-assets-vanilla
          engram-assets
          secret-guard-assets
          opencode-npm-packages
          verify-models
          verify-tiers
          verify-opencode
          openfang
          ;
        # ISO package for nix build .#packages.x86_64-linux.t14-iso
        t14-iso = self.nixosConfigurations.t14-iso.config.system.build.isoImage;
      };

      # Apps for nix run .#verify-models
      apps.${system} = {
        verify-models = {
          type = "app";
          program = "${verify-models}/bin/verify-models";
        };
        verify-tiers = {
          type = "app";
          program = "${verify-tiers}/bin/verify-tiers";
        };
        verify-opencode = {
          type = "app";
          program = "${verify-opencode}/bin/verify-opencode";
        };
        nixos-build = {
          type = "app";
          program = "${nixos-scripts}/bin/nixos-build";
        };
      };

      # Reusable library functions for other flakes
      lib.opencode-config = opencode-config-lib;

      checks.x86_64-linux = {
        rog = self.nixosConfigurations.rog.config.system.build.toplevel;
        t14 = self.nixosConfigurations.t14.config.system.build.toplevel;
        thinkcentre = self.nixosConfigurations.thinkcentre.config.system.build.toplevel;
      };

      # Multi-host configurations
      nixosConfigurations = {
        rog = mkHost { hostname = "rog"; };
        t14 = mkHost {
          hostname = "t14";
          extraModules = [ omarchy-nix.nixosModules.default ];
        };
        thinkcentre = mkHost { hostname = "thinkcentre"; };
        t14-iso = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/t14/iso.nix
            { nixpkgs.config.allowUnfree = true; }
            {
              nixpkgs.overlays = [
                (import ./modules/base/overlays.nix { inherit self inputs; })
              ];
            }
          ];
        };
      };

      # Standalone home-manager configurations (for hms alias)
      homeConfigurations =
        let
          mkHomeConfig =
            hostname: extraModules:
            home-manager.lib.homeManagerConfiguration {
              pkgs = pkgsFor system;
              modules = [
                ./modules/home/base.nix
                ./modules/home/shell.nix
                ./modules/home/theme.nix
                ./modules/home/btop.nix
                ./modules/home/tmux.nix
                ./modules/home/neovim.nix
                ./modules/home/mate.nix
                ./modules/home/rofi.nix
                ./modules/home/git.nix
                ./modules/home/gh.nix
                ./modules/home/ghostty.nix
                ./modules/home/kitty.nix
                ./modules/home/opencode.nix
                ./modules/home/opencode-profile.nix
                ./modules/home/openfang.nix
                ./modules/home/chrome-apps.nix
                ./modules/home/ssh.nix
                ./modules/home/sops.nix
                inputs.sops-nix.homeManagerModules.sops
              ]
              ++ extraModules;
              extraSpecialArgs = {
                inherit inputs;
                hostName = hostname;
              };
            };
        in
        {
          rog = mkHomeConfig "rog" [ ./modules/home/conky-rog.nix ];
          thinkcentre = mkHomeConfig "thinkcentre" [ ./modules/home/conky-thinkcentre.nix ];
        };

    };
}
