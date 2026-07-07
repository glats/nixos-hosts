{ inputs, self, ... }:

let
  mkDarwinHost =
    { hostname
    , system ? "x86_64-darwin"
    , username ? "jcuzmar"
    , extraModules ? [ ]
    ,
    }:
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = {
        inherit
          inputs
          self
          username
          system
          ;
        host = hostname;
        primaryUser = username;
        javaVersion = "temurin-25.0.1+8.0.LTS";
      };
      modules = [
        # Determinate Nix module
        inputs.determinate.darwinModules.default

        # Host-specific configuration
        ../hosts/${hostname}

        # Darwin system modules (homebrew, settings, etc.)
        ../darwin

        # Overlays for custom packages
        {
          nixpkgs.overlays = [
            (import ../overlays/darwin.nix { inherit inputs self; })
          ];
        }
      ]
      ++ extraModules;
    };
in
{
  inherit mkDarwinHost;
}
