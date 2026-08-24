{ lib, ... }:

{
  # Rog-specific secret declarations via sops
  # These reference encrypted files in ../../secrets/host/rog/ and ../../secrets/shared/

  # WireGuard secrets (server private key + peer preshared keys)
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

  # DDNS (ddclient)
  sops.secrets."ddclient" = {
    sopsFile = ../../secrets/host/rog/ddclient.yaml;
    owner = "ddclient";
    group = "ddclient";
    mode = "0400";
  };

  # Cloudflare DNS API token for ACME
  sops.secrets."cloudflare_dns_api_token" = {
    sopsFile = ../../secrets/host/rog/cloudflare.yaml;
    owner = "acme";
  };

  # Guacamole
  sops.secrets."guacamole/env" = {
    sopsFile = ../../secrets/host/rog/guacamole.yaml;
  };
  sops.secrets."guacamole/admin_password" = {
    sopsFile = ../../secrets/host/rog/guacamole.yaml;
  };

  # Authelia SSO secrets
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

  # RomM — ROM catalog manager
  sops.secrets."romm/auth_secret_key" = {
    sopsFile = ../../secrets/host/rog/romm.yaml;
  };
  sops.secrets."romm/db_root_password" = {
    sopsFile = ../../secrets/host/rog/romm.yaml;
  };
  sops.secrets."romm/db_user_password" = {
    sopsFile = ../../secrets/host/rog/romm.yaml;
  };

  # OpenAI proxy gateway (change: mact2-openai-proxy-via-rog)
  # Two secrets live on rog:
  #   - openai_proxy_upstream_key: real upstream OpenAI-compatible API
  #     credential. Never leaves rog; consumed only by the loopback
  #     proxy in linux/system/services/web/opencode-proxy.nix.
  #   - openai_proxy_client_key: scoped gateway key shared with mact2
  #     via sops shared/opencode/openai_proxy_api_key. Reject unknown
  #     clients at the loopback gateway; rotate by re-encrypting both
  #     files.
  sops.secrets."openai_proxy/upstream_key" = {
    sopsFile = ../../secrets/host/rog/openai-proxy.yaml;
    owner = "root";
    group = "root";
    mode = "0400";
  };
  sops.secrets."openai_proxy/client_key" = {
    sopsFile = ../../secrets/host/rog/openai-proxy.yaml;
    owner = "root";
    group = "root";
    mode = "0400";
  };

}
