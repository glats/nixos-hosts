{ config, lib, ... }:

{
  # Rog-specific secret declarations via sops
  # These reference encrypted files in ../../secrets/host/rog/ and ../../secrets/shared/

  # Input only: relay-policy stage/apply explicitly promotes the live policy.
  sops.secrets."ssh-relay/authorization" = lib.mkIf config.services.ssh-relay.enable {
    sopsFile = ../../secrets/shared/ssh-relay.yaml;
    key = "ssh-relay/authorization";
    owner = "root";
    group = "root";
    mode = "0600";
  };

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

  # Cloudflare DNS API token (glats.org + maquilinux.org zones) for ACME and
  # ddclient. ddclient's pre-start runs as root and copies it into its
  # private runtime config, so acme stays the owner.
  sops.secrets."cloudflare_dns_api_token" = {
    sopsFile = ../../secrets/host/rog/cloudflare.yaml;
    owner = "acme";
  };

  # Same token, readable by glats for the flarectl wrapper.
  sops.secrets."cloudflare_cli_api_token" = {
    sopsFile = ../../secrets/host/rog/cloudflare.yaml;
    key = "cloudflare_dns_api_token";
    owner = "glats";
    mode = "0400";
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

  # Darwin↔rog private link — per-device VLESS UUIDs. Each device has an
  # independently revocable credential in secrets/shared/link-uuids.yaml.
  # One scalar key per device; each is its own 0400 file owned by the
  # sing-box system user so the service can read them at activation.
  # Removing a key + this declaration + the matching users entry in
  # linux/system/services/network/sing-box-link.nix revokes that device only.
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
