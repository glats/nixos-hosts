{
  config,
  lib,
  pkgs,
  ...
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

  home.activation.ensureFlameshotX11Legacy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ini="$HOME/.config/flameshot/flameshot.ini"
    mkdir -p "$(dirname "$ini")"
    major="$(${pkgs.flameshot}/bin/flameshot --version 2>/dev/null | sed -n 's/.*v\([0-9]*\)\..*/\1/p')"
    if [ "$major" -ge 14 ] 2>/dev/null; then
      # v14+: ensure legacy X11 screenshot key is set
      if [ ! -f "$ini" ]; then
        printf '[General]\nuseX11LegacyScreenshot=true\n' > "$ini"
      elif ! grep -q '^useX11LegacyScreenshot=true' "$ini"; then
        if grep -q '^\[General\]' "$ini"; then
          sed -i '/^\[General\]/a useX11LegacyScreenshot=true' "$ini"
        else
          printf '\n[General]\nuseX11LegacyScreenshot=true\n' >> "$ini"
        fi
      fi
    else
      # v13-: remove v14-only key if present (unrecognized -> error dialog)
      if [ -f "$ini" ]; then
        sed -i '/^useX11LegacyScreenshot=/d' "$ini"
      fi
    fi
  '';
}
