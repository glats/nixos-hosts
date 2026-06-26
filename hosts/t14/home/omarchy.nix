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
{ config
, pkgs
, lib
, inputs
, ...
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
    # Split into the shared theme fragment (also imported via
    # `shared-modules.nix` on rog/thinkcentre) and the t14-specific
    # settings fragment, which `lib.mkForce`s each key.
    ../../../home-linux/btop-theme.nix
    ../../../home-linux/btop-settings.nix
    # Remmina remote-desktop clients + connection files.  rog and
    # thinkcentre get this transitively via modules/base/home-manager.nix,
    # but t14 has its own curated import list and must include it
    # explicitly to deploy ~/.config/remmina and the .desktop launchers.
    ../../../home-linux/remote-desktop.nix

    # Shared shell aliases (now extracted from home-linux/shell.nix)
    ../../../shared/shell-aliases.nix

    # OpenCode stack
    ../../../shared/opencode.nix
    ../../../shared/opencode-profile.nix
    ({ home.opencode.activeProviderName = "opencode-go"; })
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

  # Omarchy-nix's tmux module is "neutralized" by home-linux/tmux.nix
  # (imported above): it uses `lib.mkForce` on `programs.tmux.extraConfig`
  # and `programs.tmux.plugins` to drop the omarchy prefix/status/theme
  # at eval time.  We don't need to set `enable = false` here — the
  # merged `enable` from omarchy-nix + shared + home-linux is `true`,
  # and HM's tmux module runs its config block with the home-linux
  # values.  Default C-b prefix + base16 theme from shared/tmux.nix
  # + xclip bindings + vim-tmux-navigator plugin from nixpkgs.

  # Override hypridle timings from upstream omarchy-nix.
  # Upstream sets lock at 151s (1s after screensaver at 150s), which means
  # the lock kills the screensaver before the user can see it.
  # We increase the lock delay to 200s so the screensaver has 50s of visibility.
  services.hypridle.settings = lib.mkForce {
    general = {
      lock_cmd = "omarchy-system-lock";
      before_sleep_cmd = "loginctl lock-session";
      after_sleep_cmd = "hyprctl dispatch dpms on";
      ignore_dbus_inhibit = false;
      inhibit_sleep = 3;
    };
    listener = [
      {
        timeout = 150;
        on-timeout = "pidof hyprlock || omarchy-launch-screensaver";
      }
      {
        timeout = 200; # Was 151 — increased to 200 to give screensaver 50s to show
        on-timeout = "loginctl lock-session";
      }
      {
        timeout = 330;
        on-timeout = "hyprctl dispatch dpms off";
        on-resume = "hyprctl dispatch dpms on && brightnessctl -r";
      }
    ];
  };

  # Kill screensaver when hypridle stops (e.g., via Ctrl+Super+I toggle).
  # Without this, the screensaver keeps running even after idle is disabled.
  systemd.user.services.hypridle.Service.ExecStopPost =
    lib.mkForce "${pkgs.pkgsBuildBuild.bash}/bin/bash -c 'pkill -f omarchy-screensaver 2>/dev/null || true'";

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
