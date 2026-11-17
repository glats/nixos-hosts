# LAN DNS enforcement: force all clients through AdGuard, router as last-resort resolver

Objective: every LAN device's DNS is intercepted by the router and forwarded to
AdGuard on samsung (172.16.0.12); if samsung is down the router's dnsmasq keeps
resolving through its WAN upstream so the LAN never loses connectivity. No second
AdGuard on rog.

Branch: feat/adguard-dns-enforcement. Test runner: `dig` battery from a LAN client,
AdGuard stats check, live failover drill (`systemctl stop adguardhome` on samsung).

## Specs

- S1 (user verbatim: "lo que yo quiero es forzar a que todos los dispositivos pasen por los filtros sin perder objetividad no s cmo buscar la solucin por mi"): every LAN device's DNS goes through AdGuard filtering even when the device hardcodes its own DNS server. The router redirects all LAN traffic to port 53 into its own dnsmasq (source IP preserved so AdGuard per-client rules keep working), and dnsmasq forwards to samsung first.
- S2 (user verbatim: "claro yo creo que el router debera ser de fallback.i ningn otro dispositivo est disponible"): when samsung does not answer, the router's dnsmasq falls back to its WAN upstream so resolution survives; filtering is degraded until samsung returns.
- S3 (user verbatim: "rog no entra en la ecuacion"): no secondary DNS/AdGuard service is installed on rog.
- S4 (user verbatim: "Plan y ejecucin completa"): the router phase is executed by the agent over SSH (`root@router.lan` from a host with access), with `/etc/config/dhcp` and `/etc/config/firewall` backed up first.

## Design decisions (assumptions marked)

- Router dnsmasq gains `server=172.16.0.12` + `strictorder` so samsung is queried
  first and the WAN resolv.conf servers only on failure. Parallel querying (default)
  would let the faster public DNS win and bypass the filter.
- Router dnsmasq must never forward `/lan/` and `/172.16.in-addr.arpa/` upstream
  (`local=` options): samsung forwards those back to the router (`adguardhome.nix`
  upstream_dns lines 66-67, local_ptr_upstreams line 104), so forwarding them would
  create an infinite loop between the two resolvers.
- nftables chain with `hook prerouting priority dstnat - 1` in table inet fw4,
  redirecting br-lan udp/tcp dport 53 to local port 53, excluding
  `ip saddr 172.16.0.12` (samsung's own upstream queries must not be intercepted or
  they loop back into the router).
- samsung has no IPv6 global address (verified on the host), so its upstream queries
  are IPv4 only; the redirect covers IPv4 and IPv6 client traffic.
- `redirect` (not DNAT/masquerade) keeps the client source IP visible to AdGuard so
  the `$client` rules (android-tv, roku, lg-tv) keep matching.
- DHCP option 6 becomes `6,172.16.0.12` only; the public DNS entries were the bypass
  and are redundant once interception exists.
- DoH over 443 cannot be blocked by port rules; partial mitigation only via AdGuard
  DoH lists. DoT 853 block is out of scope for this change (minimal footprint).
- Fallback path loses DNSSEC validation (router dnsmasq does not validate); acceptable
  while samsung is down.
- Rollback restores the original `dhcp.lan.dhcp_option`
  (`6,172.16.0.12,172.16.0.1,9.9.9.9`), removes the server/strictorder/local entries
  and deletes the nft include, restarting dnsmasq and firewall.

## Tasks

- T1 S4 route: inline — inspect router (OpenWrt/fw4 version, interface name, current dhcp/firewall state, dnsmasq listening addresses). Status: pending, blocked on SSH access from samsung (no authorized key; rog unreachable from samsung).
- T2 S1,S2 route: inline — apply dnsmasq server/strictorder/local entries + restart. Status: pending.
- T3 S1 route: inline — install nft include `/etc/nftables.d/force-lan-dns.nft` + reload firewall. Status: pending.
- T4 S1 route: inline — set `dhcp.lan.dhcp_option='6,172.16.0.12'` + commit + restart dnsmasq. Status: pending.
- T5 S1,S2 route: inline — dig battery from a LAN client (filtered answer through a hardcoded public DNS, .lan resolution, AdGuard stats show real client IPs) + failover drill (stop adguardhome on samsung, verify resolution survives, restart). Status: pending.
- T6 S4 route: inline — document in docs/lan-dns-enforcement.md and link from docs/samsung-adguard-dns.md, including exact commands, verification and rollback. Status: pending.

## Log

- L1. (2026-11-16) User asks how to force all home devices through the filters without losing operativity if samsung (the AdGuard host) goes down: "cmo se puede imponer sin perder operatividad. en caso de que samsung s que eres sin internet" / "lo que yo quiero es forzar a que todos los dispositivos pasen por los filtros sin perder objetividad no s cmo buscar la solucin por mi".
- L2. (2026-11-16) Design question asked (secondary resolver role). User: "claro yo creo que el router debera ser de fallback.i ningn otro dispositivo est disponible" — router is the fallback, and "rog no entra en la ecuacion" removes rog from the design. Chain: samsung -> router dnsmasq -> WAN upstream.
- L3. (2026-11-16) User chose "Plan y ejecucin completa": agent prepares the plan and executes the router phase over SSH, including config backups.
- L4. (2026-11-16) Blocker found: this session runs on samsung; none of its SSH keys is accepted by the router (`root@172.16.0.1: Permission denied (publickey,password)`) and rog is unreachable from samsung, so T1-T4 need either router key authorization for samsung or manual execution from a host with access. Waiting on user.
