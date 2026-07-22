{ pkgs, ... }:

{
  xdg.configFile."autostart/io.github.Hexchat.desktop".text = ''
    [Desktop Entry]
    Name=HexChat
    GenericName=IRC Client
    Comment=Chat with other people online
    Keywords=IM;Chat;
    Exec=${pkgs.hexchat}/bin/hexchat --existing %U
    Icon=io.github.Hexchat
    Terminal=false
    Type=Application
    Categories=GTK;Network;IRCClient;
    StartupNotify=true
    StartupWMClass=Hexchat
    MimeType=x-scheme-handler/irc;x-scheme-handler:ircs;
    OnlyShowIn=MATE;
    X-MATE-Autostart-enabled=true
  '';
}
