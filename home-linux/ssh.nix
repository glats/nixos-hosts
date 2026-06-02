{ config, ... }:

let
  sshDir = "${config.home.homeDirectory}/.ssh";
in

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "Host oneplus5.local" = {
        HostName = "oneplus5.local";
        User = "glats";
        IdentityFile = "${sshDir}/oneplus5";
        IdentitiesOnly = true;
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

      "172.16.0.12" = {
        HostName = "172.16.0.12";
        User = "glats";
        IdentityFile = "${sshDir}/oneplus5";
        IdentitiesOnly = true;
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

      "thinkcentre.local" = {
        HostName = "thinkcentre.local";
        User = "glats";
        IdentityFile = "${sshDir}/thinkcentre";
        IdentitiesOnly = true;
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

      "mact2.local" = {
        HostName = "mact2.local";
        User = "jcuzmar";
        IdentityFile = "${sshDir}/mact2";
        IdentitiesOnly = true;
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

      "rog.local" = {
        HostName = "rog.local";
        User = "glats";
        IdentityFile = "${sshDir}/rog";
        IdentitiesOnly = true;
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

      "t14.local" = {
        HostName = "t14.local";
        User = "glats";
        IdentityFile = "${sshDir}/t14";
        IdentitiesOnly = true;
        SetEnv = {
          TERM = "xterm-256color";
        };
      };
    };
  };
}
