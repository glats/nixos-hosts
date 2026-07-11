# Rog Home Manager -- Omarchy HM entry point.
#
# Replaces the previous modules.nix wrapping shared-modules.nix.
# Wire the omarchy-nix homeManagerModules.default alongside rog-specific
# Hyprland overlays in home/default.nix.
#
# Selective shared-module imports:
#   * Imported: base, shell, tmux, neovim, git, gh, ssh, ghostty, kitty,
#     alacritty, remote-desktop, shell-gpt, opencode, sops, fontconfig,
#     shell-aliases, openfang, webcam-rog
#   * Excluded: mate (MATE dconf -- system-level only, incompatible with
#     Hyprland), rofi (omarchy uses walker), chrome-apps (webapps managed
#     by omarchy webapp tooling), theme.nix (omarchy owns the visual layer)
#
# The omarchy HM module is imported FIRST so rog-specific overlays in
# default.nix can override via lib.mkForce.
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    # Omarchy HM module -- supplies Hyprland, waybar, walker, etc.
    inputs.omarchy-nix.homeManagerModules.default

    # Rog-specific Hyprland overlays (monitors, input, env)
    ./default.nix

    # Compatible shared modules from home-linux/
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

    # Shared modules (cross-platform)
    ../../../shared/shell-aliases.nix
    ../../../shared/opencode.nix
    ../../../shared/opencode-profile.nix
    ../../../shared/sops.nix
    inputs.sops-nix.homeManagerModules.sops

    # ShellGPT enabled
    ({ home.shell-gpt.enable = true; })
  ];

  # Use SSH host key for sops decryption (matches host_rog in .sops.yaml).
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Disable omarchy's zsh extras that conflict with shell.nix prezto setup.
  programs.zsh.zplug.enable = lib.mkForce false;
  programs.starship.enable = lib.mkForce false;

  # Disable HM-level fontconfig -- rely on system-level fonts.nix.
  fonts.fontconfig.enable = lib.mkForce false;

  # Override active OpenCode provider for this host
  home.opencode.activeProviderName = "opencode-go-medium";
}
