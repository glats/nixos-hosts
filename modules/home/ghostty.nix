{ config, ... }:

{
  programs.ghostty = {
    enable = true;
    settings = {
      theme = "nix-colors";
      font-family = "CaskaydiaCove Nerd Font";
      font-feature = "+liga";
      background-opacity = 0.8;
      maximize = true;
      scrollback-limit = 4294967295;
      window-padding-balance = true;
      window-padding-color = "extend";
    };

    themes.nix-colors = {
      palette = [
        "0=#${config.colorScheme.palette.base00}"
        "1=#${config.colorScheme.palette.base08}"
        "2=#${config.colorScheme.palette.base0B}"
        "3=#${config.colorScheme.palette.base0A}"
        "4=#${config.colorScheme.palette.base0D}"
        "5=#${config.colorScheme.palette.base0E}"
        "6=#${config.colorScheme.palette.base0C}"
        "7=#${config.colorScheme.palette.base05}"
        "8=#${config.colorScheme.palette.base03}"
        "9=#${config.colorScheme.palette.base09}"
        "10=#${config.colorScheme.palette.brightGreen}"
        "11=#${config.colorScheme.palette.brightYellow}"
        "12=#${config.colorScheme.palette.brightBlue}"
        "13=#${config.colorScheme.palette.brightMagenta}"
        "14=#${config.colorScheme.palette.brightCyan}"
        "15=#${config.colorScheme.palette.base07}"
      ];
      background = "#${config.colorScheme.palette.base00}";
      foreground = "#${config.colorScheme.palette.base05}";
      cursor-color = "#${config.colorScheme.palette.base05}";
      selection-background = "#${config.colorScheme.palette.base02}";
    };
  };
}
