{ config, ... }:

{
  programs.kitty = {
    enable = true;
    font = {
      name = "CaskaydiaCove Nerd Font";
      size = 11;
    };
    settings = {
      background_opacity = "0.6";
      background_tint = "0.2";
      scrollback_lines = -1;
      cursor_shape = "block";
      disable_ligatures = "never";

      background = "#${config.colorScheme.palette.base00}";
      foreground = "#${config.colorScheme.palette.base05}";
      cursor = "#${config.colorScheme.palette.base05}";
      selection_background = "#${config.colorScheme.palette.base02}";
      selection_foreground = "#${config.colorScheme.palette.base05}";

      # Normal colors (0-7)
      color0 = "#${config.colorScheme.palette.base00}";
      color1 = "#${config.colorScheme.palette.base08}";
      color2 = "#${config.colorScheme.palette.base0B}";
      color3 = "#${config.colorScheme.palette.base0A}";
      color4 = "#${config.colorScheme.palette.base0D}";
      color5 = "#${config.colorScheme.palette.base0E}";
      color6 = "#${config.colorScheme.palette.base0C}";
      color7 = "#${config.colorScheme.palette.base05}";

      # Bright colors (8-15).  `brightGreen`, `brightYellow`, etc. are
      # present in the project's `shared/palette.nix` (used by rog /
      # thinkcentre / mact2) but absent in standard nix-colors presets
      # (e.g. tokyo-night used on t14).  Fall back to the
      # corresponding base color so the shared module evaluates on
      # any palette.
      color8 = "#${config.colorScheme.palette.base03}";
      color9 = "#${config.colorScheme.palette.base09}";
      color10 = "#${config.colorScheme.palette.brightGreen or config.colorScheme.palette.base0B}";
      color11 = "#${config.colorScheme.palette.brightYellow or config.colorScheme.palette.base0A}";
      color12 = "#${config.colorScheme.palette.brightBlue or config.colorScheme.palette.base0D}";
      color13 = "#${config.colorScheme.palette.brightMagenta or config.colorScheme.palette.base0E}";
      color14 = "#${config.colorScheme.palette.brightCyan or config.colorScheme.palette.base0C}";
      color15 = "#${config.colorScheme.palette.base07}";
    };
  };
}
