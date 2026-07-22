# User-level fontconfig deployed to ~/.config/fontconfig/conf.d/
#
# Chrome/Chromium/Electron read user-level fontconfig.
# Mirrors system-level 51-nixos-custom.conf.
{ ... }:
{
  xdg.configFile."fontconfig/conf.d/51-nixos-custom.conf".text =
    builtins.readFile ../../shared/fontconfig/family-map.xml;
}
