{ config
, lib
, pkgs
, ...
}:

{
  xdg.configFile = {
    "autostart/copyq.desktop".text = ''
      [Desktop Entry]
      Name=CopyQ
      Comment=Clipboard Manager with Advanced Features
      Icon=copyq
      Exec=${pkgs.copyq}/bin/copyq
      Terminal=false
      Type=Application
      Categories=GTK;GNOME;Application;Utility;
      OnlyShowIn=MATE;
      X-MATE-Autostart-enabled=true
    '';

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
      OnlyShowIn=MATE;
      X-MATE-Autostart-enabled=true
    '';

    # Disable mate-screensaver in xrdp sessions - causes disconnection issues
    "autostart/mate-screensaver.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Screensaver
      Comment=Launch screensaver and locker program
      Icon=preferences-desktop-screensaver
      Exec=mate-screensaver
      OnlyShowIn=MATE;
      Hidden=true
    '';

    # Disable mate-power-manager in xrdp sessions - not needed in remote sessions
    "autostart/mate-power-manager.desktop".text = ''
      [Desktop Entry]
      Name=Power Manager
      Comment=Power management daemon
      Icon=mate-power-manager
      Exec=mate-power-manager
      Terminal=false
      Type=Application
      OnlyShowIn=MATE;
      Hidden=true
    '';
  };

  # Flameshot v14 uses xdg-desktop-portal Screenshot by default.
  # X11/xrdp sessions have no portal backend for Screenshot.
  # Use activation script instead of xdg.configFile so flameshot can
  # write its own settings through the GUI without being overwritten.
  home.activation.ensureFlameshotX11Legacy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ini="$HOME/.config/flameshot/flameshot.ini"
    mkdir -p "$(dirname "$ini")"
    if [ ! -f "$ini" ]; then
      printf '[General]\ncontrastOpacity=188\nuseX11LegacyScreenshot=true\n' > "$ini"
    elif ! grep -q '^useX11LegacyScreenshot=true' "$ini"; then
      if grep -q '^\[General\]' "$ini"; then
        sed -i '/^\[General\]/a useX11LegacyScreenshot=true' "$ini"
      else
        printf '\n[General]\nuseX11LegacyScreenshot=true\n' >> "$ini"
      fi
    fi
  '';
}
