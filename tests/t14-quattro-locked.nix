# nix eval --impure --json --expr 'import ./tests/t14-quattro-locked.nix { flake = builtins.getFlake (toString ./.); }'
{ flake }:
let
  host = flake.nixosConfigurations.t14;
  checks = {
    publishedFork = flake.inputs.omarchy-nix.rev == "eb94d307d43ab0270ef4ec75c9c28ac563a4d44c";
    quattroEnabled = host.config.omarchy.quattro.enable;
    shellEnabled = host.config.omarchy.quattro.shell.enable or false;
    hyprlangPreserved =
      host.config.home-manager.users.glats.wayland.windowManager.hyprland.configType == "hyprlang";
  };
in
assert host.pkgs.lib.assertMsg (builtins.all (ok: ok) (
  builtins.attrValues checks
)) "T14 must use the published selective Quattro fork and shell without overrides";
checks
