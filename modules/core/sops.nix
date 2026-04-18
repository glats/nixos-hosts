{ ... }:

{
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  sops.secrets."wireguard/server_private_key" = { };
  sops.secrets."wireguard/peer_oneplus9_psk" = { };
  sops.secrets."wireguard/peer_mac_psk" = { };
  sops.secrets."wireguard/peer_thinkpad_psk" = { };
  sops.secrets."wireguard/peer_samsung_psk" = { };
  sops.secrets."wireguard/peer_thinkphone_psk" = { };
  sops.secrets."ddclient" = {
    owner = "ddclient";
    group = "ddclient";
    mode = "0400";
  };

  sops.secrets."cloudflare_api_token" = {
    owner = "acme";
  };

  sops.secrets."glats_hashed_password" = {
    neededForUsers = true;
  };

  sops.secrets."guacamole/env" = { };
}
