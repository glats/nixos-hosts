# GNOME Home Manager module for T14
# Follows the pattern of home-linux/mate.nix for MATE on rog
{ config
, pkgs
, lib
, inputs
, ...
}:

{
  imports = [
    ../../../home-linux/base.nix
    ../../../home-linux/shell.nix
    ../../../home-linux/theme.nix
    ../../../home-linux/tmux.nix
    ../../../home-linux/neovim.nix
    ../../../home-linux/git.nix
    ../../../home-linux/ssh.nix

    # Extras
    ../../../home-linux/btop.nix
    ../../../home-linux/rofi.nix
    ../../../home-linux/ghostty.nix
    ../../../home-linux/kitty.nix
    ../../../home-linux/gh.nix

    # OpenCode stack
    ../../../shared/opencode.nix
    ../../../shared/opencode-profile.nix
    ../../../shared/sops.nix
    inputs.sops-nix.homeManagerModules.sops
  ];

  # Use SSH host key for sops decryption (matches host_t14 in .sops.yaml)
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
}
