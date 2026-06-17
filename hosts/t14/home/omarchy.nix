# T14 Home Manager — Omarchy HM entry point.
#
# Replaces the previous home/gnome.nix. This module wires the
# omarchy-nix homeManagerModules.default alongside the t14-specific
# overlays already present in home/default.nix.
#
# The glats theme is handled natively by omarchy-nix via
# `omarchy.theme = "glats"` (see hosts/t14/default.nix).  Previously
# the local t14/home/theme.nix + theme-files.nix pair was required
# to (a) override omarchy's colorScheme with the custom glats palette
# and (b) deploy theme files to ~/.config/omarchy/themes/glats/.
# After the upstream omarchy-nix PR that added native glats support,
# both files were deleted and no local override is needed.
#
# Selective shared-module imports (matches what the old gnome.nix
# preserved):
#   * Imported: base, shell, git, gh, ssh, neovim, tmux, opencode, sops.
#   * Excluded:  rofi (omarchy uses walker instead),
#                mate (GNOME/MATE only — incompatible with Hyprland),
#                chrome-apps (webapps are managed by omarchy webapp
#                tooling; the home-linux list is for rog/thinkcentre),
#                home-linux/theme.nix (it configures GTK/Qt/dconf and
#                `colorScheme = shared/palette.nix`; the former is
#                owned by omarchy and the latter is now driven by
#                omarchy.theme = "glats" too).
#
# The omarchy HM module is imported FIRST so that any conflicting
# definitions from t14/home/default.nix can be overridden via
# lib.mkForce when needed.
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
    # elephant, ghostty, alacritty, kitty, btop, neovim, fcitx5,
    # and all the user-level defaults.  Imported first so subsequent
    # t14-specific fragments can override.
    inputs.omarchy-nix.homeManagerModules.default

    # t14-specific overlays on top of omarchy.
    # ghostty.nix and kitty.nix are imported via ./default.nix (which
    # transitively imports the shared home-linux/ghostty.nix and
    # home-linux/kitty.nix).
    ./default.nix

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


}
