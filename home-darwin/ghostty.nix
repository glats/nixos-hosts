# Darwin Ghostty terminal configuration.
# Migrated from raw dotfile text to programs.ghostty HM module,
# matching home-linux/ghostty.nix pattern.
# Keeps darwin-specific overrides: macos-option-as-alt, selection-foreground.
{ config, ... }:
{
  programs.ghostty = {
    enable = true;
    # Set to null because ghostty's flake does not provide a `default` package
    # for `x86_64-darwin` (Intel Mac). The HM module gracefully skips
    # package-dependent features (home.packages, config validation) when
    # package is null while still writing settings and themes via xdg.configFile.
    # Ghostty is installed via Homebrew on this host.
    package = null;
    settings = {
      bold-color = "bright";
      background-opacity = 0.8;
      clipboard-paste-protection = false;
      clipboard-write = "allow";
      font-family = "CaskaydiaCove Nerd Font";
      font-feature = "+liga";
      font-size = 11;
      keybind = [
        "shift+insert=paste_from_clipboard"
      ];
      macos-option-as-alt = "left";
      maximize = true;
      scrollback-limit = 4294967295;
      term = "xterm-256color";
      theme = "nix-colors";
      window-padding-balance = true;
      window-padding-color = "extend";
    };

    themes = {
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
          # Bright (8-15)
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
  };
}
