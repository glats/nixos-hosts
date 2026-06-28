{ config
, lib
, pkgs
, ...
}:

{
  # MATE marco compositing lock — only meaningful on hosts that run
  # MATE (selected by my.desktop.suite = "mate"). Without the gate,
  # t14 (and any future non-MATE host) would receive a dconf lock
  # pointing at a dconf key for an uninstalled window manager.
  programs.dconf.profiles.user.databases = lib.mkIf (config.my.desktop.suite == "mate") [
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
