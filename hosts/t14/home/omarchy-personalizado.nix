# T14 Home Manager — Omarchy HM entry point.
#
# Replaces the previous home/gnome.nix. This module wires the
# omarchy-nix homeManagerModules.default alongside the t14-specific
# overlays already present in home/default.nix.
#
# Selective shared-module imports:
#   * Imported: theme (t14-specific ./theme.nix that ONLY sets
#     `config.colorScheme` from `shared/palette.nix` — the project's
#     glats palette.  We can't import the shared `home-linux/theme.nix`
#     because it also configures GTK/Qt/dconf, which collides with
#     omarchy's `gtk.theme.name = "Adwaita-dark"`.  By scoping the
#     colorScheme assignment to a t14-local module we get the same
#     `config.colorScheme.palette` resolution for
#     t14/home/ghostty.nix, t14/home/kitty.nix, and shared/tmux.nix
#     without fighting omarchy's GTK theming);
#     shell, git, ssh, neovim, tmux, opencode, sops, base
#     (matches what the old gnome.nix preserved).
#   * Excluded:  ghostty (t14/home/ghostty.nix sets it via lib.mkForce
#                so the nix-colors palette wins over omarchy's runtime
#                theme symlink),
#                kitty (t14/home/kitty.nix sets it via lib.mkForce so
#                the colorScheme palette wins over omarchy's `include`),
#                rofi (omarchy uses walker instead),
#                mate (GNOME/MATE only — incompatible with Hyprland),
#                chrome-apps (webapps are managed by omarchy webapp
#                tooling; the home-linux list is for rog/thinkcentre),
#                home-linux/theme.nix (its GTK config collides with
#                omarchy's gtk.theme.name — see ./theme.nix for the
#                colorScheme-only replacement).
#
# The omarchy HM module is imported FIRST so that any conflicting
# definitions from t14/home/default.nix can be overridden via
# lib.mkForce (terminal theme + colors).
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
    # ghostty.nix and kitty.nix are imported via ./default.nix (which
    # transitively imports the shared home-linux/ghostty.nix and
    # home-linux/kitty.nix and uses lib.mkForce to keep the nix-colors
    # palette ahead of omarchy's runtime theme).
    ./default.nix
    ./elephant.nix
    ./alacritty.nix
    ./fcitx5.nix

    # Compatible shared modules from home-linux/.  These are the same
    # modules the previous gnome.nix imported; we keep them so that
    # shell, git, ssh, neovim, tmux, opencode, and sops survive the
    # migration.  We do NOT import the shared `theme.nix` because it
    # also configures GTK/Qt/dconf — those collide with omarchy's
    # own gtk.theme.name = "Adwaita-dark" and would abort evaluation.
    # Instead `./theme.nix` (defined right here) only sets
    # `config.colorScheme` from `shared/palette.nix` (the project's
    # glats palette) — that is the only piece the t14 terminal and
    # tmux overlays actually read from.
    ../../../home-linux/base.nix
    ./theme.nix
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

    # Walker stylesheet for the glats theme — added via a separate
    # home.file entry because the walker.css in themes/glats/ is
    # tracked in git only after the user commits it; until then the
    # recursive source = ./themes/glats pickup misses it. Once the
    # user commits walker.css this entry is redundant but harmless
    # (it writes the same file to the same target).
    "omarchy/themes/glats/walker.css" = {
      source = ./themes/glats/walker.css;
    };

    # Ghostty custom 16-color palette (separate from omarchy themes
    # because ghostty is invoked directly with --theme=glats).
    "ghostty/themes/glats" = {
      source = ./ghostty-themes/glats;
    };
  };

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
    # Suppress omarchy's `home.file.".config/waybar/"` recursive
    # source entirely.  The replacement source contains only the
    # files the user wants at runtime (config.jsonc, style.css).
    ".config/waybar/" = lib.mkForce {
      source = ./waybar-t14;
      recursive = true;
    };

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
