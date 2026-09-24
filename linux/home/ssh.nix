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
      # All supported terminal emulators implement xterm-256color, whereas
      # macOS does not necessarily include emulator-specific terminfo entries.
      "*".SetEnv.TERM = "xterm-256color";
    }
    // mesh.sshSettingsFor {
      source = hostName;
      inherit sshDir;
    };
  };
}
