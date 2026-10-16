{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  wsPath = "/ed59280aa562f4b7eba4519e3c316e24";

  cfg = config.link;

  uuidValue = config.sops.placeholder."link/uuid_macm5";
  uuidPhone = config.sops.placeholder."link/uuid_phone";

  fullRules = [
    { action = "sniff"; }
    {
      protocol = "dns";
      action = "hijack-dns";
    }
    {
      network = [ "udp" ];
      port = [ 443 ];
      outbound = "block";
    }
    {
      network = [ "icmp" ];
      outbound = "direct";
    }
    {
      ip_is_private = true;
      outbound = "direct";
    }
  ]
  ++ map (cidr: {
    ip_cidr = cidr;
    outbound = "direct";
  }) cfg.directCidrs
  ++ map (dom: {
    domain_suffix = dom;
    outbound = "direct";
  }) cfg.directDomains
  ++ [
    {
      process_name = [
        "falcon-sensor"
        "falconctl"
        "nsproxy"
        "Netskope Client"
        "forticlient"
      ];
      outbound = "direct";
    }
    { outbound = "home-out"; }
  ];

  scopedRules = [
    {
      domain_suffix = [
        "chatgpt.com"
        "auth.openai.com"
      ];
      outbound = "home-out";
    }
    { outbound = "direct"; }
  ];

  routeRules = if cfg.mode == "full" then fullRules else scopedRules;

  routeFinal = if cfg.mode == "full" then "auto" else "direct";

  configFile = pkgs.writeText "sing-box.json" (
    builtins.toJSON {
      log = {
        level = "info";
      };

      inbounds = [
        {
          type = "tun";
          tag = "sb-openai";
          address = [ "172.19.0.1/30" ];
          auto_route = true;
          strict_route = true;
          stack = "system";
        }

        {
          type = "mixed";
          tag = "mixed-in";
          listen = "127.0.0.1";
          listen_port = 2080;
        }
      ];

      outbounds = [
        {
          type = "vless";
          tag = "home-out";
          server = "tun.glats.org";
          server_port = 443;
          uuid = uuidValue;
          tls = {
            enabled = true;
            server_name = "tun.glats.org";
            utls = {
              enabled = true;
              fingerprint = "chrome";
            };
          };
          transport = {
            type = "ws";
            path = wsPath;
            headers = {
              Host = "tun.glats.org";
            };
          };
        }
        {
          type = "direct";
          tag = "direct";
        }
        {
          type = "block";
          tag = "block";
        }
        {
          type = "urltest";
          tag = "auto";
          outbounds = [
            "direct"
            "home-out"
          ];
          url = "https://www.gstatic.com/generate_204";
          interval = "30s";
          tolerance = 50;
          interrupt_exist_connections = true;
        }
      ];

      dns = {
        servers = [
          {
            tag = "direct-dns";
            type = "udp";
            server = "1.1.1.1";
          }
        ];
      };

      route = {
        auto_detect_interface = true;
        default_domain_resolver = "direct-dns";
        rules = routeRules;
        final = routeFinal;
      };
    }
  );

in
{
  options.link = {
    mode = lib.mkOption {
      type = lib.types.enum [
        "full"
        "scoped"
      ];
      default = "full";
      description = ''
        Routing mode for the sing-box TUN client.
        `full` sends all traffic through the link except ip_is_private,
        link.directCidrs, link.directDomains, and known EDR
        process names — those go direct.
        `scoped` sends only chatgpt.com + auth.openai.com through the
        link and everything else direct.
      '';
    };

    directDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "company.com"
        "vendor.example"
      ];
      description = ''
        Domains matched via domain_suffix that must always go direct
        (corporate, endpoint security / EDR management, etc.). Empty
        by default — populate as endpoints are confirmed.
      '';
    };

    directCidrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "10.0.0.0/8"
        "192.168.0.0/16"
      ];
      description = ''
        CIDRs that must always go direct (corporate subnets, EDR
        management networks, LAN ranges the user wants to reach
        without TUN). Empty by default — populate as endpoints are
        confirmed.
      '';
    };
  };

  config = {
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    sops.secrets."link/uuid_macm5" = {
      sopsFile = ../../secrets/shared/link-uuids.yaml;
      key = "uuid_macm5";
      owner = "root";
      mode = "0400";
    };
    sops.secrets."link/uuid_phone" = {
      sopsFile = ../../secrets/shared/link-uuids.yaml;
      key = "uuid_phone";
      owner = "root";
      mode = "0400";
    };

    sops.templates."sing-box.json" = {
      owner = "root";
      mode = "0400";
      file = configFile;
    };

    launchd.daemons.sing-box = {
      command = "${pkgs.sing-box}/bin/sing-box run -c /run/secrets/rendered/sing-box.json";
      serviceConfig = {
        RunAtLoad = false;
        KeepAlive = false;
        WorkingDirectory = "/var/empty";
        Umask = 63;
        StandardOutPath = "/var/log/sing-box.log";
        StandardErrorPath = "/var/log/sing-box.log";
      };
    };
  };
}
