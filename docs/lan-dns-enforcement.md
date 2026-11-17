# LAN DNS enforcement (router interception + fallback)

All LAN devices are forced through AdGuard on samsung (`172.16.0.12`) without
losing resolution when samsung is down. Applied on the OpenWrt router
(`root@172.16.0.1`, OpenWrt 25.12.6, dnsmasq 2.93) on 2026-11-16.

## How it works

- DHCP option 6 stays `6,172.16.0.12,172.16.0.1,9.9.9.9` (unchanged on purpose).
- A nftables chain in table `inet fw4` (`/etc/nftables.d/20-force-lan-dns.nft`)
  redirects every br-lan query to UDP/TCP port 53 into the router's own dnsmasq,
  except queries sourced from samsung (its own upstreams must not loop) and
  queries addressed to samsung (clients with DHCP DNS reach AdGuard directly, so
  AdGuard keeps seeing real client IPs and the per-`$client` rules keep working).
- Router dnsmasq forwards intercepted queries to samsung first
  (`server=172.16.0.12`, `strictorder=1`); the WAN `resolv.conf.auto` servers
  remain the last resort. Queries addressed to the public DNS entries in option 6
  are also intercepted, so they are not a bypass anymore.
- If samsung dies: DHCP clients move to `.1`/`9.9.9.9` -> intercepted into router
  dnsmasq -> samsung times out -> dnsmasq falls back to its WAN upstream.
  Resolution survives; filtering degrades until samsung returns.
- `.lan` names are answered locally by the router (`local='/lan/'`, already
  present) and private PTR queries are blocked upstream (`boguspriv='1'`), which
  also prevents a resolver loop with samsung's `[/lan/]router:53` upstreams.

## Applied changes (router)

Backups on the router: `/root/dhcp-before-dns-enforce-20261117`,
`/root/firewall-before-dns-enforce-20261117`,
`/root/dropbear-authorized_keys-before-20261117`.

```sh
# dnsmasq: samsung first, strict order, WAN stays as last resort
uci add_list dhcp.@dnsmasq[0].server='172.16.0.12'
uci set dhcp.@dnsmasq[0].strictorder='1'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

`/etc/nftables.d/20-force-lan-dns.nft`:

```nft
chain force_lan_dns {
    type nat hook prerouting priority dstnat - 1; policy accept;
    iifname "br-lan" ip saddr != 172.16.0.12 ip daddr != 172.16.0.12 udp dport 53 redirect to :53
    iifname "br-lan" ip saddr != 172.16.0.12 ip daddr != 172.16.0.12 tcp dport 53 redirect to :53
    iifname "br-lan" ip6 daddr != fd60:69e:6fd2::1 udp dport 53 redirect to :53
    iifname "br-lan" ip6 daddr != fd60:69e:6fd2::1 tcp dport 53 redirect to :53
}
```

Then `fw4 reload`. The `dhcp.lan.dhcp_option` value was left untouched.

## Verification (observed 2026-11-16, from rog)

- `dig +short example.com` -> answered via samsung.
- `dig +short @8.8.8.8 googleads.g.doubleclick.net` -> `0.0.0.0` (intercepted AND
  filtered; only AdGuard produces this answer).
- `dig +short @9.9.9.9 example.com` -> answered through the interception path.
- `dig +short t14.lan` -> `172.16.0.10`; `dig +short -x 172.16.0.10 @172.16.0.12`
  -> `t14.lan.` (samsung->router PTR path intact).
- IPv6 probe from rog: `network unreachable` — the LAN has no global IPv6 (ULA
  only), so a public-IPv6 DNS bypass is structurally impossible today; the IPv6
  redirect rules stay as future-proofing.
- Failover drill: temporary `nft` chain dropping router OUTPUT to
  `172.16.0.12:53` (simulating samsung down for dnsmasq only), then
  `dig +short @8.8.8.8 pexels.com` -> answered through the WAN fallback; a fresh
  random name also returned a response (`NOERROR`). Rule removed afterwards.
- AdGuard `/control/stats` `top_clients` shows distinct per-device IPs
  (rog `.5`, android-tv-2 `.7`, etc.), so identity is preserved.
- samsung can now SSH to the router directly: samsung's mesh key was missing
  from the router dropbear `authorized_keys` (enrolled 2026-11-06, after the
  router's 2026-10-17 verification) and was appended; see
  `docs/oneplus5-lan-ssh-mesh.md`.

## Known gaps (accepted)

- DoH over port 443 cannot be blocked by port rules; partial mitigation only via
  AdGuard's DoH lists.
- DoT (853) is not blocked in this change.
- Docker containers NAT'ed out of samsung share samsung's source IP, so their
  port-53 queries are exempt together with samsung's own upstreams.
- Hardcoded-DNS clients that get intercepted reach AdGuard through router
  dnsmasq, so AdGuard sees them as `172.16.0.1` (global rules, no per-device
  rules). DHCP clients keep their identity.

## Rollback

```sh
cp /root/dhcp-before-dns-enforce-20261117 /etc/config/dhcp
cp /root/firewall-before-dns-enforce-20261117 /etc/config/firewall
rm /etc/nftables.d/20-force-lan-dns.nft
fw4 reload
/etc/init.d/dnsmasq restart
```

Keep samsung's key in `/etc/dropbear/authorized_keys` (restoring the
`dropbear-authorized_keys-before-20261117` backup would reintroduce the mesh
gap). The original `dhcp.lan.dhcp_option` value was
`6,172.16.0.12,172.16.0.1,9.9.9.9` and is unchanged.
