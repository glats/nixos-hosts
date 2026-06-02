{
  description = "Unified Nix configuration for NixOS and macOS hosts";

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

    # gentle-ai upstream (for skills, commands, plugins)
    # Must match version in pkgs/gentle-ai/default.nix
    gentle-ai-src = {
      url = "github:Gentleman-Programming/gentle-ai/v1.30.3";
      flake = false;
    };

    # engram upstream (for OpenCode plugin)
    # Must match version in pkgs/engram/default.nix
    engram-src = {
      url = "github:Gentleman-Programming/engram/v1.15.13";
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

    # --- NixOS-only inputs ---
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

    # --- macOS-only inputs ---
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Determinate 3.* module
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-homebrew -- brew-src pinned to commit that fixes `to_sym for nil` crash
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.brew-src.follows = "homebrew-brew";
    };
    homebrew-brew = {
      # Fix commit: "cleanup undefined-method-to_sym-for-nil" (5.1.10 + 17 commits)
      url = "github:Homebrew/brew/3f0f2574bc0c89f75271cd7ee21695bfdade50f6";
      flake = false;
    };

    # LazyVim starter (pinned via flake input, no sha256 needed here)
    lazyvim-starter = {
      url = "github:LazyVim/starter";
      flake = false;
    };

    # VS Code extensions as Nix
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ghostty = {
      url = "github:ghostty-org/ghostty";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , home-manager
    , sops-nix
    , nix-colors
    , gentle-ai-src
    , engram-src
    , ...
    }:
    let
      # --- Builders ---
      inherit (import ./lib/mkHost.nix { inherit inputs self; }) mkNixosHost mkHost;
      inherit (import ./lib/mkDarwinHost.nix { inherit inputs self; }) mkDarwinHost;

      # --- Overlay selection by system ---
      linuxOverlay = import ./overlays/linux.nix {
        inherit self inputs;
      };
      darwinOverlay = import ./overlays/darwin.nix {
        inherit inputs self;
      };

      pkgsFor =
        s:
        import nixpkgs {
          system = s;
          overlays = if nixpkgs.lib.hasSuffix "linux" s then [ linuxOverlay ] else [ darwinOverlay ];
        };

      # --- Linux packages (x86_64-linux) ---
      linuxPkgs = pkgsFor "x86_64-linux";

      nixos-scripts = linuxPkgs.callPackage ./pkgs/nixos-scripts { };
      gentle-ai = linuxPkgs.callPackage ./pkgs/gentle-ai { };
      engram = linuxPkgs.callPackage ./pkgs/engram { };
      gentle-ai-assets-vanilla = linuxPkgs.callPackage ./pkgs/gentle-ai-assets/vanilla.nix {
        inherit gentle-ai-src;
      };
      gentle-ai-assets = linuxPkgs.callPackage ./pkgs/gentle-ai-assets/default.nix {
        inherit (linuxPkgs) writeText;
        vanilla = gentle-ai-assets-vanilla;
        extraSkills = ./shared/opencode/skills;
        extraCommands = ./shared/opencode/commands;
      };
      engram-assets-vanilla = linuxPkgs.callPackage ./pkgs/engram-assets/vanilla.nix {
        inherit engram-src;
      };
      engram-assets = linuxPkgs.callPackage ./pkgs/engram-assets/default.nix {
        inherit engram;
        vanilla = engram-assets-vanilla;
      };
      secret-guard-assets = linuxPkgs.callPackage ./pkgs/secret-guard-assets { };
      opencode-npm-packages = linuxPkgs.callPackage ./pkgs/opencode-npm-packages { };
      openfang = linuxPkgs.callPackage ./pkgs/openfang { };

      # verify-models: Test LLM model availability across free-tier providers
      verify-models = linuxPkgs.writers.writePython3Bin "verify-models"
        {
          libraries = [ linuxPkgs.python3Packages.openai ];
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
      verify-tiers = linuxPkgs.writers.writePython3Bin "verify-tiers"
        {
          libraries = [ linuxPkgs.python3Packages.openai ];
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
      verify-opencode = linuxPkgs.writers.writePython3Bin "verify-opencode"
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
      opencode-config-lib = import ./pkgs/opencode-config {
        inherit (linuxPkgs) lib writeText;
      };

      # --- Darwin packages (x86_64-darwin) ---
      darwinPkgs = pkgsFor "x86_64-darwin";

      darwin-gentle-ai = darwinPkgs.callPackage ./pkgs/gentle-ai { };
      darwin-engram = darwinPkgs.callPackage ./pkgs/engram { };
      darwin-gentle-ai-assets-vanilla = darwinPkgs.callPackage ./pkgs/gentle-ai-assets/vanilla.nix {
        inherit gentle-ai-src;
      };
      darwin-gentle-ai-assets = darwinPkgs.callPackage ./pkgs/gentle-ai-assets/default.nix {
        inherit (darwinPkgs) writeText;
        vanilla = darwin-gentle-ai-assets-vanilla;
        extraSkills = ./shared/opencode/skills;
        extraCommands = ./shared/opencode/commands;
      };
      darwin-engram-assets-vanilla = darwinPkgs.callPackage ./pkgs/engram-assets/vanilla.nix {
        inherit engram-src;
      };
      darwin-engram-assets = darwinPkgs.callPackage ./pkgs/engram-assets/default.nix {
        engram = darwin-engram;
        vanilla = darwin-engram-assets-vanilla;
      };
      darwin-secret-guard-assets = darwinPkgs.callPackage ./pkgs/secret-guard-assets { };
      darwin-opencode-npm-packages = darwinPkgs.callPackage ./pkgs/opencode-npm-packages { };

      darwin-opencode-config-lib = import ./pkgs/opencode-config {
        inherit (darwinPkgs) lib writeText;
      };

      # --- Home module lists ---
      linuxHomeModules = [
        ./home-linux/base.nix
        ./home-linux/shell.nix
        ./home-linux/theme.nix
        ./home-linux/btop.nix
        ./home-linux/tmux.nix
        ./home-linux/neovim.nix
        ./home-linux/mate.nix
        ./home-linux/rofi.nix
        ./home-linux/git.nix
        ./home-linux/gh.nix
        ./home-linux/ghostty.nix
        ./home-linux/kitty.nix
        ./home-linux/opencode.nix
        ./home-linux/opencode-profile.nix
        ./home-linux/openfang.nix
        ./home-linux/chrome-apps.nix
        ./home-linux/ssh.nix
        ./home-linux/sops.nix
        inputs.sops-nix.homeManagerModules.sops
      ];

      darwinHomeModules = [
        ./home-darwin
      ];

      # --- mkHomeConfig: standalone home-manager for any platform ---
      mkHomeConfig =
        hostname: system: username: extraModules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          modules =
            (if nixpkgs.lib.hasSuffix "linux" system then linuxHomeModules else darwinHomeModules)
            ++ extraModules;
          extraSpecialArgs = {
            inherit inputs username;
            hostName = hostname;
            # Darwin-specific extras (ignored by linux modules)
            primaryUser = username;
            javaVersion = "temurin-25.0.1+8.0.LTS";
          };
        };
    in
    {
      # --- Linux packages ---
      packages.x86_64-linux = {
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
      };

      # --- Darwin packages (no nixos-scripts, no openfang) ---
      packages.x86_64-darwin = {
        gentle-ai = darwin-gentle-ai;
        engram = darwin-engram;
        gentle-ai-assets-vanilla = darwin-gentle-ai-assets-vanilla;
        gentle-ai-assets = darwin-gentle-ai-assets;
        engram-assets-vanilla = darwin-engram-assets-vanilla;
        engram-assets = darwin-engram-assets;
        secret-guard-assets = darwin-secret-guard-assets;
        opencode-npm-packages = darwin-opencode-npm-packages;
      };

      # --- Apps for nix run ---
      apps.x86_64-linux = {
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

      # --- Reusable library functions ---
      lib.opencode-config = opencode-config-lib;

      # --- Checks ---
      checks.x86_64-linux = {
        rog = self.nixosConfigurations.rog.config.system.build.toplevel;
        thinkcentre = self.nixosConfigurations.thinkcentre.config.system.build.toplevel;
      };

      # --- NixOS configurations ---
      nixosConfigurations = {
        rog = mkNixosHost { hostname = "rog"; };
        thinkcentre = mkNixosHost { hostname = "thinkcentre"; };
      };

      # --- Darwin configurations ---
      darwinConfigurations = {
        mact2 = mkDarwinHost { hostname = "mact2"; };
      };

      # --- Standalone home-manager configurations ---
      homeConfigurations =
        let
          baseHomeConfig =
            hostname: system: username: extraModules:
            mkHomeConfig hostname system username extraModules;
        in
        {
          rog = baseHomeConfig "rog" "x86_64-linux" "glats" [
            ./home-linux/conky-rog.nix
          ];
          thinkcentre = baseHomeConfig "thinkcentre" "x86_64-linux" "glats" [
            ./home-linux/conky-thinkcentre.nix
          ];
          mact2 = baseHomeConfig "mact2" "x86_64-darwin" "jcuzmar" [ ];
        };

      # --- Formatter ---
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
      formatter.x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.nixfmt-rfc-style;
    };
}
