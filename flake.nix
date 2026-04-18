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
  };

  outputs = inputs@{ self, nixpkgs, home-manager, sops-nix, nix-colors, ... }:
    let
      inherit (import ./lib/mkHost.nix { inherit inputs; }) mkHost;

      system = "x86_64-linux";
      overlay = import ./modules/core/overlays.nix { inherit self; };
      pkgsFor = s: import nixpkgs { system = s; overlays = [ overlay ]; };
      pkgs = pkgsFor system;

      # Custom packages
      nixos-scripts = pkgs.callPackage ./pkgs/nixos-scripts { };
      gentle-ai = pkgs.callPackage ./pkgs/gentle-ai { };
      engram = pkgs.callPackage ./pkgs/engram { };
    in
    {
      packages.${system} = {
        inherit nixos-scripts gentle-ai engram;
      };

      checks.${system} = { };

      # Multi-host configurations
      nixosConfigurations = {
        rog = mkHost { hostname = "rog"; };
        thinkcentre = mkHost { hostname = "thinkcentre"; };
      };
    };
}
