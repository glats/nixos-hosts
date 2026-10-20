{
  pkgs,
  lib,
  inputs,
  primaryUser,
  ...
}:
let
  hmSpotlightIndexEnable = true;
  baseModules = import ./shared-modules.nix { inherit inputs; };
  baseConfig = {
    imports =
      baseModules
      ++ lib.optionals hmSpotlightIndexEnable [
        ./spotlight-index.nix
      ]
      ++ [
        ./opencode/mcps-extra.nix
        ./opencode/quota-plugin.nix
      ];

    home.username = primaryUser;
    home.homeDirectory = "/Users/${primaryUser}";
    home.stateVersion = "25.05";
    home.sessionVariables = {
      VISUAL = lib.mkForce "nvim -u NONE";
      NIXOS_REPO = "$HOME/.config/nix";
    };

    home.sessionPath = [ "$HOME/.local/bin" ];

    targets.darwin.linkApps.enable = true;

    manual.manpages.enable = false;

    home.enableNixpkgsReleaseCheck = false;

    home.file.".hushlogin".text = "";
  };
in
baseConfig
