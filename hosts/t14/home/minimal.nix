{ config, pkgs, ... }:

{
  # Minimal home configuration for T14
  # Just the essentials: terminal tools, opencode, editor

  imports = [
    ../../../home-linux/base.nix
    ../../../home-linux/shell.nix
    ../../../home-linux/tmux.nix
    ../../../home-linux/neovim.nix
    ../../../home-linux/git.nix
    ../../../home-linux/opencode.nix
    ../../../home-linux/ssh.nix
  ];

  # Add any t14-specific minimal configs here
  home.packages = with pkgs; [
    # Additional minimal tools if needed
  ];
}
