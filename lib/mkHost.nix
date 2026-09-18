{ inputs, self, ... }:

let
  mkNixosHost =
    {
      hostname,
      system ? "x86_64-linux",
      username ? "glats",
      extraModules ? [ ],
    }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit self username;
        inherit inputs;
      };
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
            (import ../overlays/linux.nix {
              inherit self;
              inherit inputs;
            })
          ];
        }

        # Pass inputs to home-manager for module access
        {
          home-manager.extraSpecialArgs = {
            inherit username;
            inherit inputs;
          };
        }
      ]
      ++ extraModules;
    };

in
{
  inherit mkNixosHost;
}
