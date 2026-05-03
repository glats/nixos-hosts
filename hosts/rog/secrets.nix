{ lib, ... }:

let
  isRog = true;
in
{
  # Rog-specific secret declarations via sops
  # These reference encrypted files in ../../secrets/system/

  # WireGuard secrets (server private key + peer preshared keys)
  sops.secrets."wireguard/server_private_key" = {
    sopsFile = ../../secrets/system/wireguard.yaml;
  };
  sops.secrets."wireguard/peer_oneplus9_psk" = {
    sopsFile = ../../secrets/system/wireguard.yaml;
  };
  sops.secrets."wireguard/peer_mac_psk" = {
    sopsFile = ../../secrets/system/wireguard.yaml;
  };
  sops.secrets."wireguard/peer_thinkpad_psk" = {
    sopsFile = ../../secrets/system/wireguard.yaml;
  };
  sops.secrets."wireguard/peer_samsung_psk" = {
    sopsFile = ../../secrets/system/wireguard.yaml;
  };
  sops.secrets."wireguard/peer_thinkphone_psk" = {
    sopsFile = ../../secrets/system/wireguard.yaml;
  };

  # DDNS (ddclient)
  sops.secrets."ddclient" = {
    sopsFile = ../../secrets/system/ddclient.yaml;
    owner = "ddclient";
    group = "ddclient";
    mode = "0400";
  };

  # Cloudflare API token for acme
  sops.secrets."cloudflare_api_token" = {
    sopsFile = ../../secrets/system/cloudflare.yaml;
    owner = "acme";
  };

  # Guacamole
  sops.secrets."guacamole/env" = {
    sopsFile = ../../secrets/system/guacamole.yaml;
  };

  # Git credentials for homemanager git module
  sops.secrets."git-credentials" = {
    sopsFile = ../../secrets/system/git-credentials.yaml;
    owner = "glats";
    group = "users";
    mode = "0600";
  };
}
