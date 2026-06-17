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
    ./elephant.nix
    ./alacritty.nix
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
  # Ghostty theme override.
  # ====================================================================
  # Omarchy's theme runtime deploys theme files to
  # ~/.config/omarchy/current/theme/ and ghostty uses the "glats"
  # theme by reference (invoked with --theme=glats).  We deploy a
  # custom 16-color palette at ~/.config/ghostty/themes/glats so
  # ghostty finds the theme regardless of what omarchy's runtime
  # symlink points at.
  xdg.configFile = {
    "ghostty/themes/glats" = {
      source = ./ghostty-themes/glats;
    };
  };

  # ====================================================================
  # Override resolution: let omarchy-nix deploy recursive sources (e.g.
  # ~/.config/waybar/indicators/) while we override individual files.
  # ====================================================================
  home.fileOverlapResolution = "override";

  # ====================================================================
  # Silences hyprland.configType migration warning.
  # 25.05 (< 26.05) defaults to "hyprlang"; explicit opt-in keeps current
  # behavior and suppresses the eval warning.
  wayland.windowManager.hyprland.configType = "hyprlang";

  # ====================================================================
  # Suppress omarchy's recursive home.file sources.
  # ====================================================================
  # The omarchy-nix HM module ships waybar via
  #   home.file.".config/waybar/" = { source = ...; recursive = true; }
  # and walker via programs.walker.settings which writes to
  # home.file.".config/walker/config.toml".  Both are designed to be
  # overridden from user configs.
  #
  # Two layering details make this tricky:
  #
  # 1. lib.mkForce on individual child paths (e.g. .config/waybar/config)
  #    is not enough.  Home Manager's home-file build script uses
  #    `home.fileOverlapResolution = "ignore"` by default, which keeps
  #    the recursively linked file and silently discards any later
  #    non-recursive entry that targets the same path.  We confirmed
  #    this empirically: omarchy's `config` and `style.css` remain at
  #    ~/.config/waybar/ even after rebuild, and the user's
  #    `config.jsonc` is inert at runtime (waybar's loader checks
  #    `config` before `config.jsonc`).
  #
  # 2. Setting `home.fileOverlapResolution = "override"` builds the
  #    `home-manager-files.drv` correctly but the build script's
  #    `rm` fails with Permission denied on the read-only Nix store
  #    paths that `lndir` created, causing the build to abort.
  #
  # The cleanest fix is to override the PARENT recursive entry with
  # lib.mkForce and replace it with our own non-recursive source that
  # contains only the files the user actually wants at runtime. The
  # `indicators/` subdirectory omarchy ships in config/waybar/ is not
  # referenced by the user's config.jsonc (it uses
  # $OMARCHY_PATH/default/waybar/indicators/ instead), so dropping it
  # is safe. The theme.css symlink omarchy writes via xdg.configFile
  # is unaffected by this override (different attribute path).
  #
  # The waybar-t14/ directory mirrors the layout omarchy expects at
  # ~/.config/waybar/ but contains only the user's files. We use a
  # dedicated subdirectory (rather than symlinking) to keep the
  # override atomic: any future addition to the user's waybar config
  # is a single-file edit + flake rebuild.
  #
  # Reference: see waybar-t14/config.jsonc for the $OMARCHY_PATH and
  # ~/.config/hypr/kb-layout.sh script references. Those scripts are
  # deployed by hosts/t14/home/default.nix to
  # ~/.local/share/omarchy/bin/ (not ~/.config/hypr/), so the
  # exec/on-click targets in the user's config resolve via the
  # existing PATH (kb-toggle.sh) or via the symlink
  # ~/.config/hypr/kb-layout.sh that default.nix also deploys.
  home.file = {
    # Override specific waybar files while letting omarchy-nix deploy
    # the indicators/ directory and other files.
    # Uses home.fileOverlapResolution = "override" (set above) to merge.
    ".config/waybar/config".text = builtins.readFile ./waybar-t14/config.jsonc;
    ".config/waybar/style.css".source = ./waybar-t14/style.css;

    # The omarchy HM module ships walker/config.toml via home.file
    # (programs.walker.settings writes a file at the same path).
    # Override it with the user's personal walker config.  No
    # recursive source to fight here, so a plain lib.mkForce on the
    # specific target is enough.
    ".config/walker/config.toml" = lib.mkForce {
      source = ./walker-config.toml;
    };

    # ==================================================================
    # PATH injection for the systemd user manager.
    # ==================================================================
    # Why: omarchy-nix exposes 160+ helper scripts in
    # `~/.local/share/omarchy/bin` (omarchy-launch-walker,
    # omarchy-hyprland-monitor-watch, omarchy-battery-monitor, etc.).
    # Home Manager's `home.sessionPath` only injects the directory
    # into the shell-sourced `hm-session-vars.sh` — it does NOT
    # propagate to the systemd user manager's environment, which is
    # where the `uwsm_app-daemon` lives. The daemon inherits its
    # PATH from the systemd user manager, so when Hyprland invokes
    # `uwsm-app -- <bare-name>` for any omarchy helper, the daemon's
    # `which()` returns None and it raises `Command not found`,
    # surfacing as a "App failure" mako notification.
    #
    # environment.d(5) is the systemd-supported way to inject env
    # vars into the user service manager. Files are read in
    # lexicographic order, so `99-` (highest in this prefix range)
    # ensures this PATH wins over `10-home-manager.conf`. The value
    # references the upstream `$PATH` (literal, no shell expansion —
    # systemd parses the file directly), prepending the omarchy bin
    # directory so the daemon can resolve every helper.
    "environment.d/99-omarchy-path.conf".text = ''
      PATH=/home/glats/.local/share/omarchy/bin:$PATH
    '';
  };
}
