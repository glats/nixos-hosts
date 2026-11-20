{ config, pkgs, ... }:
let
  themeToml = import ../../shared/superfile.nix {
    inherit (config) colorScheme;
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
