{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.dconf.profiles.user.databases = lib.mkIf (config.my.desktop.suite == "mate") [
    {
      settings = with lib.gvariant; {
        "org/mate/marco/general" = {
          compositing-manager = true;
        };
      };
    }
  ];
}
