{ config, pkgs, ... }:

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
    internalIPs = [ "10.13.13.0/24" ];
  };

  # DNS for WireGuard peers
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      listen-address = "10.13.13.1";
      bind-interfaces = true;
      server = [ "1.1.1.1" "8.8.8.8" ];
    };
  };

  # WireGuard interface
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.13.13.1/24" ];
    listenPort = 51820;
    privateKeyFile = config.sops.secrets."wireguard/server_private_key".path;

    peers = [
      {
        # oneplus9
        publicKey = "de+Fwke7uLseeAd4LxWpUIFMXqOZfxAGqY1IOWmS6zc=";
        presharedKeyFile = config.sops.secrets."wireguard/peer_oneplus9_psk".path;
        allowedIPs = [ "10.13.13.2/32" ];
      }
      {
        # mac
        publicKey = "/8U4mjny+N01cXgqqFsQ+cZKZWBzJLrVu1YsjVfnDXA=";
        presharedKeyFile = config.sops.secrets."wireguard/peer_mac_psk".path;
        allowedIPs = [ "10.13.13.3/32" ];
      }
      {
        # thinkpad
        publicKey = "QFMVaBmcZq4B9Ku4fhXzM+Zd8vPq4MMoLCcTxDOQRF8=";
        presharedKeyFile = config.sops.secrets."wireguard/peer_thinkpad_psk".path;
        allowedIPs = [ "10.13.13.4/32" ];
      }
      {
        # samsung
        publicKey = "L2Ven52rFTK4JCtnHZ7JC3fttcWaljFspj0PRZiX+Xw=";
        presharedKeyFile = config.sops.secrets."wireguard/peer_samsung_psk".path;
        allowedIPs = [ "10.13.13.5/32" ];
      }
      {
        # thinkphone
        publicKey = "zvRP554xr2NbuKisHEawwhsBmSqDZRy/mr9aGNEkR3w=";
        presharedKeyFile = config.sops.secrets."wireguard/peer_thinkphone_psk".path;
        allowedIPs = [ "10.13.13.6/32" ];
      }
    ];
  };
}
