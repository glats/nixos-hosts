{ config, lib, pkgs, ... }:

let
  hexToRgb = hex:
    let
      r = lib.substring 0 2 hex;
      g = lib.substring 2 2 hex;
      b = lib.substring 4 2 hex;
      toDec = h: lib.fromHexString h;
    in
    "${toString (toDec r)},${toString (toDec g)},${toString (toDec b)}";
in
{
  # XFCE uses xfconf for settings (Home Manager: programs.xfconf)
  # GTK theme shared via theme.nix, Qt via theme.nix

  # xfconf.settings disabled temporarily - causes "Failed to set property" in headless/xrdp sessions
  # TODO: re-enable with session detection or move to xrdp-specific config
  xfconf.settings = lib.mkForce { };

  xdg.configFile = {
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
  };

  xdg.dataFile."applications/xrdp-back-to-picker.desktop".text = ''
    [Desktop Entry]
    Name=Back to Session Picker
    Comment=Log out and return to XRDP session picker
    Exec=sh -c "XRDP_SESSION=1 ${pkgs.nixos-scripts}/bin/xrdp-back-to-picker"
    Icon=system-log-out
    Type=Application
    Terminal=false
    Categories=System;
    OnlyShowIn=XFCE;
  '';
}
