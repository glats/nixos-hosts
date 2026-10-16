{
  config,
  lib,
  pkgs,
  ...
}:

let
  wsPath = "/ed59280aa562f4b7eba4519e3c316e24";

  cfg = config.services.sing-box-link;
  pathFor = name: config.sops."secrets".${name}.path;
in
{
  options.services.sing-box-link = {
    enable = lib.mkEnableOption "loopback VLESS+WS server of the macm5↔rog private link";

    port = lib.mkOption {
      type = lib.types.port;
      default = 4011;
      description = "Loopback port for the VLESS+WS inbound.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.sing-box = {
      enable = true;
      package = pkgs.sing-box;

      settings = {
        log = {
          level = "info";
        };

        inbounds = [
          {
            type = "vless";
            listen = "127.0.0.1";
            listen_port = config.services.sing-box-link.port;
            users = [
              {
                name = "macm5";
                uuid = {
                  _secret = pathFor "link/uuid_macm5";
                };
              }
              {
                name = "phone";
                uuid = {
                  _secret = pathFor "link/uuid_phone";
                };
              }
            ];
            transport = {
              type = "ws";
              path = wsPath;
            };
          }
        ];

        outbounds = [
          {
            type = "direct";
            tag = "direct";
          }
          {
            type = "block";
            tag = "block";
          }
        ];
      };
    };
  };
}
