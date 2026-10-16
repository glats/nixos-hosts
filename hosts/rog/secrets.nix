{ config, lib, ... }:

{

  sops.secrets."ssh-relay/authorization" = lib.mkIf config.services.ssh-relay.enable {
    sopsFile = ../../secrets/shared/ssh-relay.yaml;
    key = "ssh-relay/authorization";
    owner = "root";
    group = "root";
    mode = "0600";
  };

  sops.secrets."wireguard/server_private_key" = {
    sopsFile = ../../secrets/host/rog/wireguard.yaml;
  };
  sops.secrets."wireguard/peer_oneplus9_psk" = {
    sopsFile = ../../secrets/host/rog/wireguard.yaml;
  };
  sops.secrets."wireguard/peer_mac_psk" = {
    sopsFile = ../../secrets/host/rog/wireguard.yaml;
  };
  sops.secrets."wireguard/peer_thinkpad_psk" = {
    sopsFile = ../../secrets/host/rog/wireguard.yaml;
  };
  sops.secrets."wireguard/peer_samsung_psk" = {
    sopsFile = ../../secrets/host/rog/wireguard.yaml;
  };
  sops.secrets."wireguard/peer_thinkphone_psk" = {
    sopsFile = ../../secrets/host/rog/wireguard.yaml;
  };

  sops.secrets."cloudflare_dns_api_token" = {
    sopsFile = ../../secrets/host/rog/cloudflare.yaml;
    owner = "acme";
  };

  sops.secrets."cloudflare_cli_api_token" = {
    sopsFile = ../../secrets/host/rog/cloudflare.yaml;
    key = "cloudflare_dns_api_token";
    owner = "glats";
    mode = "0400";
  };

  sops.secrets."guacamole/env" = {
    sopsFile = ../../secrets/host/rog/guacamole.yaml;
  };
  sops.secrets."guacamole/admin_password" = {
    sopsFile = ../../secrets/host/rog/guacamole.yaml;
  };

  sops.secrets."authelia/jwt_secret" = {
    sopsFile = ../../secrets/host/rog/authelia.yaml;
  };
  sops.secrets."authelia/session_secret" = {
    sopsFile = ../../secrets/host/rog/authelia.yaml;
  };
  sops.secrets."authelia/storage_encryption_key" = {
    sopsFile = ../../secrets/host/rog/authelia.yaml;
  };
  sops.secrets."authelia/postgresql_password" = {
    sopsFile = ../../secrets/host/rog/authelia.yaml;
  };
  sops.secrets."authelia/redis_password" = {
    sopsFile = ../../secrets/host/rog/authelia.yaml;
  };

  sops.secrets."romm/auth_secret_key" = {
    sopsFile = ../../secrets/host/rog/romm.yaml;
  };
  sops.secrets."romm/db_root_password" = {
    sopsFile = ../../secrets/host/rog/romm.yaml;
  };
  sops.secrets."romm/db_user_password" = {
    sopsFile = ../../secrets/host/rog/romm.yaml;
  };

  sops.secrets."link/uuid_macm5" = {
    sopsFile = ../../secrets/shared/link-uuids.yaml;
    key = "uuid_macm5";
    owner = "sing-box";
    group = "sing-box";
    mode = "0400";
  };
  sops.secrets."link/uuid_phone" = {
    sopsFile = ../../secrets/shared/link-uuids.yaml;
    key = "uuid_phone";
    owner = "sing-box";
    group = "sing-box";
    mode = "0400";
  };

}
