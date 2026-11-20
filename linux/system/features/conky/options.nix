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
    poweroffCampaign = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Show the one-line state of the poweroff A/B campaign (test-shutdown brief)";
    };
    mountPoints = mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional mount points to display in storage section";
    };
    background = mkOption {
      type = lib.types.enum [
        "transparent"
        "black"
      ];
      default = "transparent";
      description = "Conky window background: transparent keeps the wallpaper visible, black renders a semi-opaque black panel";
    };
  };
}
