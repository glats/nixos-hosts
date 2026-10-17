# Run against the locked flake without activating:
# nix eval --impure --json .#nixosConfigurations.t14 --apply 'host: import ./tests/t14-quattro-shell.nix { inherit host; }'
{ host }:
let
  candidate = host;
  hm = candidate.config.home-manager.users.glats;
  baseline = host.extendModules {
    modules = [
      { disabledModules = [ "${host._module.specialArgs.self.outPath}/hosts/t14/quattro.nix" ]; }
    ];
  };
  base = baseline.config.home-manager.users.glats;
  shell = builtins.fromJSON hm.xdg.configFile."omarchy/shell.json".text;
  widgets = shell.bar.layout.left ++ shell.bar.layout.center ++ shell.bar.layout.right;
  widgetId = widget: if builtins.isAttrs widget then widget.id or "" else widget;
  checks = {
    schemaVersion = (shell.version or null) == 1;
    widgetSchema = builtins.all (widget: builtins.isAttrs widget && widget ? id) widgets;
    keyboardWidget = builtins.any (widget: widgetId widget == "omarchy.keyboard-layout") widgets;
    noDisabledWidget = builtins.all (
      widget: !(builtins.elem (widgetId widget) shell.disabledPlugins)
    ) widgets;
    hostServicesPreserved =
      builtins.removeAttrs hm.systemd.user.services [
        "waybar"
        "omarchy-shell"
      ] == builtins.removeAttrs base.systemd.user.services [
        "waybar"
        "omarchy-shell"
      ];
    authPreserved = hm.programs.hyprlock == base.programs.hyprlock;
    idlePreserved = hm.services.hypridle == base.services.hypridle;
    mimePreserved = hm.xdg.mimeApps == base.xdg.mimeApps;
    hdmProfilesPreserved =
      hm.home.hyprdynamicmonitors.configFile == base.home.hyprdynamicmonitors.configFile
      && hm.home.hyprdynamicmonitors.extraFiles == base.home.hyprdynamicmonitors.extraFiles
      && hm.home.hyprdynamicmonitors.extraFlags == base.home.hyprdynamicmonitors.extraFlags;
    quattroEnabled = candidate.config.omarchy.quattro.enable;
    shellEnabled = candidate.config.omarchy.quattro.shell.enable;
    hostUsesHyprlang = hm.wayland.windowManager.hyprland.configType == "hyprlang";
    noWaybarUnit = !(hm.systemd.user.services ? waybar);
    mouseWigglePreserved =
      hm.systemd.user.services.mouse-wiggle
      == host.config.home-manager.users.glats.systemd.user.services.mouse-wiggle;
    hdmPreserved =
      hm.home.hyprdynamicmonitors.enable
      == host.config.home-manager.users.glats.home.hyprdynamicmonitors.enable;
    greetdPreserved = candidate.config.services.greetd.settings == host.config.services.greetd.settings;
    wayvncPreserved = candidate.config.omarchy.wayvnc == host.config.omarchy.wayvnc;
  };
in
assert host.pkgs.lib.assertMsg (host.pkgs.lib.all (ok: ok) (builtins.attrValues checks)) (
  "T14 Quattro shell checks failed: "
  + host.pkgs.lib.concatStringsSep ", " (
    builtins.attrNames (host.pkgs.lib.filterAttrs (_: ok: !ok) checks)
  )
);
checks
