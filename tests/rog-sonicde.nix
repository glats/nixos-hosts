# Run: nix eval --impure --json --expr 'import ./tests/rog-sonicde.nix { flake = builtins.getFlake ("path:" + toString ./.); }'
{ flake }:
let
  lib = flake.inputs.nixpkgs.lib;
  rog = flake.nixosConfigurations.rog.config;
  thinkcentre = flake.nixosConfigurations.thinkcentre.config;
  home = flake.homeConfigurations.rog.config;
  checks = {
    sonicParked =
      flake.inputs ? sonic-de
      && !(lib.attrByPath [ "services" "desktopManager" "sonic-de" "enable" ] false rog)
      && !(lib.attrByPath [ "services" "desktopManager" "sonic-de" "enable" ] false thinkcentre)
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
    matePreserved =
      thinkcentre.services.xserver.desktopManager.mate.enable
      && thinkcentre.services.xrdp.enable
      && lib.hasInfix "xrdp-mate-session" thinkcentre.services.xrdp.defaultWindowManager;
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
