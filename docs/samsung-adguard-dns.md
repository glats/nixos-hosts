# AdGuard Home on samsung (declarative)

`samsung` serves LAN DNS filtering at `172.16.0.12:53`. It replaces the OnePlus 5
instance (`docs/oneplus5-adguard-dns.md`, historical). The configuration is declared in
`linux/system/services/network/adguardhome.nix`; the per-device rules live in
`linux/system/services/network/adguardhome-rules.txt`. Only `hosts/samsung` imports it.

## Design

- NixOS `services.adguardhome` in immutable mode (`mutableSettings = false`): the
  config is copied from the Nix store on every start, so edits made in the web UI do
  not persist. Change the Nix files instead.
- DNS binds `172.16.0.12:53`. The router DHCP keeps advertising
  `6,172.16.0.12,172.16.0.1,9.9.9.9`, so clients fall back to the router and Quad9 when
  samsung is down. The fallback can also let some clients skip the filter; this is the
  accepted trade-off for never losing resolution.
- The web panel binds `127.0.0.1:3000` only, with no login (a declarative password
  hash would be world-readable in `/nix/store`). Reach it through a tunnel:
  From rog, run `adguard-tunnel -open`, which uses `samsung.lan` and the normal SSH
  configuration. Keep the terminal open; press Ctrl+C to close the tunnel. Without
  `-open`, open the printed URL manually (normally `http://127.0.0.1:3000`; if port
  3000 is busy, the command uses 13000). Use `-key ~/.ssh/id_ed25519_lan` for an
  explicit identity, or `-host`, `-user`, `-port`, and `-local` to override defaults.
  The forward always targets remote loopback. Without the installed command, run
  `ssh -N -L 3000:127.0.0.1:3000 glats@samsung.lan` and open `http://127.0.0.1:3000`.
- Parity with the OnePlus config: schema 34, AdGuard 0.107.79, 90 rules, 4 persistent
  clients, HaGeZi Multi LIGHT and HaGeZi Threat Intelligence Feeds MINI, same upstreams,
  fallback, cache and DNSSEC settings. Rules are scoped by `$client=<name>`; the lists
  are global.
- Clients are keyed by IP. `lg-tv` carries both `172.16.0.22` (reservation) and
  `172.16.0.237` (old dynamic lease) until the old lease expires; remove `.237` later.
- samsung disables the suspend targets and Wi-Fi power save so the DNS host stays up.

| client | ids | rules |
|---|---|---|
| `android-tv` | `172.16.0.8` (Philips) | 13 (shared with `android-tv-2`) |
| `android-tv-2` | `172.16.0.7` (Sony) | |
| `roku` | `172.16.0.14` | 51 |
| `lg-tv` | `172.16.0.22`, `172.16.0.237` | 26 |

## Router reservations (manual, run only on explicit approval)

Reach the router with `ssh root@router.lan`. Locate the entry by name instead of
trusting the index, and back up first:

```sh
cp /etc/config/dhcp /root/dhcp-before-samsung-adguard-$(date +%Y%m%d)
uci show dhcp | grep -B2 -A3 "name='oneplus5'"          # note the @host[N] index
uci set dhcp.@host[N].name='samsung'
uci set dhcp.@host[N].mac='c8:f7:33:73:9a:24'
uci set dhcp.@host[N].ip='172.16.0.12'
uci add dhcp host
uci set dhcp.@host[-1].name='lg-tv'
uci set dhcp.@host[-1].mac='48:8d:36:65:51:7c'
uci set dhcp.@host[-1].ip='172.16.0.22'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

Do not touch `dhcp.lan.dhcp_option`, WiFi, WAN or the firewall. After the change
`oneplus5.lan` stops resolving and `samsung.lan` resolves to `172.16.0.12`.

## Cutover order

1. Merge the Nix change and run the router commands above.
2. Renew samsung's lease so it moves from `.201` to `.12` (reconnect Wi-Fi or reboot).
3. Rebuild samsung (`nixos-build switch`). If AdGuard starts before the address
   exists, it fails to bind and the unit retries every 10 seconds.
4. The first start downloads both HaGeZi lists; wait a minute before testing.

## Verification

```sh
dig +short @172.16.0.12 example.com
dig +short @172.16.0.12 t14.lan
dig +short -x 172.16.0.10 @172.16.0.12
dig +tcp +short @172.16.0.12 example.com
dig +short @172.16.0.12 googleads.g.doubleclick.net      # expect 0.0.0.0
ssh -L 3000:127.0.0.1:3000 glats@samsung.lan             # then, in another shell:
curl -s http://127.0.0.1:3000/control/status             # protection_enabled true
curl -s http://127.0.0.1:3000/control/filtering/status   # 2 filters, 90 user_rules
curl -s http://127.0.0.1:3000/control/stats              # clients actually using AdGuard
```

To find clients that bypass the filter, compare the client IPs in the stats with the
router leases; a leased client that never appears is using the fallback DNS (or DoH /
Android Private DNS).

## Rollback

Remove the `adguardhome.nix` import from `hosts/samsung/default.nix` and rebuild.
Clients keep resolving through the DHCP fallback (`172.16.0.1`, `9.9.9.9`) meanwhile.
Router reservations can be restored from the `/root/dhcp-before-samsung-adguard-*` copy.

## Notes

- The router instance died of OOM seconds after each list update (242 MB RAM). That is
  the probable cause but was never proven, since AdGuard's pprof was disabled. samsung
  has 3.8 GB of RAM. AdGuard's pprof stays disabled: the bot already uses port 6060.
- The only complete copy of the previous live configuration is the OnePlus backup on
  rog (`~/Backups/oneplus5-rescue-20261105.fqBK85`); the rules file in this repo is now
  a second copy.
