{ config, ... }:

{
  programs.kitty = {
    enable = true;
    font = {
      name = "CaskaydiaCove Nerd Font";
      size = 11;
    };
    settings = {
      background_opacity = "0.8";
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

      # Bright colors (8-15)
      color8 = "#${config.colorScheme.palette.base03}";
      color9 = "#${config.colorScheme.palette.base09}";
      color10 = "#${config.colorScheme.palette.brightGreen}";
      color11 = "#${config.colorScheme.palette.brightYellow}";
      color12 = "#${config.colorScheme.palette.brightBlue}";
      color13 = "#${config.colorScheme.palette.brightMagenta}";
      color14 = "#${config.colorScheme.palette.brightCyan}";
      color15 = "#${config.colorScheme.palette.base07}";
    };
  };
}
