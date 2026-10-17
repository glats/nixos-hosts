# Xiaomi AX3200 → OpenWrt config map

Purpose: keep the user's current home-network configuration transparent across the OpenWrt migration. Extracted read-only via the MiWiFi API on 2026-10-17 (S4/T6). Secrets are NOT stored in this repo file: they live only locally at `/tmp/opencode/modem-xiaomi-ax3200/` (raw export + `secrets.env`, chmod 600). Both passwords were verified byte-exact against the live router on 2026-10-17: WAN PPPoE password and the WiFi key (same on both radios). If lost, re-extract via the stok API or via SSH in Phase 1 and regenerate `secrets.env`.

## Data inventory

| Area | Xiaomi state | OpenWrt target |
|---|---|---|
| WAN | PPPoE, user `0001094205399@tchile`, pwd in raw export, MTU/MRU 1480, peerdns 0 | `wan` interface, proto pppoe |
| WAN DNS | manual: 172.16.0.12, 9.9.9.9 (IPv6 off) | `wan` dns list, peerdns off |
| LAN | 172.16.0.1/24 (non-default subnet — keep!) | `lan` interface ipaddr 172.16.0.1 |
| WiFi 2.4 | SSID `JICS`, psk2, auto channel (currently 11), txpwr max, ax | wifi-iface radio0 |
| WiFi 5 | SSID `JICS-5G`, psk2, auto channel (currently 48), txpwr max, ax | wifi-iface radio1 |
| Port forwards | udp 51820, tcp 80, tcp 443 → 172.16.0.5 (rog) | firewall redirects ×3 |
| DHCP leases/static | captured in Phase 1: 6 reservations (.5/.6/.9/.10/.11/.12), pool start 5 limit 250 lease 720m, dns push 172.16.0.12 + 172.16.0.1 → MIGRATED (adguard feature): dns push nowrouter-only `6,172.16.0.1` (AGH on :53 at .1); the `.12` static lease stays for the OnePlus device itself but its DNS role ended | `dhcp` host entries + pool params |
| Router admin creds | required for Phase 1 (user-provided at execution time) | never stored in repo |

## Draft UCI (apply post-flash)

```sh
# network — WAN
uci set network.wan.proto='pppoe'
uci set network.wan.username='0001094205399@tchile'
uci set network.wan.password='__FROM_RAW_EXPORT__'
uci set network.wan.mtu='1480'
uci set network.wan.peerdns='0'
uci add_list network.wan.dns='172.16.0.12'
uci add_list network.wan.dns='9.9.9.9'

# network — LAN (same subnet = transparent for every device)
uci set network.lan.ipaddr='172.16.0.1'
uci set network.lan.netmask='255.255.255.0'

# firewall — port redirects (APPLIED+VERIFIED 2026-10-17; src is MANDATORY in fw4)
for spec in 'udp 51820 wireguard' 'tcp 80 http' 'tcp 443 https'; do
  set -- $spec
  uci add firewall redirect >/dev/null
  uci set firewall.@redirect[-1].name="$3"
  uci set firewall.@redirect[-1].proto="$1"
  uci set firewall.@redirect[-1].src='wan'
  uci set firewall.@redirect[-1].src_dport="$2"
  uci set firewall.@redirect[-1].dest_ip='172.16.0.5'
  uci set firewall.@redirect[-1].target='DNAT'
done
# NOTE: `uci commit` is NOT enough for firewall changes — always run afterwards:
#   /etc/init.d/firewall reload   (a `network restart` does NOT refresh fw4 rules)

# wireless — radios mt7622 (2.4) + mt7915 (5)
uci set wireless.default_radio0.ssid='JICS'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='__FROM_RAW_EXPORT__'
uci set wireless.default_radio0.channel='auto'
uci set wireless.default_radio1.ssid='JICS-5G'
uci set wireless.default_radio1.encryption='psk2'
uci set wireless.default_radio1.key='__FROM_RAW_EXPORT__'
uci set wireless.default_radio1.channel='auto'

# dhcp — pool + static leases (exact values from stock /etc/config/dhcp, Phase 1 capture 2026-10-17;
# UPDATED by adguard-openwrt migration: no dns option rewrite — dnsmasq pushes itself 172.16.0.1 which now hosts AdGuard Home on :53)
uci set dhcp.lan.start='5'
uci set dhcp.lan.limit='250'
uci set dhcp.lan.leasetime='720m'
uci add_list dhcp.lan.dhcp_option='6,172.16.0.1'
# static leases; names rog/.12 are confirmed, others keep MAC-derived placeholders until renamed
for spec in \
  'rog    88:d7:f6:22:10:fe 172.16.0.5' \
  'dev6   f8:e4:3b:53:64:cc 172.16.0.6' \
  'dev9   5a:d7:9c:c6:98:4b 172.16.0.9' \
  'dev10  54:05:db:a1:3f:01 172.16.0.10' \
  'dev11  6c:4b:90:2d:97:42 172.16.0.11' \
  'dns12  ee:03:cd:b0:51:74 172.16.0.12'; do
  set -- $spec
  uci add dhcp host >/dev/null
  uci set dhcp.@host[-1].name="$1"
  uci set dhcp.@host[-1].mac="$2"
  uci set dhcp.@host[-1].ip="$3"
done

uci commit network; uci commit wireless; uci commit firewall; uci commit dhcp
```

## Restore procedure (flash day, Phase 2)

1. After first OpenWrt boot, SSH in → apply this map via the raw exports (real passwords).
2. Merge DHCP static leases captured in Phase 1 (`/etc/config/dhcp` of stock) into UCI.
3. Verify: WAN up (same public IP 201.188.x from Telefonica), LAN unchanged, devices reassociate seamlessly, port redirects reachable from WAN, wireguard handshake on rog still working.

## Raw artifacts (Phase 1 complete, 2026-10-17 — all outside the repo, contain secrets)

- Durable staging root: `/home/glats/modem-backup-ax3200/` (mirrors `/tmp/opencode/modem-xiaomi-ax3200/`).
- Full mtd partition backup: `~/modem-backup-ax3200/xmir-patcher/backups/` — 15 parts mtd0–mtd14 (PLHeader, Preloader, ATF, uboot, Nvram, Bdata, Factory, crash×2, firmware, firmware1, kernel, rootfs, overlay, obr). ~165 MB. This is the total fallback for a stock restore.
- Stock config tarball: `~/modem-backup-ax3200/stock-config.tgz` (15116 B) + extracted `/etc/config` tree in `stock-config-extracted/`.
- Root SSH (stock firmware): password at `~/modem-backup-ax3200/.root_ssh.pw` chmod 600 (set by xmir-patcher passw.py; permanent dropbear + bdata patched: `ssh_en=1`, `uart_en=0→keep`, `boot_wait=on`).
- Xiaomi secrets (PPPoE + WiFi): `~/modem-backup-ax3200/secrets.env` chmod 600. Admin web password: `.admin.pw` chmod 600 (same folder). Never commit any of these.
