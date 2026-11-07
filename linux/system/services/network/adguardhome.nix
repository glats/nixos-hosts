{ lib, ... }:

let
  routerAddress = "172.16.0.1";
  dnsAddress = "172.16.0.12";

  userRules = lib.filter (rule: rule != "") (
    lib.splitString "\n" (builtins.readFile ./adguardhome-rules.txt)
  );

  mkClient =
    {
      name,
      ids,
      uid,
    }:
    {
      inherit name ids uid;
      tags = [ ];
      upstreams = [ ];
      upstreams_cache_enabled = false;
      upstreams_cache_size = 0;
      use_global_settings = true;
      filtering_enabled = false;
      parental_enabled = false;
      safebrowsing_enabled = false;
      use_global_blocked_services = true;
      ignore_querylog = false;
      ignore_statistics = false;
      safe_search = {
        enabled = false;
        bing = false;
        duckduckgo = false;
        ecosia = false;
        google = false;
        pixabay = false;
        yandex = false;
        youtube = false;
      };
      blocked_services = {
        schedule.time_zone = "UTC";
        ids = [ ];
      };
    };
in
{
  services.adguardhome = {
    enable = true;
    host = "127.0.0.1";
    port = 3000;
    mutableSettings = false;
    openFirewall = false;

    settings = {
      language = "";
      theme = "auto";

      dns = {
        bind_hosts = [ dnsAddress ];
        port = 53;
        ratelimit = 50;
        ratelimit_subnet_len_ipv4 = 24;
        ratelimit_subnet_len_ipv6 = 56;
        refuse_any = true;
        upstream_dns = [
          "[/lan/]${routerAddress}:53"
          "[/172.16.in-addr.arpa/]${routerAddress}:53"
          "tcp://149.112.112.10"
          "tcp://9.9.9.10"
        ];
        bootstrap_dns = [
          "9.9.9.10:53"
          "1.1.1.1:53"
        ];
        fallback_dns = [
          "9.9.9.9"
          "149.112.112.112"
        ];
        upstream_mode = "parallel";
        fastest_timeout = "1s";
        upstream_timeout = "10s";
        blocked_hosts = [
          "version.bind"
          "id.server"
          "hostname.bind"
        ];
        trusted_proxies = [
          "127.0.0.0/8"
          "::1/128"
        ];
        cache_enabled = true;
        cache_size = 33554432;
        cache_ttl_min = 0;
        cache_ttl_max = 0;
        cache_optimistic = true;
        cache_optimistic_answer_ttl = "30s";
        cache_optimistic_max_age = "12h";
        enable_dnssec = true;
        max_goroutines = 300;
        handle_ddr = true;
        hostsfile_enabled = true;
        serve_plain_dns = true;
        use_private_ptr_resolvers = true;
        local_ptr_upstreams = [ "${routerAddress}:53" ];
        pending_requests.enabled = true;
      };

      querylog = {
        enabled = true;
        file_enabled = true;
        interval = "7d";
        size_memory = 1000;
      };

      statistics = {
        enabled = true;
        interval = "1d";
      };

      filtering = {
        filtering_enabled = true;
        protection_enabled = true;
        parental_enabled = false;
        safebrowsing_enabled = false;
        rewrites_enabled = true;
        rewrites = [ ];
        blocking_mode = "default";
        blocked_response_ttl = 10;
        cache_time = 30;
        filters_update_interval = 24;
        max_http_size = "256MB";
      };

      filters = [
        {
          enabled = true;
          url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/light.txt";
          name = "HaGeZi Multi LIGHT";
          id = 1792291649;
        }
        {
          enabled = true;
          url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.mini.txt";
          name = "HaGeZi Threat Intelligence Feeds MINI";
          id = 1792291650;
        }
      ];
      whitelist_filters = [ ];
      user_rules = userRules;

      clients = {
        runtime_sources = {
          whois = false;
          arp = true;
          rdns = true;
          dhcp = false;
          hosts = true;
        };
        persistent = [
          (mkClient {
            name = "android-tv";
            ids = [ "172.16.0.8" ];
            uid = "01a088fc-7ef6-76b4-a2d1-92bb939fb37e";
          })
          (mkClient {
            name = "android-tv-2";
            ids = [ "172.16.0.7" ];
            uid = "01a08c65-d3fe-7290-b766-6f1c9c222b0b";
          })
          (mkClient {
            name = "lg-tv";
            ids = [
              "172.16.0.22"
              "172.16.0.237"
            ];
            uid = "01a15b93-d64d-783b-943d-4c15c7c82d62";
          })
          (mkClient {
            name = "roku";
            ids = [ "172.16.0.14" ];
            uid = "01a15b93-d61c-7e1b-8cdb-d9ad622aed4d";
          })
        ];
      };

      dhcp.enabled = false;

      log = {
        enabled = true;
        file = "";
        max_backups = 0;
        max_size = 100;
        max_age = 3;
        compress = false;
        local_time = false;
        verbose = false;
      };
    };
  };

  systemd.services.adguardhome = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
