{ config, lib, ... }:

let
  isRog = config.networking.hostName == "rog";
in
{
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  # Secrets shared by all hosts
  sops.secrets."glats_hashed_password" = {
    neededForUsers = true;
  };

  # Rog-only secrets
  sops.secrets."wireguard/server_private_key" = lib.mkIf isRog { };
  sops.secrets."wireguard/peer_oneplus9_psk" = lib.mkIf isRog { };
  sops.secrets."wireguard/peer_mac_psk" = lib.mkIf isRog { };
  sops.secrets."wireguard/peer_thinkpad_psk" = lib.mkIf isRog { };
  sops.secrets."wireguard/peer_samsung_psk" = lib.mkIf isRog { };
  sops.secrets."wireguard/peer_thinkphone_psk" = lib.mkIf isRog { };

  sops.secrets."ddclient" = lib.mkIf isRog {
    owner = "ddclient";
    group = "ddclient";
    mode = "0400";
  };

  sops.secrets."cloudflare_api_token" = lib.mkIf isRog {
    owner = "acme";
  };

  sops.secrets."guacamole/env" = lib.mkIf isRog { };
}
