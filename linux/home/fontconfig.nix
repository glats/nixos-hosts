{ ... }:
{
  xdg.configFile."fontconfig/conf.d/51-nixos-custom.conf".text =
    builtins.readFile ../../shared/fontconfig/family-map.xml;
}
