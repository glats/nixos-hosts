# Root sing-box TUN client daemon of the mact2↔rog private link.
#
# Runs as a root LaunchDaemon (sops-nix manages /run/secrets and the
# rendered config template; launchd invokes sing-box with -c pointing at
# the rendered JSON). TUN inbound owns the default route on macOS;
# route rules keep private + corporate + EDR-management traffic direct
# (full mode) or send only chatgpt.com + auth.openai.com through the
# link (scoped mode). A loopback mixed inbound (127.0.0.1:2080) is the
# alternate per-app door — see the inbound block below for why it
# exists. It serves ANY app whose traffic the endpoint security agent
# intercepts at socket level (browser OAuth, the OpenCode runtime,
# arbitrary GUI/CLI tools) via per-app/per-browser proxy settings;
# OpenCode's scoped bin/opencode-home launcher is just the flagship
# consumer. A system-wide PAC was tried and REMOVED — on managed macOS
# the endpoint security agent owns the SYSTEM-global proxy dictionary
# and shadows per-service networksetup PAC settings.
#
# The VLESS+WS outbound connects to tun.glats.org:443 with a uTLS
# chrome ClientHello to blend into the wider Cloudflare-fronted fleet.
# auto_detect_interface binds the link's outbound to the physical NIC
# so tun.glats.org doesn't loop into the TUN; default_domain_resolver
# forces resolution off-link via a `direct-dns` resolver tag.
#
# The WS path is the same obscurity-not-secret constant used by the
# rog server (linux/system/services/network/sing-box-link.nix),
# nginx vhost (linux/system/services/web/nginx.nix), and the phone
# link script (bin/device-link). Generating it once keeps the three
# sites byte-identical without a shared secret.
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

  cfg = config.link;

  # Substitute the rendered sops placeholder at build time. The Darwin
  # sops module sets `config.sops.placeholder.<name>` for every declared
  # secret; the activation script replaces the placeholder text with the
  # decrypted secret value.
  uuidMact2 = config.sops.placeholder."link/uuid_mact2";
  uuidPhone = config.sops.placeholder."link/uuid_phone";

  # Build the route rules. Ordered (full mode):
  #   1. sniff every connection for protocol metadata
  #   2. hijack-dns so DNS queries can be matched on domain
  #   3. block QUIC (UDP/443) — urltest probes TCP only and keeps a
  #      separate UDP selection that does NOT fail over (seen live in the
  #      2026-08 rog outage: TCP degraded to direct while UDP stayed pinned
  #      to the dead home-out). Blocking QUIC forces browsers/HTTP-3
  #      clients onto TCP, the path with working failover. Not needed in
  #      scoped mode: final is direct there, so UDP/443 has no link
  #      dependency.
  #   4. ip_is_private (RFC1918/ULA) -> direct (must come first)
  #   5. ip_cidr in link.directCidrs -> direct
  #   6. domain_suffix in link.directDomains -> direct
  #   7. process_name exclusions (best-effort on macOS standalone; back
  #      them with IP/domain rules as the authoritative gate)
  #   8. final -> "auto" (urltest group: home-out while rog is alive,
  #      automatic fallback to direct within the ≤30s probe window when it
  #      is not — the Mac degrades to a normal corporate endpoint behind
  #      the endpoint security agent, nothing is sent to a dead link)
  #
  # Scoped mode:
  #   1. domain_suffix chatgpt.com, auth.openai.com -> home-out
  #   2. final -> direct
  fullRules = [
    { action = "sniff"; }
    { protocol = "dns"; action = "hijack-dns"; }
    # Reject QUIC (UDP/443): sing-box urltest probes TCP only and keeps a
    # SEPARATE UDP selection that never fails over — during the 2-day rog
    # outage TCP degraded to direct while UDP stayed pinned to the dead
    # home-out (76× "no route to internet" on vless). Blocking QUIC
    # forces browsers (QUIC/HTTP-3) onto TCP, the path with working
    # failover; standard practice when the link is unstable. Scoped mode
    # needs no equivalent (final is direct, so UDP/443 carries no link
    # dependency).
    { network = [ "udp" ]; port = [ 443 ]; outbound = "block"; }
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
    { outbound = "home-out"; }
  ];

  scopedRules = [
    { domain_suffix = [ "chatgpt.com" "auth.openai.com" ]; outbound = "home-out"; }
    { outbound = "direct"; }
  ];

  routeRules = if cfg.mode == "full" then fullRules else scopedRules;

  # Full mode routes through the urltest group: probe both paths every
  # 30 seconds, use home-out while rog is reachable, fall back to direct
  # (normal corporate filtering via the endpoint security agent) within
  # that ≤30s window when it is not, and switch back automatically on
  # recovery. QUIC is blocked (see fullRules), so everything through the
  # link rides TCP. Scoped mode is unaffected.
  routeFinal = if cfg.mode == "full" then "auto" else "direct";

  # Rendered config JSON. The placeholder substitution happens at
  # activation; we hand sops-install-secrets a JSON file with the
  # placeholder string in the two UUID positions and it rewrites them
  # to the decrypted values before sing-box reads the file.
  configFile = pkgs.writeText "sing-box.json" (builtins.toJSON {
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
      # the alternate per-app door. The endpoint security agent's local
      # AppProxy intercepts OpenAI-bound flows at socket level BEFORE
      # they reach the TUN: with the link up, auth.openai.com still
      # presented the corporate CA ("el CA corporativo") instead of the
      # origin cert, because its category routing matches the SNI of
      # outbound connections. A loopback CONNECT/SOCKS request carries
      # no SNI for that matching to act on, so the flow is not
      # intercepted; sing-box unwraps it here and the payload rides the
      # link with outer SNI tun.glats.org only.
      #
      # Any app that can take a per-app proxy can ride this door —
      # browser OAuth flows, the OpenCode runtime, arbitrary GUI/CLI
      # tools — with OpenCode as the flagship consumer, not the purpose.
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
        tag = "home-out";
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
      # through each child every 30s; home-out wins while rog answers,
      # direct takes over within that window when it does not, and the
      # switch back is automatic. interrupt_exist_connections kills
      # connections riding the previously selected outbound the moment the
      # selection flips — without it, established flows (e.g. long-lived
      # WS) would keep heading into a dead link until they fail on their
      # own. urltest still probes TCP only (its UDP selection never fails
      # over), which is why the route rules block QUIC in full mode.
      #
      # Order matters as a SAFE DEFAULT: "direct" is listed first because
      # sing-box urltest Select() falls back to the FIRST entry of the
      # list when no probe history exists yet (source-verified) — i.e.
      # on boot or fresh config, before the first probe lands, the group
      # selects direct: the Mac behaves like a normal corporate endpoint
      # instead of pushing traffic at a possibly-dead link. Once history
      # exists, lowest-latency selection (with `tolerance`) applies as
      # usual and the 30s probe keeps it current.
      {
        type = "urltest";
        tag = "auto";
        outbounds = [ "direct" "home-out" ];
        url = "https://www.gstatic.com/generate_204";
        interval = "30s";
        tolerance = 50;
        interrupt_exist_connections = true;
      }
    ];

    # DNS: a dedicated direct resolver is required so the host lookup
    # of `tun.glats.org` (the link endpoint) does NOT loop into the
    # TUN. Without this, every link startup is a chicken-and-egg
    # recursive failure. Uses sing-box 1.12+ server format (the legacy
    # `address: "1.1.1.1"` shorthand is deprecated and rejected in
    # 1.14).
    #
    # NOTE: no `detour` here — sing-box 1.13 DNS dialers already default
    # to an empty direct outbound, and an explicit detour to a direct
    # outbound is a fatal error ("detour to an empty direct outbound
    # makes no sense"). With route.auto_detect_interface the dialer
    # binds to the physical NIC, which is the off-link path we want.
    dns = {
      servers = [
        {
          tag = "direct-dns";
          type = "udp";
          server = "1.1.1.1";
        }
      ];
    };

    # Route. auto_detect_interface binds the link's outbound
    # connection to the physical NIC; default_domain_resolver keeps
    # endpoint hostname resolution off-link. Both are required for
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
  options.link = {
    mode = lib.mkOption {
      type = lib.types.enum [ "full" "scoped" ];
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
      example = [ "company.com" "vendor.example" ];
      description = ''
        Domains matched via domain_suffix that must always go direct
        (corporate, endpoint security / EDR management, etc.). Empty
        by default — populate as endpoints are confirmed.
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
    # is declared here even though only mact2 uses the link outbound,
    # because bin/device-link reads the rendered phone UUID file on the
    # same host when generating share links.
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    sops.secrets."link/uuid_mact2" = {
      sopsFile = ../../secrets/shared/link-uuids.yaml;
      key = "uuid_mact2";
      owner = "root";
      mode = "0400";
    };
    sops.secrets."link/uuid_phone" = {
      sopsFile = ../../secrets/shared/link-uuids.yaml;
      key = "uuid_phone";
      owner = "root";
      mode = "0400";
    };

    # Rendered config. sops-install-secrets walks the placeholders and
    # writes the final JSON at activation time.
    sops.templates."sing-box.json" = {
      owner = "root";
      mode = "0400";
      file = configFile;
    };

    # Root LaunchDaemon. Requires root for utun creation on macOS.
    # Manual-operation daemon: the user raises it with launchctl kickstart
    # (after a bootout, bootstrap re-registers first — bootstrap alone does
    # NOT start a job without RunAtLoad/demand triggers, per launchd.plist(5))
    # when the home server is reachable. Never autostarts at boot; if it
    # exits, it stays down (expected — the corporate path works without it).
    # WorkingDirectory /var/empty is the macOS root-sandbox dir.
    # Umask 0077 ensures the rendered config file stays root-only.
    launchd.daemons.sing-box = {
      command = "${pkgs.sing-box}/bin/sing-box run -c /run/secrets/rendered/sing-box.json";
      serviceConfig = {
        RunAtLoad = false;
        KeepAlive = false;
        WorkingDirectory = "/var/empty";
        Umask = 63; # 0077 — root-only files
        StandardOutPath = "/var/log/sing-box.log";
        StandardErrorPath = "/var/log/sing-box.log";
      };
    };
  };
}
