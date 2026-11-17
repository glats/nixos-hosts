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

- Two interception paths, verified against the live router (OpenWrt 25.12.6, fw4,
  dnsmasq 2.93):
  - DHCP clients (option 6 = `6,172.16.0.12,172.16.0.1,9.9.9.9`) query AdGuard on
    samsung directly; the rule must NOT intercept queries addressed to
    `172.16.0.12`, so AdGuard keeps seeing real client IPs and the `$client` rules
    (android-tv, roku, lg-tv) keep matching.
  - Queries to any other port-53 destination (hardcoded 8.8.8.8 etc.) are
    redirected (`redirect to :53`, source IP preserved) into the router's own
    dnsmasq, which forwards them to samsung first (`server=172.16.0.12` +
    `strictorder`); they still get filtered but AdGuard sees them as the router
    (global rules only). This is the accepted identity trade-off.
- Fallback chain without any watchdog: samsung dies -> DHCP clients move to
  `.1`/`9.9.9.9` -> those are also intercepted into router dnsmasq -> dnsmasq
  strict-order fails over to its WAN resolv.conf upstreams. Resolution never dies;
  filtering degrades to WAN DNS until samsung returns. Keeping the public DNS
  entries in DHCP option 6 is deliberate: interception makes them non-bypass.
- Router dnsmasq must never forward `/lan/` upstream: it already has
  `local='/lan/'`, `domain='lan'` and `boguspriv='1'` (verified live), which also
  prevents the loop with samsung's `[/lan/]router:53` and PTR upstreams
  (`adguardhome.nix` lines 66-67, 104).
- nftables chain with `hook prerouting priority dstnat - 1` in table inet fw4
  (auto-included from `/etc/nftables.d/`, verified live): br-lan udp/tcp dport 53,
  excluding `ip saddr 172.16.0.12` (samsung's own upstream queries must not loop)
  and `ip daddr 172.16.0.12` (client-to-AdGuard traffic stays direct). IPv6 rules
  exclude the router's own ULA `fd60:69e:6fd2::1`; dnsmasq is verified listening
  on `fd60:69e:6fd2::1:53`.
- Router firewall config (`/etc/config/firewall`), `/etc/config/dhcp` and the
  dropbear `authorized_keys` are backed up before changes; rollback restores them.
- DoH over 443 cannot be blocked by port rules; partial mitigation only via AdGuard
  DoH lists. DoT 853 block is out of scope for this change (minimal footprint).
- Fallback path loses DNSSEC validation (router dnsmasq does not validate); acceptable
  while samsung is down.
- Rollback restores the original `dhcp.lan.dhcp_option`
  (`6,172.16.0.12,172.16.0.1,9.9.9.9`), removes the server/strictorder/local entries
  and deletes the nft include, restarting dnsmasq and firewall.

## Tasks

- T1 S4 route: inline — inspect router (OpenWrt 25.12.6/fw4, dnsmasq 2.93, br-lan, dhcp/firewall state, dnsmasq listeners). Status: done (2026-11-16, via rog jump; evidence in Log L5).
- T2 S1,S2 route: inline — apply dnsmasq `server=172.16.0.12` + `strictorder` (WAN resolv stays as last resort) + restart. Status: done (2026-11-16; DNSMASQ-OK observed).
- T3 S1 route: inline — install nft include `/etc/nftables.d/20-force-lan-dns.nft` + `fw4 reload`. Status: done (2026-11-16; chain verified live via `nft list chain`).
- T4 S2 route: inline — verify `dhcp.lan.dhcp_option` stays `6,172.16.0.12,172.16.0.1,9.9.9.9` (fallback kept deliberately; interception makes it bypass-proof). No change. Status: done (verified unchanged).
- T5 S1,S2 route: inline — dig battery from rog (default path filtered, hardcoded @8.8.8.8 filtered through interception, @9.9.9.9 resolves, .lan resolves, v6 probe) + failover drill (temporary output-drop of router->samsung:53, verify dnsmasq WAN fallback, remove) + AdGuard stats show real client IPs. Status: done (evidence in Log L7; failover drill passed and drill rule removed).
- T6 S4 route: inline — document in docs/lan-dns-enforcement.md, update docs/samsung-adguard-dns.md design note, and add router enrollment note to docs/oneplus5-lan-ssh-mesh.md so the mesh covers all hosts. Status: done.
- T7 S4 route: inline — authorize samsung's missing mesh key in the router dropbear authorized_keys (mesh gap found: router record verified 2026-10-17 predates samsung enrollment 2026-11-06). Status: done (key appended; direct samsung->router SSH verified with BatchMode).

## Log

- L1. (2026-11-16) User asks how to force all home devices through the filters without losing operativity if samsung (the AdGuard host) goes down: "cmo se puede imponer sin perder operatividad. en caso de que samsung s que eres sin internet" / "lo que yo quiero es forzar a que todos los dispositivos pasen por los filtros sin perder objetividad no s cmo buscar la solucin por mi".
- L2. (2026-11-16) Design question asked (secondary resolver role). User: "claro yo creo que el router debera ser de fallback.i ningn otro dispositivo est disponible" — router is the fallback, and "rog no entra en la ecuacion" removes rog from the design. Chain: samsung -> router dnsmasq -> WAN upstream.
- L3. (2026-11-16) User chose "Plan y ejecucin completa": agent prepares the plan and executes the router phase over SSH, including config backups.
- L4. (2026-11-16) Blocker found: this session runs on samsung; none of its SSH keys is accepted by the router (`root@172.16.0.1: Permission denied (publickey,password)`) and rog is unreachable from samsung, so T1-T4 need either router key authorization for samsung or manual execution from a host with access. Waiting on user.
- L5. (2026-11-16) Router inspection via rog jump (rog came back up): OpenWrt 25.12.6, dnsmasq 2.93, br-lan, fw4 auto-includes `/etc/nftables.d` (`10-custom-filter-chains.nft` is the untouched default template). dnsmasq listens on 172.16.0.1:53, WAN IP:53, 127.0.0.1:53 and IPv6 link-locals + `fd60:69e:6fd2::1:53`. Existing `dhcp.lan.dhcp_option='6,172.16.0.12,172.16.0.1,9.9.9.9'`, `local='/lan/'`, `boguspriv='1'`, no `server`/`strictorder` entries. Dropbear authorized_keys has macm5/oneplus5/rog/t14/thinkcentre but NOT samsung (mesh gap). AdGuard on samsung answers (dig @172.16.0.12 from rog). Design revised after inspection: full-redirect into router dnsmasq would destroy per-client identity (dnsmasq re-emits from 172.16.0.1), so interception excludes `ip daddr 172.16.0.12` and DHCP option 6 stays unchanged with the fallback entries; T4 reduced to verification; T7 added for the missing samsung key.
- L6. (2026-11-16) User direction: "la idea es que el mesh quede para todos los hosts y no tener este problema" — the router must accept every mesh member key, documented as a standing rule in the mesh runbook (T6), not a one-off fix.
- L7. (2026-11-16) Execution evidence: router backups created (`/root/{dhcp,firewall}-before-dns-enforce-20261117`, `/root/dropbear-authorized_keys-before-20261117`; router clock dates the backups 20261117); samsung key appended; dnsmasq `server=172.16.0.12` + `strictorder=1` committed and restarted; `/etc/nftables.d/20-force-lan-dns.nft` installed and `fw4 reload` clean. Battery from rog: default path via samsung; `@8.8.8.8 googleads.g.doubleclick.net` -> `0.0.0.0` (intercepted and filtered); `@9.9.9.9 example.com` -> answered through interception; `t14.lan` and PTR intact; IPv6 probe: LAN has no global v6 (ULA only), bypass structurally impossible today. Failover drill (drop router output to .12:53): `@8.8.8.8 pexels.com` answered via WAN fallback and a fresh random name returned NOERROR — dnsmasq strict-order fallback proven; drill chain removed, force_lan_dns chain intact. AdGuard stats show per-device client IPs (.5 rog, .7 android-tv-2). Direct samsung->router SSH works. Note: first script application attempt via double-hop stdin partially applied (backups + key only); remaining pieces applied with explicit commands. Feature verified against S1-S4.
