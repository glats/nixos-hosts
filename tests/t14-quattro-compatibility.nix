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
      && !(builtins.elem "omarchy.idle" disabled)
      && hm.services.hyprsunset == before.services.hyprsunset
      && hm.services.hypridle.enable
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
    menuOwnedByShell =
      let
        hm = host.config.home-manager.users.glats;
        text = hm.xdg.configFile."hypr/hyprland.conf".text;
        settings = builtins.fromJSON hm.xdg.configFile."omarchy/shell.json".text;
        override = builtins.fromJSON hm.xdg.configFile."omarchy/extensions/omarchy-menu.jsonc".text;
        hidden = id: (override.${id}.when or "") == "false";
        toggle = route: "omarchy-shell shell toggle omarchy.menu '{\"menu\":\"${route}\"}'";
      in
      !(lib.hasInfix "/omarchy-menu" text)
      && lib.all (route: lib.hasInfix (toggle route) text) [
        "root"
        "capture"
        "toggle"
        "system"
        "background"
        "theme"
        "hardware"
        "screenrecord"
        "share"
      ]
      && lib.hasInfix "omarchy-launch-walker\n" (text + "\n")
      && !(builtins.elem "omarchy.menu" settings.disabledPlugins)
      && builtins.elem { id = "omarchy.menu"; } settings.bar.layout.left
      && lib.all hidden [
        "install"
        "remove"
        "setup.reset"
        "update.channel"
        "setup.direct-boot"
        "setup.security.passwordless-sudo"
        "update.config"
        "update.firmware"
        "trigger.tests"
        "setup.network.qr"
        "setup.plugin"
        "setup.default"
        "style.font"
        "style.bar"
        "style.unlock"
        "style.hyprland"
        "setup.monitors"
        "setup.keybindings"
        "setup.input"
      ]
      && !(override ? "update.omarchy")
      && !(override ? "update.time")
      && override."learn.arch".label == "NixOS"
      && override."learn.arch".icon == "󱄅"
      && lib.hasInfix "nixos.org/manual" override."learn.arch".action;
    backgroundOwnedByShell =
      let
        hm = host.config.home-manager.users.glats;
        text = hm.xdg.configFile."hypr/hyprland.conf".text;
        disabled = (builtins.fromJSON hm.xdg.configFile."omarchy/shell.json".text).disabledPlugins;
        panel = builtins.head (
          builtins.match ".*(/nix/store/[a-z0-9]+-quattro-panel-commands)/bin.*" shellLauncher
        );
        commands = builtins.attrNames (builtins.readDir "${panel}/bin");
        seed = hm.home.activation.seedQuattroBackground or null;
      in
      !(lib.hasInfix "swaybg" text)
      && !(builtins.elem "omarchy.background" disabled)
      && !(builtins.elem "omarchy.image-picker" disabled)
      &&
        builtins.match ".*/nix/store/[a-z0-9]+-vips-[0-9.]+-bin/bin:.*|.*/nix/store/[a-z0-9]+-vips-[0-9.]+/bin:.*" shellLauncher
        != null
      && builtins.elem "omarchy-theme-bg-set" commands
      && builtins.elem "omarchy-theme-bg-next" commands
      && seed != null
      && builtins.elem "linkGeneration" seed.after
      && lib.hasInfix ".local/state/omarchy/current" seed.data;
    polkitOwnedByShell =
      let
        hm = host.config.home-manager.users.glats;
        disabled = (builtins.fromJSON hm.xdg.configFile."omarchy/shell.json".text).disabledPlugins;
      in
      !hm.services.hyprpolkitagent.enable
      && !(lib.hasInfix "hyprpolkitagent" hm.xdg.configFile."hypr/hyprland.conf".text)
      && !(builtins.elem "omarchy.polkit" disabled)
      && host.config.security.polkit.enable;
    lockOwnedByShell =
      let
        hm = host.config.home-manager.users.glats;
        text = hm.xdg.configFile."hypr/hyprland.conf".text;
        disabled = (builtins.fromJSON hm.xdg.configFile."omarchy/shell.json".text).disabledPlugins;
        idle = hm.services.hypridle.settings;
        quattroLock = "env PATH=/home/glats/.local/share/omarchy/quattro/bin:$PATH omarchy-system-lock";
        panel = builtins.head (
          builtins.match ".*(/nix/store/[a-z0-9]+-quattro-panel-commands)/bin.*" shellLauncher
        );
        commands = builtins.attrNames (builtins.readDir "${panel}/bin");
      in
      host.config.security.pam.services ? "omarchy-lock-password"
      && host.config.security.pam.services ? hyprlock
      && !(builtins.elem "omarchy.lock" disabled)
      && lib.hasInfix "Lock system, exec, env PATH=/home/glats/.local/share/omarchy/quattro/bin:" text
      && !(lib.hasInfix "/omarchy-system-lock" text)
      && idle.general.lock_cmd == quattroLock
      && idle.general.before_sleep_cmd == quattroLock
      && !(lib.hasInfix "pidof hyprlock" (builtins.toJSON idle))
      && builtins.elem "omarchy-system-lock" commands
      && builtins.elem "omarchy-hyprland-session-locked" commands;
    idleOwnedByShell =
      let
        hm = host.config.home-manager.users.glats;
        text = hm.xdg.configFile."hypr/hyprland.conf".text;
        settings = builtins.fromJSON hm.xdg.configFile."omarchy/shell.json".text;
        idle = hm.services.hypridle.settings;
        quattroBin = "/home/glats/.local/share/omarchy/quattro/bin";
        panel = builtins.head (
          builtins.match ".*(/nix/store/[a-z0-9]+-quattro-panel-commands)/bin.*" shellLauncher
        );
        commands = builtins.attrNames (builtins.readDir "${panel}/bin");
        migrate = hm.home.activation.migrateStayAwake or null;
      in
      !(builtins.elem "omarchy.idle" settings.disabledPlugins)
      &&
        settings.idle == {
          screensaver = 150;
          lock = 151;
        }
      && map (l: l.timeout) idle.listener == [ 330 ]
      && lib.hasInfix ".local/state/omarchy/indicators/stay-awake" (builtins.head idle.listener)
      .on-timeout
      && idle.general.before_sleep_cmd == "env PATH=${quattroBin}:$PATH omarchy-system-lock"
      && idle.general.inhibit_sleep == 3
      && !(lib.hasInfix "idle-off" (builtins.toJSON idle))
      && builtins.elem "omarchy-toggle-idle" commands
      && !(builtins.elem "omarchy-system-wake" commands)
      && lib.hasInfix "Toggle locking on idle, exec, env PATH=${quattroBin}:" text
      && !(lib.hasInfix "/omarchy-toggle-idle" text)
      && migrate != null
      && lib.hasInfix "toggles/idle-off" migrate.data
      && lib.hasInfix "indicators/stay-awake" migrate.data;
    keybindingsOwnedByShell =
      let
        hm = host.config.home-manager.users.glats;
        text = hm.xdg.configFile."hypr/hyprland.conf".text;
        panel = builtins.head (
          builtins.match ".*(/nix/store/[a-z0-9]+-quattro-panel-commands)/bin.*" shellLauncher
        );
      in
      lib.hasInfix "Show key bindings, exec, env PATH=/home/glats/.local/share/omarchy/quattro/bin:" text
      && lib.hasInfix "omarchy-menu-keybindings" text
      && !(lib.hasInfix "omarchy-show-keybindings" text)
      && builtins.elem "omarchy-menu-keybindings" (builtins.attrNames (builtins.readDir "${panel}/bin"));
    v3KeybindingsPreserved =
      lib.hasInfix "/omarchy-show-keybindings"
        before.xdg.configFile."hypr/hyprland.conf".text;
    v3IdlePreserved =
      map (l: l.timeout) before.services.hypridle.settings.listener == [
        150
        151
        330
      ]
      && lib.hasInfix "/omarchy-toggle-idle" before.xdg.configFile."hypr/hyprland.conf".text;
    v3LockPreserved =
      before.services.hypridle.settings.general.lock_cmd == "omarchy-system-lock"
      && lib.hasInfix "/omarchy-system-lock" before.xdg.configFile."hypr/hyprland.conf".text;
    v3PolkitPreserved =
      before.services.hyprpolkitagent.enable
      &&
        lib.hasInfix "systemctl --user start hyprpolkitagent"
          before.xdg.configFile."hypr/hyprland.conf".text;
    v3BackgroundPreserved =
      lib.hasInfix "swaybg -i ~/.config/omarchy/current/background"
        before.xdg.configFile."hypr/hyprland.conf".text;
    v3MenuKeysPreserved =
      let
        text = before.xdg.configFile."hypr/hyprland.conf".text;
      in
      lib.hasInfix "/omarchy-menu capture" text
      && lib.hasInfix "/omarchy-menu system" text
      && !(lib.hasInfix "omarchy.menu" text);
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
