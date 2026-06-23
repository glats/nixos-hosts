{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.dconf.profiles.user.databases = [
    {
      settings = with lib.gvariant; {
        "org/mate/marco/general" = {
          compositing-manager = false;
        };
      };
      locks = [
        "/org/mate/marco/general/compositing-manager"
      ];
    }
  ];
}
