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

    # 🔥 NUEVO: gentle-ai upstream (para skills, commands, plugins)
    gentle-ai-src = {
      url = "github:Gentleman-Programming/gentle-ai";
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
      overlay = import ./modules/core/overlays.nix {
        inherit self inputs; # Pasar inputs para los nuevos src
      };
      pkgsFor = s: import nixpkgs { system = s; overlays = [ overlay ]; };
      pkgs = pkgsFor system;

      # Custom packages
      nixos-scripts = pkgs.callPackage ./pkgs/nixos-scripts { };
      gentle-ai = pkgs.callPackage ./pkgs/gentle-ai { };
      engram = pkgs.callPackage ./pkgs/engram { };
      gentle-ai-assets = pkgs.callPackage ./pkgs/gentle-ai-assets { inherit gentle-ai-src; };
    in
    {
      packages.${system} = {
        inherit nixos-scripts gentle-ai engram gentle-ai-assets;
      };

      checks.${system} = { };

      # Multi-host configurations
      nixosConfigurations = {
        rog = mkHost { hostname = "rog"; };
        thinkcentre = mkHost { hostname = "thinkcentre"; };
      };
    };
}
