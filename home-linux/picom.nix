{ config, lib, pkgs, hostName, ... }:

{
  services.picom = lib.mkIf (builtins.elem hostName [ "rog" "thinkcentre" ]) {
    enable = true;
    backend = "glx";
    vSync = true;
    shadow = true;
    fade = false;

    settings = {
      detect-client-opacity = true;
      detect-transient = true;
      detect-client-leader = true;
      detect-rounded-corners = true;
      unredir-if-possible = true;
    };
  };
}
