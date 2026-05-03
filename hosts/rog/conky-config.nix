{ lib, ... }:

{
  conky-config = {
    enable = true;
    networkInterface = "enp3s0";
    additionalInterfaces = [ "wlp2s0" ];
    mountPoints = [
      "/run/media/library"
      "/run/media/stuff"
      "/run/media/archlinux"
    ];
  };
}
