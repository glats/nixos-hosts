{ config, hostName, lib, ... }:

let
  sshDir = "${config.home.homeDirectory}/.ssh";
  mesh = import ../../shared/ssh/lan-mesh.nix { inherit lib; };
in

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = mesh.sshSettingsFor
      {
        source = hostName;
        inherit sshDir;
      } // {
      "mact2.local" = {
        HostName = "mact2.local";
        User = "jcuzmar";
        IdentityFile = "${sshDir}/mact2";
        IdentitiesOnly = true;
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

    };
  };
}
