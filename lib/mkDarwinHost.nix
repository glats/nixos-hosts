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
        inputs.determinate.darwinModules.default

        ../hosts/${configName}

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
