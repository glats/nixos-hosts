{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
      hostName = config.networking.hostName;
      conkyConfig = config.conky-config;
      # Force rebuild: 2026-05-03
    };
    users.glats = {
      imports = [
        ../../home-linux/base.nix
        ../../home-linux/shell.nix
        ../../home-linux/theme.nix
        ../../home-linux/btop.nix
        ../../home-linux/tmux.nix
        ../../home-linux/neovim.nix
        ../../home-linux/mate.nix
        ../../home-linux/rofi.nix
        ../../home-linux/git.nix
        ../../home-linux/gh.nix
        ../../home-linux/ghostty.nix
        ../../home-linux/kitty.nix
        ../../home-linux/opencode.nix
        ../../home-linux/opencode-profile.nix
        ../../home-linux/chrome-apps.nix
        ../../home-linux/ssh.nix
        ../../home-linux/sops.nix
        inputs.sops-nix.homeManagerModules.sops
      ]
      ++ lib.optionals (config.networking.hostName == "rog") [
        ../../home-linux/conky-rog.nix
        ../../home-linux/openfang.nix
      ]
      ++ lib.optionals (config.networking.hostName == "thinkcentre") [
        ../../home-linux/conky-thinkcentre.nix
      ];
    };
  };
}
