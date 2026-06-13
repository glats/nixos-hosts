# Home Manager configuration for macOS
# Aggregates all home-darwin modules.
{ pkgs
, lib
, inputs
, primaryUser
, ...
}:
let
  # Toggle: set to false to disable Spotlight indexing for HM apps
  hmSpotlightIndexEnable = true;
  # Canonical base list (see ./shared-modules.nix). Both flake.nix
  # (`darwinHomeModules`) and this file import from the same source
  # to keep paths in sync.
  baseModules = import ./shared-modules.nix { inherit inputs; };
  baseConfig = {
    imports =
      baseModules
      ++ lib.optionals hmSpotlightIndexEnable [
        ./spotlight-index.nix
      ]
      ++ [
        ./opencode/mcps-extra.nix
      ];

    # Minimal home fragment; tmux is configured in ./tmux.nix
    home.username = primaryUser;
    # Ensure the home directory option is set so home-manager can resolve paths
    home.homeDirectory = "/Users/${primaryUser}";
    home.stateVersion = "25.05";
    home.sessionVariables = {
      VISUAL = lib.mkForce "nvim -u NONE";
    };

    # Disable man page generation — triggers boost::too_few_args in Nix 2.31
    # (home-manager uses builtins.derivation for options.json without proper store context)
    manual.manpages.enable = false;

    # Silence version mismatch warning between home-manager and nixpkgs
    home.enableNixpkgsReleaseCheck = false;

    # create .hushlogin file to suppress login messages
    home.file.".hushlogin".text = "";
  };
in
baseConfig
