# hosts/rog/home/modules.nix -- BACKWARD COMPATIBILITY WRAPPER
#
# This file is preserved for backward compatibility. The canonical HM
# entry point for rog is ./omarchy.nix. Both NixOS-integrated and
# standalone HM paths now use omarchy.nix directly (see flake.nix
# homeConfigurations.rog and hosts/rog/default.nix).
#
# New consumers should import ./omarchy.nix instead.
{ inputs }:
[
  inputs.omarchy-nix.homeManagerModules.default
  ./default.nix
  ../../../home-linux/base.nix
  ../../../home-linux/shell.nix
  ../../../home-linux/tmux.nix
  ../../../home-linux/neovim.nix
  ../../../home-linux/git.nix
  ../../../home-linux/gh.nix
  ../../../home-linux/ssh.nix
  ../../../home-linux/remote-desktop.nix
  ../../../home-linux/ghostty.nix
  ../../../home-linux/kitty.nix
  ../../../home-linux/alacritty.nix
  ../../../home-linux/shell-gpt.nix
  ../../../home-linux/openfang.nix
  ../../../home-linux/webcam-rog.nix
  ../../../shared/shell-aliases.nix
  ../../../shared/opencode.nix
  ../../../shared/opencode-profile.nix
  ../../../shared/sops.nix
  inputs.sops-nix.homeManagerModules.sops
  ({ home.shell-gpt.enable = true; })
]
