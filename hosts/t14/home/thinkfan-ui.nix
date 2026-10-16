{
  config,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [ thinkfan-ui ];

  xdg.configFile."autostart/thinkfan-ui.desktop".text = ''
    [Desktop Entry]
    Name=ThinkFan UI
    Comment=ThinkPad Fan Control GUI
    Exec=thinkfan-ui --hide
    Icon=${pkgs.thinkfan-ui}/share/icons/thinkfan-ui.svg
    Terminal=false
    Type=Application
    Categories=System;Monitor;
    X-GNOME-Autostart-enabled=true
  '';
}
