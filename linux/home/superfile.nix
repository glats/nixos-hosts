# Linux superfile (TUI file manager) configuration.
# Imports shared superfile theme and deploys to ~/.config/superfile/.
{ config, pkgs, ... }:
let
  themeToml = import ../../shared/superfile.nix {
    colorScheme = config.colorScheme;
  };
in
{
  home.packages = [ pkgs.superfile ];
  xdg.configFile."superfile/theme/glats.toml".text = themeToml;
  xdg.configFile."superfile/config.toml".text = ''
    theme = "glats"
    ignore_missing_fields = true
  '';
}
