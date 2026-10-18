# Run: nix eval --impure --json --expr 'import ./tests/t14-lid-policy.nix { flake = builtins.getFlake (toString ./.); }'
{ flake }:
let
  lib = flake.inputs.nixpkgs.lib;
  host = flake.nixosConfigurations.t14.config;
  login = host.services.logind.settings.Login;
  checks = {
    externalPowerIgnoresLid = login.HandleLidSwitchExternalPower or null == "ignore";
    dockedIgnoresLid = login.HandleLidSwitchDocked or null == "ignore";
    batteryStillSuspends = !(login ? HandleLidSwitch) || login.HandleLidSwitch == "suspend";
    hdmOwnershipPreserved = !host.omarchy.hyprland.lidSwitch.enable;
  };
in
assert lib.assertMsg (lib.all (ok: ok) (builtins.attrValues checks)) (
  "T14 lid policy regression checks failed: "
  + lib.concatStringsSep ", " (builtins.attrNames (lib.filterAttrs (_: ok: !ok) checks))
);
checks
