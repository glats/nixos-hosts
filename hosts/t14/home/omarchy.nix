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
    # kitty.nix is imported via ./default.nix (which transitively
    # re-imports the shared home-linux/kitty.nix because omarchy-nix
    # does not include it).
    # Ghostty is owned by `home-linux/ghostty.nix` (the single source
    # of truth across all Linux hosts).  The shared file uses
    # `lib.mkForce` on `programs.ghostty.themes` to drop omarchy's
    # `themes.omarchy`, and the import order makes per-key settings
    # resolve in favor of the shared file.  `./ghostty.nix` only adds
    # t14-specific hardware tweaks (background-opacity, async-backend,
    # mouse-scroll-multiplier) on top.
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
    # btop is imported directly from home-linux/ to override
    # omarchy-nix's own btop module.  The shared file uses `lib.mkForce`
    # on every `programs.btop.settings.*` key, so omarchy's values for
    # the same keys are dropped at eval time.  This keeps rog /
    # thinkcentre / t14 visually identical (one source of truth).
    ../../../home-linux/btop.nix

    # OpenCode stack
    ../../../shared/opencode.nix
    ../../../shared/opencode-profile.nix
    ../../../shared/sops.nix
    inputs.sops-nix.homeManagerModules.sops
  ];

  # Use SSH host key for sops decryption (matches host_t14 in .sops.yaml).
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Disable omarchy's zsh extras that conflict with shell.nix prezto setup.
  # rog/thinkcentre use pure prezto (no starship, no zplug). Match them.
  programs.zsh.zplug.enable = lib.mkForce false;
  programs.starship.enable = lib.mkForce false;

  # Disable HM-level fontconfig — rely on system-level fonts.nix (same as rog).
  # omarchy-nix's HM fonts module overrides defaults with different fonts;
  # rog/thinkcentre only use the system-level config from modules/desktop/fonts.nix.
  fonts.fontconfig.enable = lib.mkForce false;

  # Set icon theme explicitly — omarchy-nix manages gtk.theme and gtk.cursorTheme
  # but does NOT set gtk.iconTheme. Papirus-Dark is already installed system-wide
  # (via modules/base/profiles/base.nix) but never activated on t14 because
  # home-linux/theme.nix is excluded (omarchy owns the visual layer).
  gtk.iconTheme = {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme;
  };

  # Enable dark mode entries for both GTK3 and GTK4 settings.ini.
  # Without this, GTK4 settings.ini has no gtk-theme-name (HM 26.05
  # silences gtk4.theme by default) and no gtk-application-prefer-dark-theme.
  # Nautilus (libadwaita) reads these to determine dark mode.
  gtk.colorScheme = "dark";

  # Fix: home-manager escribe gtk-interface-color-scheme=2 (integer) pero
  # GTK4 espera el string "dark" — sin esto libadwaita ignora el dark mode.
  gtk.gtk4.extraConfig."gtk-interface-color-scheme" = "dark";
}
