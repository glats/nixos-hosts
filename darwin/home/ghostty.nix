# Darwin Ghostty terminal configuration.
# Imports shared ghostty settings + palette. Adds darwin-specific overrides:
# macos-option-as-alt, selection-foreground = base00, package = null (brew).
{ config, ... }:
let
  ghostty = import ../../shared/ghostty.nix {
    colorScheme = config.colorScheme;
    selectionForegroundPalette = "base00";
    extraSettings = { macos-option-as-alt = "left"; };
  };
in
{
  programs.ghostty = {
    enable = true;
    package = null;
    settings = ghostty.settings;
    themes = ghostty.theme;
  };
}
