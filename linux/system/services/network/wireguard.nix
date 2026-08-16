{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib) mapAttrsToList;
  wgTools = pkgs.wireguard-tools;

  # --- Peer definitions (single source of truth) ---
  # Blocks between the wg-peer markers are managed by `wg-peer` (bin/wg-peer).
  peers = {
    # --- wg-peer:managed-start ---
    oneplus9 = {
      ip = "10.13.13.2";
      publicKey = "EsGamd57GFCaTxEk50FqU0Xya4bLmj2ij3l1AC8F/ig=";
      psk = config.sops.secrets."wireguard/peer_oneplus9_psk";
    };
    mac = {
      ip = "10.13.13.3";
      publicKey = "9MFatUrExdDzaIJpvcFPVUTPFyN5wT9uV2nnc3YCA28=";
      psk = config.sops.secrets."wireguard/peer_mac_psk";
    };
    thinkpad = {
      ip = "10.13.13.4";
      publicKey = "QFMVaBmcZq4B9Ku4fhXzM+Zd8vPq4MMoLCcTxDOQRF8=";
      psk = config.sops.secrets."wireguard/peer_thinkpad_psk";
    };
    samsung = {
      ip = "10.13.13.5";
      publicKey = "L2Ven52rFTK4JCtnHZ7JC3fttcWaljFspj0PRZiX+Xw=";
      psk = config.sops.secrets."wireguard/peer_samsung_psk";
    };
    thinkphone = {
      ip = "10.13.13.6";
      publicKey = "PUJEcWsMCTOfENyZYqoRRiPx9VZVAr3gXjP0BCT6+38=";
      psk = config.sops.secrets."wireguard/peer_thinkphone_psk";
    };
    # --- wg-peer:managed-end ---
  };

  # WireGuard interface IP
  serverIP = "10.13.13.1";
  serverEndpoint = "guard.glats.org";

  # Convert peers attrset to NixOS peer configs
  mkWireGuardPeers = mapAttrsToList (
    _: p: {
      publicKey = p.publicKey;
      presharedKeyFile = lib.mkIf (p.psk != null) p.psk.path;
      allowedIPs = [ "${p.ip}/32" ];
    }
  );
in
{
  # Enable IP forwarding
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv4.conf.all.src_valid_mark" = 1;
  };

  # NAT for peers (using internalIPs instead of externalInterface
  # to support multiple network interfaces: ethernet and WiFi)
  networking.nat = {
    enable = true;
    internalIPs = [ "${serverIP}/24" ];
  };

  # DNS for WireGuard peers
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      listen-address = serverIP;
      bind-interfaces = true;
      server = [
        "1.1.1.1"
        "8.8.8.8"
      ];
    };
  };

  # WireGuard interface
  networking.wireguard.interfaces.wg0 = {
    ips = [ "${serverIP}/24" ];
    listenPort = 51820;
    privateKeyFile = config.sops.secrets."wireguard/server_private_key".path;
    peers = mkWireGuardPeers peers;
  };

  # --- Generate client configs at activation time ---
  # Produces /etc/wireguard/clients/<name>.conf for each peer.
  # Client private key must be generated on the client itself.
  system.activationScripts.wireguard-client-configs = ''
    mkdir -p /etc/wireguard/clients

    SERVER_PUB=$(${wgTools}/bin/wg pubkey < ${config.sops.secrets."wireguard/server_private_key".path})

    ${builtins.concatStringsSep "\n" (
      mapAttrsToList (name: p: ''
            ${if p.psk != null then "PSK=$(cat ${p.psk.path})" else "PSK="}
            cat > /etc/wireguard/clients/${name}.conf << CONF
        [Interface]
        Address = ${p.ip}/32
        # PrivateKey = /etc/wireguard/${name}.key
        # Generate: wg genkey | sudo tee /etc/wireguard/${name}.key | wg pubkey
        DNS = ${serverIP}

        [Peer]
        PublicKey = $SERVER_PUB
        ${if p.psk != null then "PresharedKey = $PSK" else "# no PresharedKey configured"}
        AllowedIPs = 10.13.13.0/24, 172.16.0.0/24
        Endpoint = ${serverEndpoint}:51820
        PersistentKeepalive = 25
        CONF
      '') peers
    )}

    chmod 600 /etc/wireguard/clients/*
  '';
}
