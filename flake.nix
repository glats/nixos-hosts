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

    # gentle-ai upstream (for skills, commands, plugins)
    # Must match version in pkgs/gentle-ai/default.nix
    gentle-ai-src = {
      url = "github:Gentleman-Programming/gentle-ai/v1.24.1";
      flake = false; # No es un flake, es repo normal
    };

    # 🔥 NUEVO: asus-fan-control upstream
    asus-fan-control-src = {
      url = "github:dominiksalvet/asus-fan-control";
      flake = false;
    };

    # 🔥 NUEVO: pipewire-module-xrdp upstream
    pipewire-module-xrdp-src = {
      url = "github:neutrinolabs/pipewire-module-xrdp";
      flake = false;
    };

    # 🔥 NUEVO: nvim config
    nvim-config = {
      url = "github:j1cs/nvim";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, sops-nix, nix-colors, gentle-ai-src, asus-fan-control-src, pipewire-module-xrdp-src, ... }:
    let
      inherit (import ./lib/mkHost.nix { inherit inputs self; }) mkHost;

      system = "x86_64-linux";
      overlay = import ./modules/base/overlays.nix {
        inherit self inputs; # Pasar inputs para los nuevos src
      };
      pkgsFor = s: import nixpkgs { system = s; overlays = [ overlay ]; };
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
      };

      # Library functions for external use (non-NixOS portability)
      opencode-config-lib = import ./pkgs/opencode-config { inherit (pkgs) lib writeText; };
    in
    {
      packages.${system} = {
        inherit nixos-scripts gentle-ai engram gentle-ai-assets-vanilla gentle-ai-assets;
      };

      # Reusable library functions for other flakes
      lib.opencode-config = opencode-config-lib;

      checks.${system} = { };

      # Multi-host configurations
      nixosConfigurations = {
        rog = mkHost { hostname = "rog"; };
        thinkcentre = mkHost { hostname = "thinkcentre"; };
      };
    };
}
