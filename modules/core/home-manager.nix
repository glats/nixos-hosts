{ config, lib, pkgs, inputs, ... }:

let
  # Select conky config based on hostname
  conkyModule =
    if config.networking.hostName == "rog" then
      ../home/conky-rog.nix
    else
      ../home/conky-thinkcentre.nix;
in
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
      hostName = config.networking.hostName;
    };
    users.glats = {
      imports = [
        ../home/base.nix
        ../home/shell.nix
        ../home/theme.nix
        ../home/btop.nix
        ../home/tmux.nix
        ../home/neovim.nix
        ../home/mate.nix
        ../home/xfce.nix
        ../home/cinnamon.nix
        ../home/rofi.nix
        conkyModule
        ../home/git.nix
        ../home/gh.nix
        ../home/ghostty.nix
        ../home/kitty.nix
        ../home/opencode.nix
        ../home/opencode-profile.nix
        ../home/chrome-apps.nix
        ../home/ssh.nix
        ../home/sops.nix
        inputs.sops-nix.homeManagerModules.sops
      ];
    };
  };
}
