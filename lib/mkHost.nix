{ inputs, self, ... }:

let
  mkHost =
    { hostname
    , system ? "x86_64-linux"
    , extraModules ? [ ]
    }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs self; };
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
            (import ../modules/base/overlays.nix { inherit self inputs; })
          ];
        }

        # Pass flake inputs through Home Manager modules.
        {
          home-manager.extraSpecialArgs = { inherit inputs; };
        }
      ] ++ extraModules; # Extra host modules such as external desktop layers.
    };
in
{
  inherit mkHost;
}
