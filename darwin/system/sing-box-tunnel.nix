# Root sing-box TUN client daemon for the OpenCode tunnel.
#
# Runs as a root LaunchDaemon (sops-nix manages /run/secrets and the
# rendered config template; launchd invokes sing-box with -c pointing at
# the rendered JSON). TUN inbound owns the default route on macOS;
# route rules keep private + corporate + EDR-management traffic direct
# (full mode) or tunnel only chatgpt.com + auth.openai.com (scoped mode).
# A loopback mixed inbound (127.0.0.1:2080) is the Netskope steering
# escape hatch — see the inbound block below for why it exists. Clients
# reach it via per-app/per-browser proxy settings (e.g. the scoped
# bin/opencode-tunnel launcher for OpenCode): a system-wide PAC was
# tried and REMOVED — on managed macOS Netskope owns the SYSTEM-global
# proxy dictionary and shadows per-service networksetup PAC settings
# (see design.md, PR2 addendum).
#
# The VLESS+WS outbound connects to tun.glats.org:443 with a uTLS
# chrome ClientHello to blend into the wider Cloudflare-fronted fleet.
# auto_detect_interface binds the tunnel's outbound to the physical
# NIC so tun.glats.org doesn't loop into the TUN; default_domain_resolver
# forces resolution off-tunnel via a `direct-dns` resolver tag.
#
# The WS path is the same obscuity-not-secret constant used by the
# rog server (linux/system/services/network/sing-box-tunnel.nix),
# nginx vhost (linux/system/services/web/nginx.nix), and the phone
# link script (bin/tunnel-device-link). Generating it once keeps the
# three sites byte-identical without a shared secret.
#
# The `inputs` arg is required by sops-nix templates (Darwin nix-darwin
# modules need access to the flake input). The flake passes `inputs`
# via mkDarwinHost.specialArgs already.
{ config
, lib
, pkgs
, inputs
, ...
}:

let
  # Generated-once random hex (obscurity, not auth).
  wsPath = "/ed59280aa562f4b7eba4519e3c316e24";

  cfg = config.tunnel;

  # Substitute the rendered sops placeholder at build time. The Darwin
  # sops module sets `config.sops.placeholder.<name>` for every declared
  # secret; the activation script replaces the placeholder text with the
  # decrypted secret value.
  uuidMact2 = config.sops.placeholder."opencode-tunnel/uuid_mact2";
  uuidPhone = config.sops.placeholder."opencode-tunnel/uuid_phone";

  # Build the route rules. Ordered (full mode):
  #   1. sniff every connection for protocol metadata
  #   2. hijack-dns so DNS queries can be matched on domain
  #   3. ip_is_private (RFC1918/ULA) -> direct (must come first)
  #   4. ip_cidr in tunnel.directCidrs -> direct
  #   5. domain_suffix in tunnel.directDomains -> direct
  #   6. process_name exclusions (best-effort on macOS standalone; back
  #      them with IP/domain rules as the authoritative gate)
  #   7. final -> "auto" (urltest group: tunnel-out while rog is alive,
  #      automatic fallback to direct when it is not — the Mac degrades to
  #      a normal corporate endpoint behind Netskope, nothing leaks to a
  #      dead tunnel because nothing is sent to rog at all)
  #
  # Scoped mode:
  #   1. domain_suffix chatgpt.com, auth.openai.com -> tunnel-out
  #   2. final -> direct
  fullRules = [
    { action = "sniff"; }
    { protocol = "dns"; action = "hijack-dns"; }
    # ICMP (ping) is unsupported by the VLESS outbound — route it direct.
    # Valid since sing-box 1.13.0 for echo requests from TUN inbounds.
    { network = [ "icmp" ]; outbound = "direct"; }
    { ip_is_private = true; outbound = "direct"; }
  ]
  ++ map (cidr: { ip_cidr = cidr; outbound = "direct"; }) cfg.directCidrs
  ++ map (dom: { domain_suffix = dom; outbound = "direct"; }) cfg.directDomains
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
    { outbound = "tunnel-out"; }
  ];

  scopedRules = [
    { domain_suffix = [ "chatgpt.com" "auth.openai.com" ]; outbound = "tunnel-out"; }
    { outbound = "direct"; }
  ];

  routeRules = if cfg.mode == "full" then fullRules else scopedRules;

  # Full mode routes through the urltest group: probe both paths every
  # minute, use tunnel-out while rog is reachable, fall back to direct
  # (normal corporate filtering via Netskope) when it is not, and switch
  # back automatically on recovery. Scoped mode is unaffected.
  routeFinal = if cfg.mode == "full" then "auto" else "direct";

  # Rendered config JSON. The placeholder substitution happens at
  # activation; we hand sops-install-secrets a JSON file with the
  # placeholder string in the two UUID positions and it rewrites them
  # to the decrypted values before sing-box reads the file.
  configFile = pkgs.writeText "sing-box-tunnel.json" (builtins.toJSON {
    log = { level = "info"; };

    # TUN inbound. Stack "system" uses native utun (needed for process
    # resolution on macOS). auto_route + strict_route claim the default
    # route and prevent DNS leaks / unreachable marking. Sniff is
    # configured via a route action (not on the inbound — that field
    # was removed in sing-box 1.13.0). address uses the merged 1.10+
    # format. mtu is omitted to take the sing-box default.
    inbounds = [
      {
        type = "tun";
        tag = "sb-openai";
        address = [ "172.19.0.1/30" ];
        auto_route = true;
        strict_route = true;
        stack = "system";
      }

      # Loopback mixed inbound (HTTP CONNECT + SOCKS on 127.0.0.1:2080) —
      # the Netskope steering escape hatch. Home evidence FAIL #2
      # (openspec/changes/mact2-openai-tls-tunnel-via-rog/home-evidence.md)
      # showed Netskope's local AppProxy intercepts OpenAI-bound flows at
      # socket level BEFORE they reach the TUN: with the tunnel up,
      # auth.openai.com still presented Netskope's own CA
      # (ca.grupofalabella.goskope.com) instead of the origin cert, because
      # its steering matches the SNI of outbound connections. A loopback
      # CONNECT/SOCKS request carries no SNI for steering to match, so the
      # flow is not intercepted; sing-box unwraps it here and the payload
      # rides the tunnel with outer SNI tun.glats.org only.
      #
      # No inbound-specific route rules: mixed-in traffic flows through
      # the same route rules + final as TUN traffic (full → "auto"
      # urltest, scoped → domain_suffix → "direct") — that is the desired
      # semantic. CONNECT/SOCKS request targets are hostnames, so the
      # scoped domain_suffix rules match them without sniffing.
      # `listen_port` is the sing-box 1.11+ unified inbound field
      # (verified against sing-box 1.13.19 schema).
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
        tag = "tunnel-out";
        server = "tun.glats.org";
        server_port = 443;
        uuid = uuidMact2;
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
          # Host header goes in headers, not in a top-level `host`
          # field — that field exists on HTTP transport but not on
          # WebSocket (verified against sing-box 1.13.19 schema).
          headers = { Host = "tun.glats.org"; };
        };
      }
      { type = "direct"; tag = "direct"; }
      { type = "block"; tag = "block"; }
      # Resilience group: full-mode final. urltest probes gstatic 204
      # through each child; tunnel-out wins while rog answers, direct
      # takes over when it does not, and the switch back is automatic.
      {
        type = "urltest";
        tag = "auto";
        outbounds = [ "tunnel-out" "direct" ];
        url = "https://www.gstatic.com/generate_204";
        interval = "1m";
        tolerance = 50;
      }
    ];

    # DNS: a dedicated direct resolver is required so the host lookup
    # of `tun.glats.org` (the tunnel endpoint) does NOT loop into the
    # TUN. Without this, every tunnel startup is a chicken-and-egg
    # recursive failure. Uses sing-box 1.12+ server format (the legacy
    # `address: "1.1.1.1"` shorthand is deprecated and rejected in
    # 1.14).
    #
    # NOTE: no `detour` here — sing-box 1.13 DNS dialers already default
    # to an empty direct outbound, and an explicit detour to a direct
    # outbound is a fatal error ("detour to an empty direct outbound
    # makes no sense"). With route.auto_detect_interface the dialer
    # binds to the physical NIC, which is the off-tunnel path we want.
    dns = {
      servers = [
        {
          tag = "direct-dns";
          type = "udp";
          server = "1.1.1.1";
        }
      ];
    };

    # Route. auto_detect_interface binds the tunnel's outbound
    # connection to the physical NIC; default_domain_resolver keeps
    # endpoint hostname resolution off-tunnel. Both are required for
    # boot, not optional hardening.
    route = {
      auto_detect_interface = true;
      default_domain_resolver = "direct-dns";
      rules = routeRules;
      final = routeFinal;
    };
  });

in
{
  options.tunnel = {
    mode = lib.mkOption {
      type = lib.types.enum [ "full" "scoped" ];
      default = "full";
      description = ''
        Routing mode for the sing-box TUN client.
        `full` sends all traffic to the tunnel except ip_is_private,
        tunnel.directCidrs, tunnel.directDomains, and known EDR
        process names — those go direct.
        `scoped` tunnels only chatgpt.com + auth.openai.com and sends
        everything else direct.
      '';
    };

    directDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "company.com" "vendor.example" ];
      description = ''
        Domains matched via domain_suffix that must always go direct
        (corporate, Netskope/CrowdStrike/FortiClient management,
        etc.). Empty by default — populate as endpoints are confirmed.
      '';
    };

    directCidrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "10.0.0.0/8" "192.168.0.0/16" ];
      description = ''
        CIDRs that must always go direct (corporate subnets, EDR
        management networks, LAN ranges the user wants to reach
        without TUN). Empty by default — populate as endpoints are
        confirmed.
      '';
    };
  };

  config = {
    # Sops-nix: declare the per-device UUIDs we need. The phone secret
    # is declared here even though only mact2 uses the tunnel outbound,
    # because bin/tunnel-device-link reads the rendered phone UUID file
    # on the same host when generating share links.
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    sops.secrets."opencode-tunnel/uuid_mact2" = {
      sopsFile = ../../secrets/shared/opencode-tunnel.yaml;
      key = "uuid_mact2";
      owner = "root";
      mode = "0400";
    };
    sops.secrets."opencode-tunnel/uuid_phone" = {
      sopsFile = ../../secrets/shared/opencode-tunnel.yaml;
      key = "uuid_phone";
      owner = "root";
      mode = "0400";
    };

    # Rendered config. sops-install-secrets walks the placeholders and
    # writes the final JSON at activation time.
    sops.templates."sing-box-tunnel.json" = {
      owner = "root";
      mode = "0400";
      file = configFile;
    };

    # Root LaunchDaemon. Requires root for utun creation on macOS.
    # KeepAlive retries if launchd races sops-install-secrets.
    # WorkingDirectory /var/empty is the macOS root-sandbox dir.
    # Umask 0077 ensures the rendered config file stays root-only.
    launchd.daemons.sing-box-tunnel = {
      command = "${pkgs.sing-box}/bin/sing-box run -c /run/secrets/rendered/sing-box-tunnel.json";
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        WorkingDirectory = "/var/empty";
        Umask = 63; # 0077 — root-only files
        StandardOutPath = "/var/log/sing-box-tunnel.log";
        StandardErrorPath = "/var/log/sing-box-tunnel.log";
      };
    };
  };
}
