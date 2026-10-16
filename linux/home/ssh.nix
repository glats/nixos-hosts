{
  config,
  hostName,
  lib,
  ...
}:

let
  sshDir = "${config.home.homeDirectory}/.ssh";
  mesh = import ../../shared/ssh/lan-mesh.nix { inherit lib; };
in

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*".SetEnv.TERM = "xterm-256color";
    }
    // mesh.sshSettingsFor {
      source = hostName;
      inherit sshDir;
    };
  };
}
