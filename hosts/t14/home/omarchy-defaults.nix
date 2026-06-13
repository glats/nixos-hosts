# T14 Home Manager — DEFAULTS ONLY (no personalizations).
#
# This is the minimal Omarchy configuration. Only the upstream
# omarchy-nix homeManagerModules.default is imported. No t14 overlays,
# no custom themes, no shared home-linux modules.
#
# Goal: make Omarchy defaults work first. Personalizations will be
# re-added later once the base is stable.
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    # Omarchy HM module — provides everything: Hyprland, waybar, walker,
    # ghostty, alacritty, kitty, btop, zsh, tmux, neovim, git, starship,
    # theme-switcher, etc. This is the ONLY import for the defaults-only
    # configuration.
    inputs.omarchy-nix.homeManagerModules.default

    # OpenCode stack (shared with rog/thinkcentre)
    ../../../shared/opencode.nix
    ../../../shared/opencode-profile.nix
    ../../../shared/sops.nix
    inputs.sops-nix.homeManagerModules.sops
  ];

  # Hyprland input: latam keyboard layout (t14-specific)
  wayland.windowManager.hyprland.settings.input = {
    kb_layout = "latam";
    kb_variant = "";
  };

  # Required by Home Manager
  home.stateVersion = "25.05";
}
