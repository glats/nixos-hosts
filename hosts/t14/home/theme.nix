# T14-specific theme module.
#
# Sets `config.colorScheme` from `shared/palette.nix` (the project's
# glats palette), and forces the GTK/Qt/dconf visual settings that
# the shared `home-linux/theme.nix` normally provides, but which
# we cannot import wholesale on t14 (see the "Why this module exists"
# section below).
#
# Why this module exists:
#   * `t14/home/ghostty.nix`, `t14/home/kitty.nix`, and
#     `shared/tmux.nix` all read `config.colorScheme.palette` to
#     resolve their colors.
#   * Without this module, `config.colorScheme` falls back to
#     whatever omarchy's `inputs.nix-colors.colorSchemes.${theme}`
#     produces (currently tokyo-night), so the terminal palettes and
#     tmux status colors do not match the project's glats palette.
#   * Omarchy's home-manager module sets `gtk.theme.name = "Adwaita-dark"`
#     and ships no icon theme.  The shared `home-linux/theme.nix` sets
#     `gtk.theme.name = "adw-gtk3-dark"` and
#     `gtk.iconTheme.name = "Papirus-Dark"`, but importing it directly
#     would conflict with omarchy's GTK theming and abort evaluation.
#     So we use `lib.mkForce` on each individual attribute to override
#     omarchy's defaults without replacing the whole module.
#
# Why `lib.mkForce` on the whole `colorScheme` attrset:
#   Omarchy's `homeManagerModules.default` already sets
#   `colorScheme = selectedColorScheme` for the active omarchy theme
#   (e.g. tokyo-night).  When we ALSO set `colorScheme` here at the
#   same priority, Nix's per-key attribute merging concatenates the
#   string values inside `palette` (e.g. `1A1B26` from tokyo-night +
#   `000000` from glats = `1A1B26000000`, 12 chars) — which then
#   breaks every consumer that calls
#   `nix-colors.lib.conversions.hexToRGB` on the result.  `lib.mkForce`
#   bumps our definition's priority above omarchy's, so the merge
#   short-circuits and the whole `colorScheme` attrset is replaced
#   by our glats palette.
#
# Why `lib.mkForce` on GTK/Qt/dconf attrs (not the whole module):
#   Same reason — omarchy sets `gtk.theme.name`, `gtk.iconTheme.name`,
#   and the dconf `icon-theme` key at default priority.  Using
#   `lib.mkForce` on each individual leaf attribute raises our value's
#   priority above omarchy's while leaving the rest of omarchy's GTK
#   config (cursor, font settings, etc.) untouched.
#
# Why we use `xdg.configFile` for the CSS instead of `gtk3.extraCss`:
#   Omarchy's home-manager module does not enable the `gtk` program
#   (it ships its own theming pipeline via `~/.config/omarchy/current/`).
#   `gtk3.extraCss` would be a no-op because there is no `gtk3` attrset
#   to merge into.  Writing the file directly via `xdg.configFile`
#   sidesteps that entirely — both GTK3 and GTK4 load `gtk.css` from
#   `~/.config/gtk-{3,4}.0/` at runtime, so the CSS takes effect
#   regardless of which home-manager module "owns" the GTK config.
#
# Tradeoffs vs. importing `home-linux/theme.nix`:
#   * rog/thinkcentre (MATE/GNOME hosts) use the shared module
#     unchanged, so they keep their GTK icon theming and unfocused-
#     selection CSS.  t14 does not, because Hyprland's GTK theming
#     runs through omarchy's `~/.config/omarchy/current/theme/` and
#     we ship a `glats` theme directory for that.
#   * Anything in the shared `theme.nix` that reads
#     `config.colorScheme.palette` still works the same way on t14
#     (e.g. `home-linux/rofi.nix`, `home-linux/conky-*.nix`),
#     because this module sets the same `colorScheme` attribute.
{ lib, pkgs, ... }:

{
  colorScheme = lib.mkForce (import ../../../shared/palette.nix);

  # Force GTK3/GTK4 / icon theme overrides on top of omarchy's
  # defaults.  Omarchy sets `gtk.theme.name = "Adwaita-dark"` and
  # `gtk.theme.package = gnome-themes-extra` (the Adwaita package),
  # and ships no icon theme; we want adw-gtk3-dark + Papirus-Dark.
  # adw-gtk3 is required for Nautilus (libadwaita) compatibility —
  # Materia-dark is ignored by libadwaita apps.
  #
  # `gtk.gtk4.theme` is a sub-attrset, not a top-level option — the
  # older flat `gtk4.theme = lib.mkForce ...` form fails with
  # "option `home-manager.users.glats.gtk4' does not exist".
  #
  # `lib.mkForce` is also needed on `package` because the home-manager
  # GTK2/GTK3/GTK4 theme modules share the same `package` option and
  # omarchy defines it at default priority for GTK3; without
  # `mkForce` on `package`, evaluation aborts with "defined multiple
  # times".
  gtk = {
    iconTheme = {
      name = lib.mkForce "Papirus-Dark";
      package = lib.mkForce pkgs.papirus-icon-theme;
    };
    theme = {
      name = lib.mkForce "adw-gtk3-dark";
      package = lib.mkForce pkgs.adw-gtk3;
    };
    gtk2.theme = {
      name = lib.mkForce "adw-gtk3-dark";
      package = lib.mkForce pkgs.adw-gtk3;
    };
    gtk4.theme = lib.mkForce {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
  };

  # ====================================================================
  # Font configuration — override omarchy-nix HM defaults.
  # ====================================================================
  # Omarchy's HM module sets monospace to "Caskaydia Mono Nerd Font"
  # via fonts.fontconfig.defaultFonts. Our system-level fonts.nix uses
  # "CaskaydiaCove Nerd Font". We force the HM defaults to match the
  # system, and deploy granular conf.d files (matching the user's Arch
  # disk) that use binding="strong" for reliable font resolution.
  fonts.fontconfig.defaultFonts = {
    monospace = lib.mkForce [
      "CaskaydiaCove Nerd Font"
      "Noto Sans Mono"
    ];
    serif = lib.mkForce [
      "Source Sans 3"
      "Noto Serif"
    ];
    sansSerif = lib.mkForce [
      "Source Sans 3"
      "Noto Sans"
    ];
    emoji = lib.mkForce [
      "JoyPixels"
      "Noto Color Emoji"
    ];
  };

  # Border-radius override (titlebar / window-frame only) +
  # granular fontconfig conf.d files.
  # Using `xdg.configFile` instead of `gtk.extraCss` because omarchy
  # doesn't enable the `gtk` home-manager program.
  xdg.configFile = {
    # GTK border-radius — sourced from the Arch disk config.
    "gtk-3.0/gtk.css".text = ''
      .titlebar, .titlebar .background, .window-frame, .window-frame:backdrop, decoration, window, window.background, window.titlebar {
          border-radius: 0px;
          box-shadow: none; /* Optional: Remove any associated shadow */
      }
    '';
    "gtk-4.0/gtk.css".text = ''
      .titlebar, .titlebar .background, .window-frame, .window-frame:backdrop, decoration, window, window.background, window.titlebar {
          border-radius: 0px;
          box-shadow: none; /* Optional: Remove any associated shadow */
      }
    '';

    # Granular fontconfig conf.d files — mirrors the Arch disk layout.
    # These use binding="strong" to ensure the correct fonts resolve
    # regardless of what other modules set at lower priority.
    "fontconfig/conf.d/61-monospace.conf".text = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <match target="pattern">
          <test name="family" compare="eq">
            <string>monospace</string>
          </test>
          <edit name="family" mode="assign" binding="same">
            <string>CaskaydiaCove Nerd Font</string>
          </edit>
        </match>
        <match target="pattern">
          <test name="family" compare="eq">
            <string>mono</string>
          </test>
          <edit name="family" mode="assign" binding="same">
            <string>CaskaydiaCove Nerd Font</string>
          </edit>
        </match>
        <alias binding="strong">
          <family>monospace</family>
          <prefer>
            <family>CaskaydiaCove Nerd Font</family>
            <family>Symbols Nerd Font</family>
            <family>Symbola</family>
          </prefer>
        </alias>
      </fontconfig>
    '';
    "fontconfig/conf.d/63-sans.conf".text = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <alias binding="strong">
          <family>sans</family>
          <prefer>
            <family>Source Sans 3</family>
            <family>Noto Sans</family>
          </prefer>
        </alias>
      </fontconfig>
    '';
    "fontconfig/conf.d/63-sans-serif.conf".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <alias binding="strong">
          <family>sans-serif</family>
          <prefer>
            <family>Source Sans 3</family>
            <family>Noto Sans</family>
          </prefer>
        </alias>
      </fontconfig>
    '';
    "fontconfig/conf.d/63-serif.conf".text = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <alias binding="strong">
          <family>serif</family>
          <prefer>
            <family>Source Sans 3</family>
            <family>Noto Serif</family>
          </prefer>
        </alias>
      </fontconfig>
    '';
    "fontconfig/conf.d/69-emoji.conf".text = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <alias binding="weak">
          <family>sans-serif</family>
          <prefer>
            <family>JoyPixels</family>
          </prefer>
        </alias>
        <alias binding="weak">
          <family>serif</family>
          <prefer>
            <family>JoyPixels</family>
          </prefer>
        </alias>
        <alias binding="weak">
          <family>monospace</family>
          <prefer>
            <family>JoyPixels</family>
          </prefer>
        </alias>
      </fontconfig>
    '';
  };

  # GTK font — match the Arch disk config.
  gtk.font = lib.mkForce {
    name = "Source Sans 3";
    size = 11;
  };

  # Qt integration: route Qt6 theming through GTK so Qt apps
  # (Krita, Qt5ct, etc.) match the GTK theme.  `gtk2` is deprecated
  # for Qt6; `gtk` is the modern equivalent.
  qt.platformTheme = lib.mkForce "gtk";

  # GNOME/GTK apps read icon theme from dconf.  Force it so non-
  # home-manager-managed apps (Nautilus, etc.) pick up Papirus-Dark
  # and stop falling back to the Adwaita default.  Key name is
  # `icon-theme` (with hyphen) per the gsettings schema.
  dconf.settings."org/gnome/desktop/interface".icon-theme = lib.mkForce "Papirus-Dark";

  # Pin GTK_THEME in the session environment so it overrides any
  # default the toolkit picks at startup.  Without this, GTK apps
  # that read GTK_THEME before the home-manager GTK settings land
  # (e.g. Nautilus spawned from a shell) fall back to Adwaita, which
  # leaks Adwaita-styled window borders even though settings.ini
  # and our CSS both say adw-gtk3-dark.
  home.sessionVariables.GTK_THEME = lib.mkForce "adw-gtk3-dark";
}
