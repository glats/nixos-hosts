# Home config temporal para t14 con GNOME.
# Solo lo mínimo mientras migramos a Hyprland+Omarchy.
# Endgame: ver t14-context.md Phase 1.
{ config, pkgs, ... }:

{
  imports = [
    ../../../home-linux/base.nix
    ../../../home-linux/shell.nix
    ../../../home-linux/theme.nix
    ../../../home-linux/tmux.nix
    ../../../home-linux/neovim.nix
    ../../../home-linux/git.nix
    ../../../home-linux/ssh.nix
  ];

  # NO importar en esta fase: mate, rofi, btop, ghostty, kitty,
  # gh, opencode-profile, openfang, chrome-apps, sops, conky-*,
  # waybar. Todo eso viene con Hyprland/Omarchy.
  # theme.nix está incluido porque tmux.nix referencia config.colorScheme.
}
