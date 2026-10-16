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
