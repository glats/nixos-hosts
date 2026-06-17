{ config, ... }:

{
  programs.ghostty = {
    enable = true;
    settings = {
      theme = "nix-colors";
      font-family = "CaskaydiaCove Nerd Font";
      font-size = 11;
      font-feature = "+liga";
      background-opacity = 0.8;
      maximize = true;
      scrollback-limit = 4294967295;
      window-padding-balance = true;
      window-padding-color = "extend";
    };

    themes.nix-colors = {
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
      selection-foreground = "#${config.colorScheme.palette.base00}";
    };
  };
}
