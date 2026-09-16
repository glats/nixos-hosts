{ inputs, self, ... }:

let
  mkDarwinHost =
    {
      configName,
      system ? "x86_64-darwin",
      primaryUser ? "jcuzmar",
      githubUser ? "jcuzmar",
      extraModules ? [ ],
    }:
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = {
        inherit
          inputs
          self
          primaryUser
          githubUser
          system
          ;
        host = configName;
        javaVersion = "temurin-25.0.1+8.0.LTS";
      };
      modules = [
        # Determinate Nix module
        inputs.determinate.darwinModules.default

        # Host-specific configuration (includes darwin modules)
        ../hosts/${configName}

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
