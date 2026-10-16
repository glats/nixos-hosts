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
