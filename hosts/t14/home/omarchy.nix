# T14 Home Manager — Omarchy HM entry point.
#
# Replaces the previous home/gnome.nix. This module wires the
# omarchy-nix homeManagerModules.default alongside the t14-specific
# overlays already present in home/default.nix.
#
# Selective shared-module imports:
#   * Imported: shell, git, ssh, neovim, tmux, opencode, sops, base
#     (matches what the old gnome.nix preserved).
#   * Excluded:  theme (omarchy owns GTK/Qt theming via nix-colors),
#                ghostty (t14/home/default.nix sets it via mkDefault),
#                kitty (omarchy supplies its own kitty module),
#                rofi (omarchy uses walker instead),
#                mate (GNOME/MATE only — incompatible with Hyprland),
#                chrome-apps (webapps are managed by omarchy webapp
#                tooling; the home-linux list is for rog/thinkcentre).
#
# The omarchy HM module is imported FIRST so that any conflicting
# definitions from t14/home/default.nix can be overridden via mkDefault.
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    # Omarchy HM module — supplies Hyprland overlays, waybar, walker,
    # elephant, ghostty, alacritty, kitty, starship, btop, neovim, fcitx5,
    # and all the user-level defaults.  Imported first so subsequent
    # t14-specific fragments can override.
    inputs.omarchy-nix.homeManagerModules.default

    # t14-specific overlays on top of omarchy.
    ./default.nix
    ./starship.nix
    ./elephant.nix
    ./alacritty.nix
    ./kitty.nix
    ./fcitx5.nix

    # Compatible shared modules from home-linux/.  These are the same
    # modules the previous gnome.nix imported; we keep them so that
    # shell, git, ssh, neovim, tmux, opencode, and sops survive the
    # migration.
    ../../../home-linux/base.nix
    ../../../home-linux/shell.nix
    ../../../home-linux/tmux.nix
    ../../../home-linux/neovim.nix
    ../../../home-linux/git.nix
    ../../../home-linux/gh.nix
    ../../../home-linux/ssh.nix

    # OpenCode stack
    ../../../shared/opencode.nix
    ../../../shared/opencode-profile.nix
    ../../../shared/sops.nix
    inputs.sops-nix.homeManagerModules.sops
  ];

  # Use SSH host key for sops decryption (matches host_t14 in .sops.yaml).
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # ====================================================================
  # Custom "glats" theme deployment.
  # ====================================================================
  # The omarchy.theme NixOS option is "tokyo-night" (it must be in the
  # upstream enum). Omarchy's theme runtime loads from
  # ~/.config/omarchy/current/theme/. The theme-switcher resolves the
  # "current" symlink to one of the entries in ~/.config/omarchy/themes/.
  # By placing a "glats" directory in ~/.config/omarchy/themes/ and
  # pointing "current" at it, we can ship our own visual identity
  # without forking omarchy-nix.
  #
  # The theme files (waybar.css, hyprland.conf, ghostty-theme, btop.theme,
  # backgrounds/) are deployed by the xdg.configFile entries below.
  xdg.configFile = {
    # Glats theme — applied by the user via `omarchy-theme-set glats`
    # (or by setting omarchy.theme = "tokyo-night" and symlinking
    # current -> glats). The theme files live under themes/glats/.
    "omarchy/themes/glats" = {
      source = ./themes/glats;
      recursive = true;
    };

    # Ghostty custom 16-color palette (separate from omarchy themes
    # because ghostty is invoked directly with --theme=glats).
    "ghostty/themes/glats" = {
      source = ./ghostty-themes/glats;
    };
  };
}
