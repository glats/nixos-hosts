{ inputs, self, ... }:

let
  mkNixosHost =
    { hostname
    , system ? "x86_64-linux"
    , username ? "glats"
    , extraModules ? [ ]
    , extraOverlays ? [ ]
    , nixpkgsInput ? inputs.nixpkgs
    , homeManagerInput ? inputs.home-manager
    ,
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
        # Host-specific configuration
        ../hosts/${hostname}

        # Sops-nix for secrets management
        hostInputs.sops-nix.nixosModules.sops

        # Home Manager integrated with NixOS
        homeManagerInput.nixosModules.home-manager

        # Overlays for custom packages
        {
          nixpkgs.overlays = [
            (import ../overlays/linux.nix { inherit self; inputs = hostInputs; })
          ] ++ extraOverlays;
        }

        # Pass inputs to home-manager for module access
        {
          home-manager.extraSpecialArgs = {
            inherit username;
            inputs = hostInputs;
          };
        }
      ]
      ++ extraModules;
    };

  # Backward-compatible alias
  mkHost = mkNixosHost;
in
{
  inherit mkHost mkNixosHost;
}
