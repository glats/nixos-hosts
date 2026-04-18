{ inputs, ... }:

let
  mkHost = { hostname
  , system ? "x86_64-linux"
  , extraModules ? []
  }:
  inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit inputs; };
    modules = [
      # Host-specific configuration
      ../hosts/${hostname}

      # Sops-nix for secrets management
      inputs.sops-nix.nixosModules.sops

      # Home Manager integrated with NixOS
      inputs.home-manager.nixosModules.home-manager

      # Overlays for custom packages
      {
        nixpkgs.overlays = [
          (import ../modules/core/overlays.nix { self = inputs.self; })
        ];
      }
    ] ++ extraModules;
  };
in
{
  inherit mkHost;
}
