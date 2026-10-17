{ flake }:
let
  lib = flake.inputs.nixpkgs.lib;
  rog = flake.nixosConfigurations.rog.config;
  thinkcentre = flake.nixosConfigurations.thinkcentre.config;
  home = flake.homeConfigurations.rog.config;
  checks = {
    sonicOnlyOnThinkcentre =
      flake.inputs ? sonic-de
      && !(lib.attrByPath [ "services" "desktopManager" "sonic-de" "enable" ] false rog)
      && lib.attrByPath [ "services" "desktopManager" "sonic-de" "enable" ] false thinkcentre
      && !(lib.attrByPath [
        "services"
        "desktopManager"
        "sonic-de"
        "enable"
      ] false flake.nixosConfigurations.t14.config);
    rogRemoteSession =
      rog.services.xrdp.enable
      && lib.hasInfix "xrdp-mate-session" rog.services.xrdp.defaultWindowManager
      && rog.services.xserver.desktopManager.mate.enable
      && rog.my.desktop.suite == "mate";
    noLocalLogin =
      !rog.services.displayManager.sddm.enable && !rog.services.xserver.displayManager.lightdm.enable;
    thinkcentreRemoteSession =
      !thinkcentre.services.xserver.desktopManager.mate.enable
      && thinkcentre.services.xrdp.enable
      && lib.hasSuffix "/bin/startplasma-x11" thinkcentre.services.xrdp.defaultWindowManager
      && !thinkcentre.services.displayManager.sddm.enable
      && !thinkcentre.services.xserver.displayManager.lightdm.enable;
    thinkcentreHome =
      !flake.homeConfigurations.thinkcentre.config.qt.enable
      && !flake.homeConfigurations.thinkcentre.config.services.picom.enable
      &&
        thinkcentre.home-manager.users.glats.qt.kde.settings
        == flake.homeConfigurations.thinkcentre.config.qt.kde.settings;
    thinkcentreKdeSettings =
      let
        s = flake.homeConfigurations.thinkcentre.config.qt.kde.settings;
        sc = s.kglobalshortcutsrc.services;
      in
      s.kdeglobals.KDE.LookAndFeelPackage == "org.kde.breezedark.desktop"
      && s.kdeglobals.General.ColorScheme == "BreezeDark"
      && s.kscreenlockerrc.Daemon.Autolock == false
      && s.kscreenlockerrc.Daemon.Timeout == 0
      && s.powerdevilrc.AC.SuspendAndShutdown.AutoSuspendAction == 0
      && s.kded5rc."Module-device_automounter".autoload == false
      && s.kded5rc."Module-gtkconfig".autoload == false
      && s.ksmserverrc.General.loginMode == "emptySession"
      && sc."org.kde.krunner.desktop"._launch == "Ctrl+Space"
      && sc."org.kde.spectacle.desktop"._launch == "Print"
      && sc."org.flameshot.Flameshot.desktop".Capture == null;
    thinkcentreAutostart =
      let
        hm = flake.homeConfigurations.thinkcentre.config;
        files = hm.xdg.configFile;
        layout = hm.xdg.dataFile."sonicde/layout.js".text;
      in
      !(files ? "autostart/io.github.Hexchat.desktop")
      && !(lib.any (p: (p.pname or "") == "hexchat") hm.home.packages)
      && !(files ? "autostart/org.flameshot.Flameshot.desktop")
      && !(lib.any (p: (p.pname or "") == "flameshot") hm.home.packages)
      && !(lib.any (p: (p.pname or "") == "flameshot") thinkcentre.environment.systemPackages)
      && files ? "autostart/sonicde-layout.desktop"
      && lib.hasInfix "org.kde.color" layout
      && lib.hasInfix "applications:kitty.desktop" layout
      && lib.hasInfix "applications:brave-browser.desktop" layout
      && lib.hasInfix "p.height = 24;" layout;
    thinkcentreKwinUnwrapPatch =
      let
        sonicWin =
          flake.nixosConfigurations.thinkcentre._module.args.sonic-de.packages.x86_64-linux.sonic-win;
      in
      lib.any (p: lib.hasSuffix "sonic-win-unwrap-serviceutils.patch" (toString p)) sonicWin.patches
      && thinkcentre.security.wrappers.kwin_x11.source == "${lib.getBin sonicWin}/bin/kwin_x11"
      && lib.elem sonicWin thinkcentre.environment.systemPackages;
    mateKeepsFlameshot =
      lib.any (p: (p.pname or "") == "flameshot") rog.environment.systemPackages
      && rog.home-manager.users.glats.xdg.configFile ? "autostart/org.flameshot.Flameshot.desktop";
    rogKdeUntouched =
      rog.home-manager.users.glats.qt.kde.settings == { }
      && !(rog.home-manager.users.glats.xdg.configFile ? "autostart/sonicde-layout.desktop");
    kconfigAvailable = flake.homeConfigurations.rog.options.qt.kde ? settings;
    mateThemeRestored = home.qt.enable && home.qt.platformTheme.name == "gtk3";
    integratedHomeMatches =
      rog.home-manager.users.glats.qt.enable == home.qt.enable
      && rog.home-manager.users.glats.qt.kde.settings == home.qt.kde.settings;
  };
in
assert lib.assertMsg (lib.all (x: x) (builtins.attrValues checks)) (
  "SonicDE regression checks failed: "
  + lib.concatStringsSep ", " (builtins.attrNames (lib.filterAttrs (_: ok: !ok) checks))
);
checks
