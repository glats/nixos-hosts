{ config, pkgs, ... }:

let
  applyLayout = pkgs.writeShellApplication {
    name = "sonicde-apply-layout";
    runtimeInputs = [ pkgs.dbus ];
    text = ''
      js="$(cat "${config.xdg.dataHome}/sonicde/layout.js")"
      for _ in $(seq 30); do
        if dbus-send --session --print-reply --dest=org.kde.plasmashell /PlasmaShell \
          org.kde.PlasmaShell.evaluateScript "string:$js" >/dev/null 2>&1; then
          exit 0
        fi
        sleep 2
      done
      echo "plasmashell scripting unavailable" >&2
      exit 1
    '';
  };
in
{
  qt.kde.settings = {
    kdeglobals = {
      KDE.LookAndFeelPackage = "org.kde.breezedark.desktop";
      General.ColorScheme = "BreezeDark";
    };
    plasmarc.Theme.name = "breeze-dark";
    kscreenlockerrc.Daemon = {
      Autolock = false;
      Timeout = 0;
    };
    powerdevilrc.AC.SuspendAndShutdown.AutoSuspendAction = 0;
    kded5rc = {
      "Module-device_automounter".autoload = false;
      "Module-gtkconfig".autoload = false;
    };
    kglobalshortcutsrc.services = {
      "org.kde.krunner.desktop"._launch = "Ctrl+Space";
      "org.kde.spectacle.desktop"._launch = "Print";
      "org.flameshot.Flameshot.desktop".Capture = null;
    };
  };

  xdg.dataFile."sonicde/layout.js".text = ''
    desktops().forEach(function (d) {
      d.wallpaperPlugin = "org.kde.color";
      d.currentConfigGroup = ["Wallpaper", "org.kde.color", "General"];
      d.writeConfig("Color", "0,0,0");
    });
    panels().forEach(function (p) {
      if (p.location == "bottom") {
        p.height = 24;
      }
      p.widgets("org.kde.plasma.icontasks").forEach(function (w) {
        w.currentConfigGroup = ["General"];
        w.writeConfig("launchers", [
          "applications:systemsettings.desktop",
          "preferred://filemanager",
          "applications:brave-browser.desktop",
          "applications:kitty.desktop"
        ]);
      });
    });
  '';

  xdg.configFile = {
    "autostart/sonicde-layout.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=SonicDE layout
      Exec=${applyLayout}/bin/sonicde-apply-layout
      OnlyShowIn=KDE;
      NoDisplay=true
      X-KDE-autostart-phase=2
    '';
  };
}
