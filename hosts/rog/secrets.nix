{ lib, ... }:

let
  isRog = true;
in
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

  # Cloudflare API token for acme
  sops.secrets."cloudflare_api_token" = {
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

  # Git credentials for homemanager git module
  sops.secrets."git-credentials" = {
    sopsFile = ../../secrets/shared/git-credentials.yaml;
    owner = "glats";
    group = "users";
    mode = "0600";
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

}
