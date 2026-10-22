# Run against the locked flake without activating:
# nix eval --impure --json .#nixosConfigurations.t14 --apply 'host: import ./tests/t14-quattro-compatibility.nix { inherit host; }'
{ host }:
let
  baseline = host.extendModules {
    modules = [
      { disabledModules = [ "${host._module.specialArgs.self.outPath}/hosts/t14/quattro.nix" ]; }
    ];
  };
  candidate = baseline.extendModules {
    modules = [
      {
        omarchy.quattro.enable = true;
        home-manager.users.glats.wayland.windowManager.hyprland.configType = "hyprlang";
      }
    ];
  };
  lib = host.pkgs.lib;
  before = baseline.config.home-manager.users.glats;
  after = candidate.config.home-manager.users.glats;
  native =
    (baseline.extendModules { modules = [ { omarchy.quattro.enable = true; } ]; })
    .config.home-manager.users.glats;
  shellLauncher = builtins.readFile (
    builtins.head (
      lib.toList host.config.home-manager.users.glats.systemd.user.services.omarchy-shell.Service.ExecStart
    )
  );
  checks = {
    retainedServiceIndicators =
      let
        hm = host.config.home-manager.users.glats;
        source = hm.home.file.".local/share/omarchy/quattro".source;
        night = builtins.readFile "${source}/shell/plugins/bar/indicators/NightLight.qml";
        idle = builtins.readFile "${source}/shell/plugins/bar/indicators/StayAwake.qml";
        disabled = (builtins.fromJSON hm.xdg.configFile."omarchy/shell.json".text).disabledPlugins;
      in
      lib.hasInfix "/omarchy/bin/omarchy-toggle-nightlight" night
      && lib.hasInfix "/omarchy/bin/omarchy-toggle-idle" idle
      && lib.hasInfix "/omarchy/toggles/idle-off" idle
      && builtins.elem "omarchy.nightlight" disabled
      && builtins.elem "omarchy.idle" disabled
      && hm.services.hyprsunset == before.services.hyprsunset
      && hm.services.hypridle == before.services.hypridle
      && hm.systemd.user.services.mouse-wiggle == before.systemd.user.services.mouse-wiggle;
    sharedHyprlandPackage =
      after.wayland.windowManager.hyprland.package.drvPath
      == candidate.config.programs.hyprland.package.drvPath;
    defaultFormatsPreserved =
      before.wayland.windowManager.hyprland.configType == "hyprlang"
      && native.wayland.windowManager.hyprland.configType == "lua";
    hostSelectsHyprlang = after.wayland.windowManager.hyprland.configType == "hyprlang";
    noCompetingLuaEntry =
      !(after.xdg.configFile ? "hypr/hyprland.lua") && !(after.home.file ? ".config/hypr/hyprland.lua");
    hostFragmentsPreserved =
      after.wayland.windowManager.hyprland.extraConfig == lib.replaceStrings
        [
          "  col.border_locked_active = -1\n  col.border_locked_inactive = -1\n"
        ]
        [ "" ]
        before.wayland.windowManager.hyprland.extraConfig;
    mouseWigglePreserved =
      after.systemd.user.services.mouse-wiggle == before.systemd.user.services.mouse-wiggle;
    greeterPreserved =
      candidate.config.services.greetd.settings == host.config.services.greetd.settings;
    logindPreserved = candidate.config.services.logind.settings == host.config.services.logind.settings;
    lidOwnershipPreserved = !candidate.config.omarchy.hyprland.lidSwitch.enable;
    runtimeAvailable = after.home.file ? ".local/share/omarchy/quattro";
    pluginScanFollowsSymlinks = lib.hasInfix "find -L \\\"$dir\\\" -mindepth 2" (
      builtins.readFile "${
        host.config.home-manager.users.glats.home.file.".local/share/omarchy/quattro".source
      }/shell/services/PluginRegistry.qml"
    );
    topBarToggleTargetsShell =
      lib.hasInfix
        "Toggle top bar, exec, /home/glats/.local/share/omarchy/quattro/bin/omarchy-toggle bar-off"
        host.config.home-manager.users.glats.xdg.configFile."hypr/hyprland.conf".text;
    shellUsesQuattroVoxtypeStatus =
      let
        launcher = builtins.readFile (
          builtins.head (
            lib.toList host.config.home-manager.users.glats.systemd.user.services.omarchy-shell.Service.ExecStart
          )
        );
        panelDir = builtins.head (builtins.match ".*PATH=([^:]*quattro-panel-commands/bin):.*" launcher);
      in
      builtins.pathExists "${panelDir}/omarchy-voxtype-status"
      && !(lib.hasInfix "kill 0" (builtins.readFile "${panelDir}/omarchy-voxtype-status"));
    omarchyPathMatchesShell =
      host.config.environment.sessionVariables.OMARCHY_PATH == "$HOME/.local/share/omarchy/quattro"
      &&
        host.config.home-manager.users.glats.home.sessionVariables.OMARCHY_PATH
        == "/home/glats/.local/share/omarchy/quattro";
    batteryOwnedByShell =
      let
        disabled =
          (builtins.fromJSON host.config.home-manager.users.glats.xdg.configFile."omarchy/shell.json".text)
          .disabledPlugins;
        hm = host.config.home-manager.users.glats;
      in
      !(hm.systemd.user.timers ? omarchy-battery-monitor)
      && !(hm.systemd.user.services ? omarchy-battery-monitor)
      && !(builtins.elem "omarchy.battery" disabled);
    nightlightKept =
      host.config.home-manager.users.glats.services.hyprsunset.enable
      &&
        builtins.elem "omarchy.nightlight"
          (builtins.fromJSON host.config.home-manager.users.glats.xdg.configFile."omarchy/shell.json".text)
          .disabledPlugins;
    osdOwnedByShell =
      let
        text = host.config.home-manager.users.glats.xdg.configFile."hypr/hyprland.conf".text;
        disabled =
          (builtins.fromJSON host.config.home-manager.users.glats.xdg.configFile."omarchy/shell.json".text)
          .disabledPlugins;
      in
      !(lib.hasInfix "swayosd" text)
      && lib.hasInfix "omarchy-audio-output-volume raise" text
      && lib.hasInfix "omarchy-shell media playPause" text
      && !(builtins.elem "omarchy.osd" disabled);
    notificationsOwnedByShell =
      let
        text = host.config.home-manager.users.glats.xdg.configFile."hypr/hyprland.conf".text;
        disabled =
          (builtins.fromJSON host.config.home-manager.users.glats.xdg.configFile."omarchy/shell.json".text)
          .disabledPlugins;
      in
      !host.config.home-manager.users.glats.services.mako.enable
      && !(lib.hasInfix "makoctl" text)
      && lib.hasInfix "omarchy-shell notifications dismissOne" text
      && !(builtins.elem "omarchy.notifications" disabled);
    clipboardEmojisOwnedByShell =
      let
        text = host.config.home-manager.users.glats.xdg.configFile."hypr/hyprland.conf".text;
        disabled =
          (builtins.fromJSON host.config.home-manager.users.glats.xdg.configFile."omarchy/shell.json".text)
          .disabledPlugins;
      in
      !(lib.hasInfix "clipse -listen" text)
      && !(lib.hasInfix "omarchy-launch-walker -m clipboard" text)
      && !(lib.hasInfix "omarchy-launch-walker -m symbols" text)
      && lib.hasInfix "omarchy-shell shell toggle omarchy.clipboard" text
      && lib.hasInfix "omarchy-shell shell toggle omarchy.emojis" text
      && !(builtins.elem "omarchy.clipboard" disabled)
      && !(builtins.elem "omarchy.emojis" disabled)
      && lib.hasInfix "wtype" shellLauncher;
    noRemovedHyprlandOptions =
      let
        text = host.config.home-manager.users.glats.xdg.configFile."hypr/hyprland.conf".text;
      in
      !(lib.hasInfix "pseudotile" text) && !(lib.hasInfix "border_locked_active = -1" text);
  };
in
assert lib.assertMsg (lib.all (ok: ok) (builtins.attrValues checks)) (
  "T14 Quattro compatibility checks failed: "
  + lib.concatStringsSep ", " (builtins.attrNames (lib.filterAttrs (_: ok: !ok) checks))
);
checks
