{ lib, ... }:

{
  conky-config = {
    enable = true;
    networkInterface = "enp0s31f6";
    additionalInterfaces = [ "wlp2s0" ];
    mountPoints = [ ];
  };
}
