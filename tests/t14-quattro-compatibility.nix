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
  checks = {
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
