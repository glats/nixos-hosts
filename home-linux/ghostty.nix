# Single source of truth for ghostty config on every Linux host
# (t14, rog, thinkcentre).
#
# rog / thinkcentre pick this up transitively via
# `home-linux/shared-modules.nix` -> `flake.nix` linuxHomeModules.
# t14 imports it from `hosts/t14/home/ghostty.nix` (which adds t14
# hardware tweaks on top).
#
# On t14, omarchy-nix's `homeManagerModules.default` also pulls in
# its own `programs.ghostty` block (JetBrainsMono 9, `themes.omarchy`,
# keybinds, padding defaults, etc.).  home-manager's
# `programs.ghostty.settings` type serialises lists of values as
# duplicate TOML keys, so letting the two modules' values merge
# produces lines like:
#
#   font-family = CaskaydiaCove Nerd Font
#   font-family = JetBrainsMono Nerd Font
#
# in `~/.config/ghostty/config` — the visible "duplicate settings"
# bug.  The `lib.mkForce` calls below pin each key this file owns
# to its own value, so omarchy's contribution to the same key is
# dropped at eval time.  Keys this file does not set
# (window-padding-x, cursor-style, keybind, …) keep omarchy's values
# on t14, which is the desired behaviour.
{ config, lib, ... }:

{
  programs.ghostty = {
    enable = true;
    settings = {
      theme = lib.mkForce "nix-colors";
      font-family = lib.mkForce "CaskaydiaCove Nerd Font";
      font-size = lib.mkForce 11;
      font-feature = lib.mkForce "+liga";
      background-opacity = 0.8;
      maximize = lib.mkForce true;
      scrollback-limit = lib.mkForce 4294967295;
      window-padding-balance = lib.mkForce true;
      window-padding-color = lib.mkForce "extend";
    };

    themes = lib.mkForce {
      nix-colors = {
        palette = [
          # Normal (0-7)
          "0=#${config.colorScheme.palette.base00}"
          "1=#${config.colorScheme.palette.base08}"
          "2=#${config.colorScheme.palette.base0B}"
          "3=#${config.colorScheme.palette.base0A}"
          "4=#${config.colorScheme.palette.base0D}"
          "5=#${config.colorScheme.palette.base0E}"
          "6=#${config.colorScheme.palette.base0C}"
          "7=#${config.colorScheme.palette.base05}"
          # Bright (8-15) — standard base16 reuses same colors as normal
          "8=#${config.colorScheme.palette.base03}"
          "9=#${config.colorScheme.palette.base08}"
          "10=#${config.colorScheme.palette.base0B}"
          "11=#${config.colorScheme.palette.base0A}"
          "12=#${config.colorScheme.palette.base0D}"
          "13=#${config.colorScheme.palette.base0E}"
          "14=#${config.colorScheme.palette.base0C}"
          "15=#${config.colorScheme.palette.base07}"
          # Extended 256-color space (16-21)
          "16=#${config.colorScheme.palette.base09}"
          "17=#${config.colorScheme.palette.base0F}"
          "18=#${config.colorScheme.palette.base01}"
          "19=#${config.colorScheme.palette.base02}"
          "20=#${config.colorScheme.palette.base04}"
          "21=#${config.colorScheme.palette.base06}"
        ];
        background = "#${config.colorScheme.palette.base00}";
        foreground = "#${config.colorScheme.palette.base05}";
        cursor-color = "#${config.colorScheme.palette.base05}";
        selection-background = "#${config.colorScheme.palette.base02}";
        selection-foreground = "#${config.colorScheme.palette.base05}";
      };
    };
  };
}
