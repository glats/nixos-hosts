{ lib, ... }:

let
  inherit (lib) mkOption;
in
{
  options.conky-config = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable conky system monitor";
    };
    networkInterface = mkOption {
      type = lib.types.str;
      default = "eth0";
      description = "Primary network interface for conky display";
    };
    additionalInterfaces = mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional network interfaces for failover";
    };
    mountPoints = mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional mount points to display in storage section";
    };
  };

  config.conky-config = {
    enable = lib.mkDefault false;
    networkInterface = lib.mkDefault "eth0";
    additionalInterfaces = lib.mkDefault [ ];
    mountPoints = lib.mkDefault [ ];
  };
}
