# Shared Ghostty terminal configuration -- pure Nix function, NOT a HM module.
#
# Returns { settings, theme } for platform-specific HM modules to consume.
# Platform differences (macos-option-as-alt, selection-foreground, mkForce)
# are handled by the caller, not via conditionals.
#
# Usage:
#   let ghostty = import ../../shared/ghostty.nix { colorScheme = config.colorScheme; };
#   in { programs.ghostty.settings = ghostty.settings; ... }
{ colorScheme
, selectionForegroundPalette ? "base05"
, extraSettings ? { }
}:
let
  p = colorScheme.palette;
in
{
  settings = extraSettings // {
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
    maximize = true;
    scrollback-limit = 4294967295;
    term = "xterm-256color";
    theme = "nix-colors";
    window-padding-balance = true;
    window-padding-color = "extend";
  };
  theme = {
    nix-colors = {
      palette = [
        "0=#${p.base00}"
        "1=#${p.base08}"
        "2=#${p.base0B}"
        "3=#${p.base0A}"
        "4=#${p.base0D}"
        "5=#${p.base0E}"
        "6=#${p.base0C}"
        "7=#${p.base05}"
        "8=#${p.base03}"
        "9=#${p.base08}"
        "10=#${p.base0B}"
        "11=#${p.base0A}"
        "12=#${p.base0D}"
        "13=#${p.base0E}"
        "14=#${p.base0C}"
        "15=#${p.base07}"
        "16=#${p.base09}"
        "17=#${p.base0F}"
        "18=#${p.base01}"
        "19=#${p.base02}"
        "20=#${p.base04}"
        "21=#${p.base06}"
      ];
      background = "#${p.base00}";
      foreground = "#${p.base05}";
      cursor-color = "#${p.base05}";
      selection-background = "#${p.base02}";
      selection-foreground = "#${p.${selectionForegroundPalette}}";
    };
  };
}
