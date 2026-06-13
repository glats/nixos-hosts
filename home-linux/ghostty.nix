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
        # `brightGreen`, `brightYellow`, etc. are present in the
        # project's `shared/palette.nix` (used by rog / thinkcentre /
        # mact2) but absent in standard nix-colors presets
        # (e.g. tokyo-night used on t14).  Fall back to the
        # corresponding base color so the shared module evaluates on
        # any palette.
        "10=#${config.colorScheme.palette.brightGreen or config.colorScheme.palette.base0B}"
        "11=#${config.colorScheme.palette.brightYellow or config.colorScheme.palette.base0A}"
        "12=#${config.colorScheme.palette.brightBlue or config.colorScheme.palette.base0D}"
        "13=#${config.colorScheme.palette.brightMagenta or config.colorScheme.palette.base0E}"
        "14=#${config.colorScheme.palette.brightCyan or config.colorScheme.palette.base0C}"
        "15=#${config.colorScheme.palette.base07}"
      ];
      background = "#${config.colorScheme.palette.base00}";
      foreground = "#${config.colorScheme.palette.base05}";
      cursor-color = "#${config.colorScheme.palette.base05}";
      selection-background = "#${config.colorScheme.palette.base02}";
    };
  };
}
