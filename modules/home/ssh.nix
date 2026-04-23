{ config, ... }:

let
  sshDir = "${config.home.homeDirectory}/.ssh";
in

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      oneplus5-local = {
        host = "oneplus5.local";
        hostname = "oneplus5.local";
        user = "glats";
        identityFile = "${sshDir}/oneplus5";
        identitiesOnly = true;
        setEnv = {
          TERM = "xterm-256color";
        };
      };
      oneplus5-ip = {
        host = "172.16.0.12";
        hostname = "172.16.0.12";
        user = "glats";
        identityFile = "${sshDir}/oneplus5";
        identitiesOnly = true;
        setEnv = {
          TERM = "xterm-256color";
        };
      };
      thinkcentre-local = {
        host = "thinkcentre.local";
        hostname = "thinkcentre.local";
        user = "glats";
        identityFile = "${sshDir}/thinkcentre";
        identitiesOnly = true;
        setEnv = {
          TERM = "xterm-256color";
        };
      };
      mact2-local = {
        host = "mact2.local";
        hostname = "mact2.local";
        user = "jcuzmar";
        identityFile = "${sshDir}/mact2";
        identitiesOnly = true;
        setEnv = {
          TERM = "xterm-256color";
        };
      };
      rog-local = {
        host = "rog.local";
        hostname = "rog.local";
        user = "glats";
        identityFile = "${sshDir}/rog";
        identitiesOnly = true;
        setEnv = {
          TERM = "xterm-256color";
        };
      };
    };
  };
}
