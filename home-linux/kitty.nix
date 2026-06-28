# Single source of truth for kitty config on every Linux host
# (t14, rog, thinkcentre).
#
# Mirrors the proven `home-linux/ghostty.nix` pattern: wrap
# `programs.kitty.settings` in `lib.mkForce` so on t14 the entire
# attrset replaces whatever omarchy-nix contributed. Every key this
# file does not define (omarchy's `include`, opacity 0.95, etc.) is
# dropped on t14, producing byte-identical kitty config across
# rog / thinkcentre / t14.
#
# `enable` and `font.name` are intentionally NOT set here:
#   - t14: omarchy-nix sets `enable = mkDefault true` and
#     `font.name = mkDefault cfg.fonts.kitty` (overridden in
#     `hosts/t14/home/omarchy.nix` to "CaskaydiaCove Nerd Font").
#   - rog / thinkcentre: do NOT import omarchy-nix. Verify that
#     kitty is still enabled (HM default for `programs.kitty.enable`
#     is false; on those hosts kitty will be disabled and the rest
#     of this file is dormant). If that's wrong, add
#     `enable = lib.mkDefault true;` back.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.kitty = {
    settings = lib.mkForce {
      # User preferences
      background_opacity = "0.6";
      background_tint = "0.2";
      scrollback_lines = -1;
      cursor_shape = "block";
      disable_ligatures = "never";

      # Omarchy defaults that must be re-declared inside mkForce
      # or they get dropped on t14.
      window_padding_width = 10;
      repaint_delay = 10;
      input_delay = 3;
      sync_to_monitor = "yes";

      # Special colors
      background = "#${config.colorScheme.palette.base00}";
      foreground = "#${config.colorScheme.palette.base05}";
      cursor = "#${config.colorScheme.palette.base05}";
      selection_background = "#${config.colorScheme.palette.base02}";
      selection_foreground = "#${config.colorScheme.palette.base00}";

      # Normal colors (0-7)
      color0 = "#${config.colorScheme.palette.base00}";
      color1 = "#${config.colorScheme.palette.base08}";
      color2 = "#${config.colorScheme.palette.base0B}";
      color3 = "#${config.colorScheme.palette.base0A}";
      color4 = "#${config.colorScheme.palette.base0D}";
      color5 = "#${config.colorScheme.palette.base0E}";
      color6 = "#${config.colorScheme.palette.base0C}";
      color7 = "#${config.colorScheme.palette.base05}";

      # Bright colors (8-15) — standard base16 mapping, reuses baseXX
      color8 = "#${config.colorScheme.palette.base03}";
      color9 = "#${config.colorScheme.palette.base08}";
      color10 = "#${config.colorScheme.palette.base0B}";
      color11 = "#${config.colorScheme.palette.base0A}";
      color12 = "#${config.colorScheme.palette.base0D}";
      color13 = "#${config.colorScheme.palette.base0E}";
      color14 = "#${config.colorScheme.palette.base0C}";
      color15 = "#${config.colorScheme.palette.base07}";

      # Extended 256-color space (16-21)
      color16 = "#${config.colorScheme.palette.base09}";
      color17 = "#${config.colorScheme.palette.base0F}";
      color18 = "#${config.colorScheme.palette.base01}";
      color19 = "#${config.colorScheme.palette.base02}";
      color20 = "#${config.colorScheme.palette.base04}";
      color21 = "#${config.colorScheme.palette.base06}";
    };

    # Override omarchy's `mkDefault 12` with our 11. Standalone
    # mkForce (not inside settings) because `font.size` is a
    # separate attr from `settings` in the HM kitty module.
    font.size = lib.mkForce 11;

    keybindings = {
      "kitty_mod+f10" = "toggle_maximized";
    };
  };

  xdg.dataFile."applications/kitty.desktop".text = ''
    [Desktop Entry]
    Name=Kitty
    Comment=Fast, feature-rich terminal emulator
    Exec=${pkgs.kitty}/bin/kitty --start-as maximized %U
    Icon=kitty
    Type=Application
    Categories=System;TerminalEmulator;
    Terminal=false
    StartupNotify=true
    StartupWMClass=kitty
  '';
}
