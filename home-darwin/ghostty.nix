{ config, ... }:
{
  # Manage Ghostty configuration declaratively (Application Support)
  home.file."Library/Application Support/com.mitchellh.ghostty/config".text = ''
    theme = customColor
    font-family = "CaskaydiaCove Nerd Font"
    font-feature = "liga"
    background-opacity = 0.8
    scrollback-limit = 4294967295
    window-padding-balance = true
    window-padding-color = extend
    macos-option-as-alt = left
  '';

  # Custom Ghostty theme — formato líneas separadas (Ghostty macOS usa formato flat)
  home.file.".config/ghostty/themes/customColor".text = ''
    palette = 0=#${config.colorScheme.palette.base00}
    palette = 1=#${config.colorScheme.palette.base08}
    palette = 2=#${config.colorScheme.palette.base0B}
    palette = 3=#${config.colorScheme.palette.base0A}
    palette = 4=#${config.colorScheme.palette.base0D}
    palette = 5=#${config.colorScheme.palette.base0E}
    palette = 6=#${config.colorScheme.palette.base0C}
    palette = 7=#${config.colorScheme.palette.base05}
    palette = 8=#${config.colorScheme.palette.base04}
    palette = 9=#${config.colorScheme.palette.base09}
    palette = 10=#${config.colorScheme.palette.brightGreen}
    palette = 11=#${config.colorScheme.palette.brightYellow}
    palette = 12=#${config.colorScheme.palette.brightBlue}
    palette = 13=#${config.colorScheme.palette.brightMagenta}
    palette = 14=#${config.colorScheme.palette.brightCyan}
    palette = 15=#${config.colorScheme.palette.base07}
    background = #${config.colorScheme.palette.base00}
    foreground = #${config.colorScheme.palette.base05}
    cursor-color = #${config.colorScheme.palette.base05}
    selection-background = #${config.colorScheme.palette.base02}
  '';
}
