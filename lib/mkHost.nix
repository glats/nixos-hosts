{ inputs, self, ... }:

let
  mkNixosHost =
    {
      hostname,
      system ? "x86_64-linux",
      username ? "glats",
      extraModules ? [ ],
      extraOverlays ? [ ],
      nixpkgsInput ? inputs.nixpkgs,
      homeManagerInput ? inputs.home-manager,
    }:
    let
      hostInputs = inputs // {
        nixpkgs = nixpkgsInput;
        home-manager = homeManagerInput;
      };
    in
    nixpkgsInput.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit self username;
        inputs = hostInputs;
      };
      modules = [
        ../hosts/${hostname}

        hostInputs.sops-nix.nixosModules.sops

        homeManagerInput.nixosModules.home-manager

        {
          nixpkgs.overlays = [
            (import ../overlays/linux.nix {
              inherit self;
              inputs = hostInputs;
            })
          ]
          ++ extraOverlays;
        }

        {
          home-manager.extraSpecialArgs = {
            inherit username;
            inputs = hostInputs;
          };
        }
      ]
      ++ extraModules;
    };

  mkHost = mkNixosHost;
in
{
  inherit mkHost mkNixosHost;
}
