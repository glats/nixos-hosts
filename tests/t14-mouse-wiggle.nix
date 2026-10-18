# Run: nix eval --impure --json --expr 'import ./tests/t14-mouse-wiggle.nix { flake = builtins.getFlake (toString ./.); }'
{ flake }:
let
  lib = flake.inputs.nixpkgs.lib;
  home = flake.nixosConfigurations.t14.config.home-manager.users.glats;
  unit = home.systemd.user.services.mouse-wiggle;
  execStart = builtins.head unit.Service.ExecStart;
  script = builtins.head (
    builtins.filter (pkg: execStart == pkg.outPath + "/bin/mouse-wiggle") home.home.packages
  );
  scriptText = script.text;
  checks = {
    waitGuardAdoptsSignature =
      lib.hasInfix "HYPRLAND_INSTANCE_SIGNATURE" scriptText
      && lib.hasInfix "show-environment" scriptText
      && lib.hasInfix "export HYPRLAND_INSTANCE_SIGNATURE" scriptText;
    waitGuardBounded = lib.hasInfix "-lt 60" scriptText && lib.hasInfix "sleep 1" scriptText;
    scriptNeverReadsSignatureBare =
      !lib.hasInfix "\${HYPRLAND_INSTANCE_SIGNATURE}" (lib.replaceStrings [ "\n" ] [ "" ] scriptText);
    wantedByPreserved = builtins.elem "graphical-session.target" unit.Install.WantedBy;
    restartPreserved = unit.Service.Restart == "on-failure";
  };
in
assert lib.assertMsg (lib.all (ok: ok) (builtins.attrValues checks)) (
  "T14 mouse-wiggle regression checks failed: "
  + lib.concatStringsSep ", " (builtins.attrNames (lib.filterAttrs (_: ok: !ok) checks))
);
checks
