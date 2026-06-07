{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.services.wol-custom = {
    enable = lib.mkEnableOption "Wake-on-LAN service" // {
      default = true;
    };
    interface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Network interface for the ethtool wol-enable service. Set per host.";
    };
  };

  config = lib.mkIf config.services.wol-custom.enable {
    systemd.services.wol-enable = lib.mkIf (config.services.wol-custom.interface != null) {
      description = "Enable Wake-on-LAN";
      after = [ "NetworkManager.service" ];
      wants = [ "NetworkManager.service" ];
      wantedBy = [
        "multi-user.target"
        "sleep.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.ethtool}/bin/ethtool -s ${config.services.wol-custom.interface} wol g";
        RemainAfterExit = true;
      };
    };
  };
}
