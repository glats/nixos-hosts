# Darwin superfile (TUI file manager) configuration.
# Imports shared superfile theme and deploys to ~/Library/Application Support/superfile/.
# Package is already in packages.nix -- this module only deploys config files.
{ config, ... }:
let
  themeToml = import ../../shared/superfile.nix {
    colorScheme = config.colorScheme;
  };
in
{
  home.file."Library/Application Support/superfile/theme/glats.toml".text = themeToml;
  home.file."Library/Application Support/superfile/config.toml".text = ''
    theme = "glats"
    ignore_missing_fields = true
  '';
}
