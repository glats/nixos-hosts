# T14-specific elephant provider config overlays.
#
# Elephant is omarchy's launcher backend (used by walker in calc/dmenu
# modes). Omarchy's HM module deploys default calc.toml and
# desktopapplications.toml via home.file. This module overrides them
# with the user's personal versions using home.file + force = true
# (same mechanism as upstream to avoid cross-mechanism conflicts).
# The symbols.toml override is also included.
{ lib, ... }:

{
  # Override omarchy's default elephant configs with the user's personal
  # versions from the external drive. lib.mkForce is required because the
  # upstream omarchy-nix module also defines these paths via home.file
  # (through programs.walker.elephant). Without mkForce, Nix sees two
  # definitions for the same option path and raises a conflicting-definition
  # error.
  home.file = {
    ".config/elephant/calc.toml" = lib.mkForce {
      source = ./elephant/calc.toml;
    };
    ".config/elephant/desktopapplications.toml" = lib.mkForce {
      source = ./elephant/desktopapplications.toml;
    };
    ".config/elephant/symbols.toml" = lib.mkForce {
      source = ./elephant/symbols.toml;
    };
  };

  # t14-specific unicode symbol extensions for the elephant picker.
  # This adds Latin American accented characters to the top of the
  # SUPER+CTRL+E picker so they appear on the first page.
  xdg.configFile."elephant/symbols-t14.toml".text = ''
    providers = [ "unicode" ]

    [providers.unicode]
    extraSymbols = [
      "á" "é" "í" "ó" "ú"
      "ñ" "ü"
      "Á" "É" "Í" "Ó" "Ú"
      "Ñ" "Ü"
      "¡" "¿"
      "«" "»"
    ]
  '';
}
