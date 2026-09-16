{
  config,
  pkgs,
  ...
}:

{
  xdg.dataFile."applications/mate-terminal.desktop".text = ''
    [Desktop Entry]
    Name=Terminal
    Comment=Use the command line
    Exec=${pkgs.mate-terminal}/bin/mate-terminal --maximize
    Icon=utilities-terminal
    Type=Application
    Terminal=false
    Categories=GNOME;GTK;Utility;TerminalEmulator;System;
    Keywords=command line;execute;interpret;MATE;
    OnlyShowIn=MATE;
    StartupNotify=true
  '';
}
