{ config, lib, pkgs, hostName, ... }:

let
  hexToRgb = hex:
    let
      r = lib.substring 0 2 hex;
      g = lib.substring 2 2 hex;
      b = lib.substring 4 2 hex;
      toDec = h: lib.fromHexString h;
    in
    "rgb(${toString (toDec r)},${toString (toDec g)},${toString (toDec b)})";
  doubleHex = hex: lib.concatStrings (lib.concatMap (c: [ c c ]) (lib.stringToCharacters hex));
  byteDoubleHex = hex:
    let
      r = lib.substring 0 2 hex;
      g = lib.substring 2 2 hex;
      b = lib.substring 4 2 hex;
    in
    "${r}${r}${g}${g}${b}${b}";
in
{
  # XFCE uses xfconf for settings, configured via programs.xfconf in home-manager
  # dconf settings still apply for GTK theme (shared via theme.nix)

  xdg.configFile = {
    # CopyQ clipboard manager
    "autostart/copyq.desktop".text = ''
      [Desktop Entry]
      Name=CopyQ
      Comment=Clipboard Manager with Advanced Features
      Icon=copyq
      Exec=${pkgs.copyq}/bin/copyq
      Terminal=false
      Type=Application
      Categories=GTK;Utility;
      OnlyShowIn=XFCE;
      X-XFCE-Autostart-enabled=true
    '';

    # Flameshot screenshot tool - use X11 legacy path for xrdp compatibility
    "autostart/org.flameshot.Flameshot.desktop".text = ''
      [Desktop Entry]
      Name=Flameshot
      GenericName=Screenshot tool
      Comment=Powerful yet simple to use screenshot software.
      Keywords=flameshot;screenshot;capture;shutter;
      Exec=${pkgs.flameshot}/bin/flameshot
      Icon=org.flameshot.Flameshot
      Terminal=false
      Type=Application
      Categories=Graphics;
      StartupNotify=false
      StartupWMClass=flameshot
      OnlyShowIn=XFCE;
      X-XFCE-Autostart-enabled=true
    '';

    # Disable xfce4-screensaver in xrdp sessions
    "autostart/xfce4-screensaver.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Screensaver
      Comment=Launch screensaver and locker program
      Icon=preferences-desktop-screensaver
      Exec=xfce4-screensaver
      OnlyShowIn=XFCE;
      Hidden=true
    '';

    # Disable xfce4-power-manager in xrdp sessions
    "autostart/xfce4-power-manager.desktop".text = ''
      [Desktop Entry]
      Name=Power Manager
      Comment=Power management daemon
      Icon=xfce4-power-manager
      Exec=xfce4-power-manager
      Terminal=false
      Type=Application
      OnlyShowIn=XFCE;
      Hidden=true
    '';
  } // lib.optionalAttrs (hostName == "rog") {
    "autostart/io.github.Hexchat.desktop".text = ''
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
      OnlyShowIn=XFCE;
      X-XFCE-Autostart-enabled=true
    '';
  };
}