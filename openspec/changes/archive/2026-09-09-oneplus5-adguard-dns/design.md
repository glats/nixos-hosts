# Design: OnePlus 5 AdGuard DNS

## Context

The OnePlus 5 is an always-on postmarketOS/systemd host; Alpine provides AdGuard Home 0.107.79 but no systemd unit. Three repository artifacts define log-only DNS for manually enrolled TVs. Version 0.107.79 source confirms schema 34 and the nested forms below.

## Goals / Non-Goals

Provide stable LAN-only DNS, per-TV visibility, opt-in filtering, reproducible deployment, and TV-first rollback. Do not change DHCP, Nix, scripts, non-TV DNS, or intercept hardcoded resolvers.

## Decisions

| # | Choice and rationale | Rejected alternatives |
|---|---|---|
| 1 | Keep `172.16.0.12` on DHCP **only after** a Xiaomi reservation maps the phone MAC to `.12`; reconnect twice and confirm each lease. Otherwise prove `.12` is outside the displayed pool before making `JICS` manual, or halt. | Manual+reservation duplicates state; static-only risks collision. |
| 2 | Primary `9.9.9.10`, fallback `1.1.1.1`; bootstrap both with `:53`. Numeric resolvers avoid router-DNS dependence; bootstrap supports future named upstreams. | Router DNS couples forwarding; balancing both obscures fallback. |
| 3 | Bind UI to `172.16.0.12:3000`. Corrected after apply: the phone runs a curated nftables allowlist (`/etc/nftables.nft`, input policy drop) that does NOT accept `:3000` from the LAN, so LAN-browser access is blocked by design; the operator path is the SSH tunnel helper (`adguard-tunnel`, Req 10). Never wildcard/Tailscale-bind or port-forward it. | Wildcard exposes Tailscale/other interfaces; localhost prevents LAN administration; opening 3000 on the firewall requires an operator opt-in plus UI auth first. |
| 4 | Query log `7d`; statistics `24h`: bounded storage with daily summaries. | Longer logs increase state; `1d` is too short. |
| 5 | Ship no lists. Runbook uses **Filters → DNS blocklists → Add blocklist → Add a custom list**, enables filtering, then tests one TV. URLs: `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.samsung.txt`, `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.lgwebos.txt`, `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.roku.txt`, `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.amazon.txt`, `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.apple.txt`. | Preloading violates opt-in; CDN aliases add indirection. |
| 6 | Run as `adguardhome`, grant only `CAP_NET_BIND_SERVICE`, wait for NetworkManager online, restart always after 5s, and use modest filesystem hardening with explicit writable state/config paths. | Root is unnecessary; aggressive isolation risks Alpine/AGH breakage. |
| 7 | Schema-34 baseline below: filtering/protection/safety features off, no rules/lists, 32 MiB optimistic cache, rate limit `50` per client, identifiable IPs, DHCP off. `50` protects the exposed LAN socket without constraining normal TVs. | `0` removes abuse protection; default active filters violate log-only. |
| 8 | Redeploy via `/tmp`: stop, install ownership/modes, daemon-reload, restart, verify; this corrects drift without write races. | UI-only edits are irreproducible. |
| 9 | Runbook order: prerequisites; static-IP gate; install; deploy/start; verify; enroll TVs by brand; name clients/read logs; HaGeZi opt-in; redeploy/drift; rollback; troubleshooting. | Mixing filtering into installation weakens the log-only gate. |
| 10 | Troubleshooting detects hardcoded `8.8.8.8` as a TV that resolves but stays silent in AGH logs; retry its manual DNS control or accept the blind spot. | Redirecting/blocking `8.8.8.8` requires router policy and is out of scope. |

## Architecture Diagram

```text
TV (manual DNS) ──UDP/TCP 53──> OnePlus 5 / AdGuard Home ──> 9.9.9.10
                                      │                       └─fail→ 1.1.1.1
LAN browser ─────172.16.0.12:3000─────┘
Other clients ───────────────> Xiaomi/router DNS (unchanged)
```

## Detailed Design

Unit draft (`docs/oneplus5-adguard-dns/adguardhome.service`):

```ini
[Unit]
After=network-online.target NetworkManager-wait-online.service
Wants=network-online.target NetworkManager-wait-online.service
[Service]
User=adguardhome
Group=adguardhome
ExecStart=/usr/bin/adguardhome -s run --config /etc/adguardhome/AdGuardHome.yaml --work-dir /var/lib/adguardhome
Restart=always
RestartSec=5s
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=/etc/adguardhome /var/lib/adguardhome
[Install]
WantedBy=multi-user.target
```

Baseline draft (`docs/oneplus5-adguard-dns/AdGuardHome.yaml`); empty collections prove no filtering. Add `samsung-tv`, `lg-tv`, etc. through the UI using actual stable TV addresses.

```yaml
http: {address: "172.16.0.12:3000"}
dns:
  bind_hosts: [172.16.0.12]
  port: 53
  upstream_dns: [9.9.9.10]
  fallback_dns: [1.1.1.1]
  bootstrap_dns: ["9.9.9.10:53", "1.1.1.1:53"]
  upstream_mode: load_balance
  ratelimit: 50
  cache_enabled: true
  cache_size: 33554432
  cache_optimistic: true
  anonymize_client_ip: false
filtering:
  protection_enabled: false
  filtering_enabled: false
  safebrowsing_enabled: false
  parental_enabled: false
  safe_search: {enabled: false}
filters: []
whitelist_filters: []
user_rules: []
querylog: {enabled: true, file_enabled: true, interval: 7d, size_memory: 1000}
statistics: {enabled: true, interval: 24h}
clients:
  persistent: []
  runtime_sources: {whois: false, arp: true, rdns: true, dhcp: false, hosts: true}
dhcp: {enabled: false}
tls: {enabled: false}
schema_version: 34
```

Redeploy section commands: `scp -i ~/.ssh/oneplus5 docs/oneplus5-adguard-dns/{AdGuardHome.yaml,adguardhome.service} glats@172.16.0.12:/tmp/`; remotely run `sudo install -d -o adguardhome -g adguardhome /etc/adguardhome /var/lib/adguardhome`, `sudo systemctl stop adguardhome`, `sudo install -o adguardhome -g adguardhome -m 0640 /tmp/AdGuardHome.yaml /etc/adguardhome/AdGuardHome.yaml`, `sudo install -o root -g root -m 0644 /tmp/adguardhome.service /etc/systemd/system/adguardhome.service`, then `sudo systemctl daemon-reload && sudo systemctl enable --now adguardhome`. Verify with `systemctl`, `ss`, `dig @172.16.0.12 example.com`, UI access, a named-TV query, and zero enabled filters; reboot-test once. Repository checks are artifact inspection plus `nix flake check --no-build`.

Threat matrix: documentation-like paths, Git selection, commit, push, and PR commands are **N/A**: no classifier or VCS automation exists. Process RED checks cover invalid YAML, absent LAN address, and writable paths under hardening.

## Risks / Trade-offs

The phone/Wi-Fi remains a DNS single point for enrolled TVs; rollback starts by restoring TV automatic/router DNS. UI is plaintext on `.12:3000`; the phone's curated nftables allowlist blocks LAN TCP/3000 (apply-discovered), so operator access goes through the `adguard-tunnel` SSH tunnel and never through a port-forward. AGH may rewrite YAML after UI changes; redeploy intentionally removes drift and opt-in lists. Apply must validate schema/startup before enrolling TVs.

## Open Questions

None.
