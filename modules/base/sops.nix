{ config, lib, ... }:

let
  isRog = config.networking.hostName == "rog";
in
{
  sops.defaultSopsFile = ../../secrets/system/passwords.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  # Secrets shared by all hosts
  sops.secrets."glats_hashed_password" = {
    neededForUsers = true;
  };

  sops.secrets."github/pat" = {
    owner = "glats";
    group = "users";
    mode = "0400";
  };

  # Rog-only secrets with per-file references
  sops.secrets."wireguard/server_private_key" = lib.mkIf isRog {
    sopsFile = ../../secrets/system/wireguard.yaml;
  };
  sops.secrets."wireguard/peer_oneplus9_psk" = lib.mkIf isRog {
    sopsFile = ../../secrets/system/wireguard.yaml;
  };
  sops.secrets."wireguard/peer_mac_psk" = lib.mkIf isRog {
    sopsFile = ../../secrets/system/wireguard.yaml;
  };
  sops.secrets."wireguard/peer_thinkpad_psk" = lib.mkIf isRog {
    sopsFile = ../../secrets/system/wireguard.yaml;
  };
  sops.secrets."wireguard/peer_samsung_psk" = lib.mkIf isRog {
    sopsFile = ../../secrets/system/wireguard.yaml;
  };
  sops.secrets."wireguard/peer_thinkphone_psk" = lib.mkIf isRog {
    sopsFile = ../../secrets/system/wireguard.yaml;
  };

  sops.secrets."ddclient" = lib.mkIf isRog {
    sopsFile = ../../secrets/system/ddclient.yaml;
    owner = "ddclient";
    group = "ddclient";
    mode = "0400";
  };

  sops.secrets."cloudflare_api_token" = lib.mkIf isRog {
    sopsFile = ../../secrets/system/cloudflare.yaml;
    owner = "acme";
  };

  sops.secrets."guacamole/env" = lib.mkIf isRog {
    sopsFile = ../../secrets/system/guacamole.yaml;
  };

  sops.secrets."git-credentials" = lib.mkIf isRog {
    sopsFile = ../../secrets/system/git-credentials.yaml;
    owner = "glats";
    group = "users";
    mode = "0600";
  };

  # engram cloud disabled until credentials are available
  # sops.secrets."engram-cloud/env" = lib.mkIf isRog {
  #   sopsFile = ../../secrets/system/engram-cloud.yaml;
  # };
}
