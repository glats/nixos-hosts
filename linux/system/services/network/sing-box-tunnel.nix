# Loopback VLESS+WS inbound for the opencode tunnel.
#
# One sing-box process binds 127.0.0.1:4011 and accepts WS connections
# proxied by nginx from tun.glats.org. Each approved device gets its
# own entry in the `users` array; the UUID is pulled at activation from
# a per-device sops file (one _secret per UUID, never the whole array),
# so removing a key + decl + users entry revokes only that device.
#
# The WS path is a one-time random hex constant, NOT sops: it's
# obscurity, not auth. nginx passes the location path through (the same
# value lives in linux/system/services/web/nginx.nix), and the same
# value is referenced by the mact2 client (darwin/system/sing-box-tunnel.nix)
# and by bin/tunnel-device-link for phone link generation. Generating it
# once keeps the three sites byte-identical without a shared secret.
#
# Runs as the unprivileged `sing-box` system user created by the NixOS
# module. Loopback inbound only — no public listener, no TUN, no caps.
{ config
, lib
, pkgs
, ...
}:

let
  # Random hex generated once via `openssl rand -hex 16`. Treat as
  # obscurity — not a credential, not a sops key.
  wsPath = "/ed59280aa562f4b7eba4519e3c316e24";

  cfg = config.services.sing-box-tunnel;
in
{
  options.services.sing-box-tunnel = {
    enable = lib.mkEnableOption "OpenCode tunnel loopback VLESS+WS server";

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

      # Freeform JSON. Each `users[].uuid = { _secret = ...; }` is
      # replaced at activation by the NixOS sing-box module's
      # `genJqSecretsReplacementSnippet` (verified against nixpkgs
      # nixos-26.05 modules/services/networking/sing-box.nix). The file
      # content is embedded as a JSON string (default `quote = true`).
      settings = {
        log = {
          level = "info";
        };

        inbounds = [
          {
            type = "vless";
            listen = "127.0.0.1";
            listen_port = config.services.sing-box-tunnel.port;
            users = [
              {
                name = "mact2";
                uuid = { _secret = config.sops.secrets."opencode-tunnel/uuid_mact2".path; };
              }
              {
                name = "phone";
                uuid = { _secret = config.sops.secrets."opencode-tunnel/uuid_phone".path; };
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
