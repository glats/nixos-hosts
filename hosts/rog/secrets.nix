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

  # mact2↔rog private tunnel — per-device VLESS UUIDs (shared with
  # mact2). The "opencode-tunnel" key namespace is historical; do not
  # rename (sops re-encryption churn for zero functional gain).
  # One scalar key per device; each is its own 0400 file owned by the
  # sing-box system user so the service can read them at activation.
  # Removing a key + this decl + the matching users entry in
  # linux/system/services/network/sing-box-tunnel.nix revokes that
  # device only — mact2 and other devices stay connected.
  sops.secrets."opencode-tunnel/uuid_mact2" = {
    sopsFile = ../../secrets/shared/opencode-tunnel.yaml;
    key = "uuid_mact2";
    owner = "sing-box";
    group = "sing-box";
    mode = "0400";
  };
  sops.secrets."opencode-tunnel/uuid_phone" = {
    sopsFile = ../../secrets/shared/opencode-tunnel.yaml;
    key = "uuid_phone";
    owner = "sing-box";
    group = "sing-box";
    mode = "0400";
  };

}
