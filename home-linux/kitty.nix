# Single source of truth for kitty config on every Linux host
# (t14, rog, thinkcentre).
#
# Mirrors the proven `home-linux/ghostty.nix` pattern: wrap
# `programs.kitty.settings` in `lib.mkDefault` so on t14 the
# attrset merges with whatever omarchy-nix contributed (via
# attrset union). Keys unique to either side survive; keys
# with matching values merge cleanly; `include` (declared only
# by omarchy-nix) survives — enabling `omarchy-theme-set` to
# recolor kitty at runtime without a rebuild.
#
# The natural attrset merge in NixOS module system rejects
# equal-priority scalar conflicts rather than picking a winner.
# Since both modules also declare `window_padding_width`,
# `repaint_delay`, `input_delay`, `sync_to_monitor`, and
# `background_opacity` at `mkDefault`, we use `lib.mkForce`
# inline on `background_opacity` so the nixos-hosts value
# ("0.9") wins on every host. The other four keys happen to
# match between omarchy-nix and nixos-hosts, so they merge
# without conflict.
#
# omarchy-nix's keybindings (`ctrl+insert` → copy,
# `shift+insert` → paste) are additive to nixos-hosts's
# `kitty_mod+f10` → maximize and merge via attrset union.
#
# On rog / thinkcentre, no omarchy-nix is imported, so
# `lib.mkDefault` on `settings` is the effective priority and
# the resulting kitty config is byte-identical to a
# `mkForce`-style layout (minus the inline `mkForce` on
# `background_opacity`, which is a no-op without a competitor).
#
# `enable` and `font.name` use `lib.mkDefault` so:
#   - t14: omarchy-nix's `mkDefault` for both is overridden by
#     `omarchy.fonts.kitty = "CaskaydiaCove Nerd Font"` (set in
#     `hosts/t14/home/omarchy.nix`). `lib.mkDefault` on `settings`
#     merges omarchy defaults in alongside nixos-hosts's keys.
#   - rog / thinkcentre: no omarchy-nix — `lib.mkDefault` is the
#     effective value. Both hosts get CaskaydiaCove 11, same
#     settings, byte-identical config.
{ config
, lib
, pkgs
, ...
}:

{
  programs.kitty = {
    enable = lib.mkDefault true;

    settings = lib.mkDefault {
      # User preferences
      # background_opacity is lib.mkForce so the 0.9 value wins on
      # t14 too (omarchy-nix's mkDefault "0.95" would otherwise
      # conflict at equal priority and fail evaluation).
      background_opacity = lib.mkForce "0.9";
      background_tint = "0.2";
      scrollback_lines = -1;
      cursor_shape = "block";
      disable_ligatures = "never";

      # Padding / delay / sync keys are also declared by
      # omarchy-nix. Re-declared here so nixos-hosts's values win
      # via later-import priority at the same mkDefault level.
      window_padding_width = 0;
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
    font = {
      name = lib.mkDefault "CaskaydiaCove Nerd Font";
      size = lib.mkForce 11;
    };

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
