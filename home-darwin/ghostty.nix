{ config, ... }:
{
  # Manage Ghostty configuration declaratively (Application Support)
  home.file."Library/Application Support/com.mitchellh.ghostty/config".text = ''
    theme = customColor
    font-family = "CaskaydiaCove Nerd Font"
    font-feature = "liga"
    background-opacity = 0.8
    clipboard-write = allow
    scrollback-limit = 4294967295
    window-padding-balance = true
    window-padding-color = extend
    macos-option-as-alt = left
  '';

  # Custom Ghostty theme — standard base16 22-color ANSI mapping
  home.file.".config/ghostty/themes/customColor".text = ''
    # Normal (0-7)
    palette = 0=#${config.colorScheme.palette.base00}
    palette = 1=#${config.colorScheme.palette.base08}
    palette = 2=#${config.colorScheme.palette.base0B}
    palette = 3=#${config.colorScheme.palette.base0A}
    palette = 4=#${config.colorScheme.palette.base0D}
    palette = 5=#${config.colorScheme.palette.base0E}
    palette = 6=#${config.colorScheme.palette.base0C}
    palette = 7=#${config.colorScheme.palette.base05}
    # Bright (8-15) — standard reuses same colors as normal
    palette = 8=#${config.colorScheme.palette.base03}
    palette = 9=#${config.colorScheme.palette.base08}
    palette = 10=#${config.colorScheme.palette.base0B}
    palette = 11=#${config.colorScheme.palette.base0A}
    palette = 12=#${config.colorScheme.palette.base0D}
    palette = 13=#${config.colorScheme.palette.base0E}
    palette = 14=#${config.colorScheme.palette.base0C}
    palette = 15=#${config.colorScheme.palette.base07}
    # Extended 256-color space (16-21)
    palette = 16=#${config.colorScheme.palette.base09}
    palette = 17=#${config.colorScheme.palette.base0F}
    palette = 18=#${config.colorScheme.palette.base01}
    palette = 19=#${config.colorScheme.palette.base02}
    palette = 20=#${config.colorScheme.palette.base04}
    palette = 21=#${config.colorScheme.palette.base06}
    background = #${config.colorScheme.palette.base00}
    foreground = #${config.colorScheme.palette.base05}
    cursor-color = #${config.colorScheme.palette.base05}
    selection-background = #${config.colorScheme.palette.base02}
    selection-foreground = #${config.colorScheme.palette.base00}
  '';
}
