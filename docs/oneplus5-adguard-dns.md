# OnePlus 5 as LAN DNS (AdGuard Home) — Runbook

The OnePlus 5 (`172.16.0.12`, postmarketOS edge, systemd) runs AdGuard Home as a
LAN-only DNS server for manually enrolled TVs. Baseline is **log-only**: every
query is logged with the client IP, nothing is blocked. Hagezi vendor blocklists
are an explicit operator opt-in (see [Hagezi opt-in](#hagezi-opt-in)).

Repository source of truth:

| File | Deployed to |
|------|-------------|
| `docs/oneplus5-adguard-dns/AdGuardHome.yaml` | `/etc/adguardhome/AdGuardHome.yaml` |
| `docs/oneplus5-adguard-dns/adguardhome.service` | `/etc/systemd/system/adguardhome.service` |
| `docs/oneplus5-adguard-dns.md` (this runbook) | — |

## Prerequisites

- SSH from `rog` (or any trusted LAN host): `ssh -i ~/.ssh/oneplus5 glats@172.16.0.12` (passwordless sudo).
- The phone is Wi-Fi-only on `172.16.0.0/24` (SSIDs `JICS` / `JICS-5G`, NM profiles pin MAC `EE:03:CD:B0:51:74`).
- AdGuard Home is served by the Alpine `adguardhome` package (edge repo, ≥ 0.107.79, schema 34). Alpine ships only an OpenRC init script — the systemd unit comes from this repo.
- Trust model: the web UI (`172.16.0.12:3000`, plain HTTP) runs on a phone that
  is reachable by the trusted LAN. There is **no TLS** — plain HTTP only, so
  keep it LAN-local and **never port-forward 3000 through Tailscale or the
  router**. NOTE: the phone does run a curated nftables firewall
  (`/etc/nftables.nft`, drop-all input with per-service allowlist); its
  current policy allows SSH and DNS on wlan* but **not port 3000**, so the UI
  is only reachable from the phone itself until the operator adds an allow
  rule (see the UI-firewall troubleshooting entry below).

## Address gate (one-time)

The DNS service binds `172.16.0.12` specifically, so the address must not drift.

1. Operator creates a DHCP reservation in the Xiaomi MiWiFi web UI (`miwifi.com`
   → router settings → LAN/DHCP → static/DHCP reservation) mapping the phone
   MAC `EE:03:CD:B0:51:74` to `172.16.0.12`. (Done once; the reservation is
   treated as stable operator state.)
2. Validate from the phone:
   ```sh
   ssh -i ~/.ssh/oneplus5 glats@172.16.0.12 'ip -4 addr show wlan0; nmcli -f DHCP4 con show JICS | grep -E "expiry|ip_address"'
   ```
   PASS if `wlan0` holds `172.16.0.12/24` and the lease lists `ip_address = 172.16.0.12`.
   The NM profile also pins the MAC (`cloned-mac-address=EE:03:CD:B0:51:74` in
   `/etc/NetworkManager/system-connections/JICS*.nmconnection`), so the lease
   identifier is stable across reconnects.
3. If the reservation cannot be captured in the router UI, the only alternative
   is proving `.12` sits outside the router DHCP pool (not observable without
   router access) — do **not** switch the NM profile to manual/static without that proof.

## Install (one-time)

```sh
ssh -i ~/.ssh/oneplus5 glats@172.16.0.12
sudo apk add adguardhome          # pulls adguardhome + adguardhome-openrc (OpenRC script is inert on pmOS; ignore it)
id adguardhome                    # dedicated user/group must exist
command -v adguardhome            # => /usr/bin/adguardhome
```

## Deploy / start

Copy artifacts to `/tmp` from `rog`, then install them on the phone with the
ownership/modes AdGuard Home and systemd expect:

```sh
scp -i ~/.ssh/oneplus5 docs/oneplus5-adguard-dns/{AdGuardHome.yaml,adguardhome.service} glats@172.16.0.12:/tmp/
```

Still on the phone:

```sh
sudo install -d -o adguardhome -g adguardhome /etc/adguardhome /var/lib/adguardhome
sudo install -o adguardhome -g adguardhome -m 0640 /tmp/AdGuardHome.yaml /etc/adguardhome/AdGuardHome.yaml
sudo install -o root -g root -m 0644 /tmp/adguardhome.service /etc/systemd/system/adguardhome.service
systemd-analyze verify /etc/systemd/system/adguardhome.service
sudo systemctl daemon-reload
sudo systemctl enable --now adguardhome.service
```

> If the service fails to start with the YAML unreadable by the `adguardhome`
> user, fall back to `sudo install -o root -g root -m 0644 /tmp/AdGuardHome.yaml
> /etc/adguardhome/AdGuardHome.yaml` (AdGuard Home only reads the deployed
> config as the service user; world-readable is safe — it contains no secrets).

### Verify

```sh
systemctl is-active adguardhome                       # => active
systemctl is-enabled adguardhome                      # => enabled
ss -tulpn | grep -E ':53|:3000'                       # bound to 172.16.0.12 only, never 0.0.0.0
dig @172.16.0.12 example.com                          # ANSWER via upstream 9.9.9.10
```

From another LAN host:

```sh
dig @172.16.0.12 oneplus5-test.localdomain     # LAN socket reachability (answered = OK)
```

The web UI check from a PC works only after the operator opens it in the
phone firewall (see below); meanwhile verify it from the phone itself:

```sh
ssh -i ~/.ssh/oneplus5 glats@172.16.0.12 'curl -s --max-time 5 -o /dev/null -w "%{http_code}\n" http://172.16.0.12:3000/'   # => 200
```

Notes:

- `systemctl is-system-running` reports `degraded` on this phone because of two
  pre-existing benign failures (`postmarketos-zram-swap`, `sleep-inhibitor`).
  That is expected — check `adguardhome` specifically, not the overall state.
- Baseline has **no admin user**: with an empty `users` list AdGuard Home keeps
  its web UI/API open on the configured LAN bind. To add one, set it in the
  web UI (Settings → User management) — first user makes the UI password-
  protected. Recorded password policy: `adguard` (placeholder; change at will).
- Reboot-test once after first deploy: `sudo systemctl reboot`, wait for SSH to
  return (≤ 3 min), then re-run the verify block above. The service must come
  back active with the phone still holding `172.16.0.12`.

### Operator UI access via SSH tunnel (`adguard-tunnel`)

The phone firewall intentionally blocks `:3000` from the LAN, so UI access
from a PC goes through SSH itself, authenticated with the dedicated key
(`~/.ssh/oneplus5`). The `adguard-tunnel` Go helper (in
`pkgs/nixos-scripts/cmd/adguard-tunnel/`, repo `pkgs/nixos-scripts`)
automates this: it opens the local port-forward, prints the resolved local
UI URL, and tears the forward down cleanly on Ctrl+C.

```sh
adguard-tunnel                      # => tunnel up: http://127.0.0.1:3000/ -> 172.16.0.12:3000
adguard-tunnel -open                # same, also xdg-open the URL
```

Defaults are `-host 172.16.0.12 -port 3000 -local 3000 -user glats
-key ~/.ssh/oneplus5`; run `adguard-tunnel -h` for the full list. If the
preferred local port is busy the helper falls back to `+10000` (3000 →
13000) automatically and prints the note; if both are busy it refuses with
a clear error. SSH key auth is the access control for the admin UI — the
helper works only where `~/.ssh/oneplus5` resolves to the authorized key.

Run it as `adguard-tunnel` — it ships in `pkgs/nixos-scripts` and is on
PATH (per-user home-manager profile, `/etc/profiles/per-user/<user>/bin/`)
after a host switch (`nixos-build`).

**Phone-side prerequisite (one-time):** the phone's sshd ships with
`AllowTcpForwarding no` (deliberate hardening in `/etc/ssh/sshd_config`),
which makes every forward fail with `channel open failed:
administratively prohibited`. A scoped drop-in fixes exactly this case
without loosening the rest:

```sh
# /etc/ssh/sshd_config.d/100-adguard-tunnel.conf (on the phone)
AllowTcpForwarding local
PermitOpen 172.16.0.12:3000
```

Then `sudo sshd -t && sudo systemctl restart sshd` (`sshd -t` first — a
broken config would lock new SSH sessions out). `local` forbids `-R`/`-D`
and `PermitOpen` restricts forward targets to the AdGuard UI only. Add
further targets by appending to `PermitOpen`.


## Enroll TVs (operator, on each TV)

Set the TV's network settings to manual/static DNS with primary
`172.16.0.12`. Leave the secondary field blank, or use the router
`172.16.0.1` if the TV UI forces a second entry.

- **Samsung (Tizen):** Settings → Network → Network Status → IP Settings → DNS setting: “Enter manually” → `172.16.0.12`.
- **LG (webOS):** Settings → Network → Wi-Fi/connection → Advanced settings → “Edit manually” → DNS server: `172.16.0.12`.
- **Android/Google TV:** Settings → Network & Internet → select network → Advanced → IP settings: Static → DNS 1: `172.16.0.12`.
- **Roku / Amazon Fire TV / Apple TV:** use the same manual-DNS flow in their network settings; some stop at the platform's DNS fields, some are hardcoded (see troubleshooting).

Repeat per TV, then continue with a normal streaming session to generate queries.

### Hardcoded-DNS blind spot (8.8.8.8)

A TV whose DNS is hardcoded `8.8.8.8` (or another external resolver) resolves
normally but never appears in the AdGuard Home query log — the rule of thumb is
**a TV that works but is a silent “client” in the UI either wasn't enrolled or
hardcodes its resolver**. Diagnosis: find the TV IP in the router's lease list,
then from the phone watch ARP while the TV streams:

```sh
sudo tcpdump -ni wlan0 'host <TV-IP> and not port 53 and not port 67-68'   # ARP/IP chatter
dig +short ch txt whoami.google @8.8.8.8   # sanity check that 8.8.8.8 itself is reachable
```

A TV visible on the LAN but absent from the query log while streaming is on a
hardcoded resolver. Retry its manual DNS control; if the platform refuses,
accept the blind spot — redirecting/blocking `8.8.8.8` needs router policy and
is out of scope for this runbook.

## Name clients and read logs

- **Query log:** web UI → Dashboard/Query log. Every query shows client IP +
  resolved name (ARP/rDNS runtime sources are enabled in the baseline).
- **Per-client names:** Settings → Client settings → Add client → identifier =
  TV IP or MAC, name = `samsung-tv` / `lg-tv` / … . The baseline YAML ships
  **no** persistent clients (`clients.persistent: []`): AdGuard Home
  fatal-errors at startup on any persistent client with an empty `ids` list,
  so names can only be created through the UI once a TV's stable address is
  known. Entries created here are user data on the phone, never repo state; a
  redeploy wipes them and they must be re-added through the UI.
- **Per-client filtering is available later** (client settings keep global
  defaults in the log-only state).

## Hagezi opt-in

Nothing is blocked until an operator does this. Per-vendor lists exist for
Samsung, LG webOS, Roku, Amazon Fire TV, and Apple TV. **Do not mix onto the
wrong vendor's TV** (e.g. don't put the Roku list on an LG).

1. Verify a TV is enrolled and appearing in the query log by name.
2. Web UI → **Filters → DNS blocklists → Add blocklist → Add a custom list**
   → name it after the vendor, paste the raw URL, **Add and enable**.
3. Enable global filtering when ready to cut noise: Settings → General →
   “Block domains” toggle ON. All enrolled clients switch to filtering at once;
   per-client settings can limit later additions, but the UI toggle flips the
   baseline for everyone.
4. Test: stream on the affected TV for a few minutes; the query log should show
   blocked telemetry requests (0.0.0.0 answers). Watch for broken app
   functionality — if a service breaks, disable that list in the blocklists
   panel or its specific allowlists in Hagezi's docs.

Verified raw URLs (5, one per vendor, `hagezi/dns-blocklists` `main` branch):

| Vendor | URL |
|--------|-----|
| Samsung Tizen | `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.samsung.txt` |
| LG webOS | `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.lgwebos.txt` |
| Roku | `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.roku.txt` |
| Amazon Fire TV | `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.amazon.txt` |
| Apple TV | `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.apple.txt` |

At the end of apply **no list is active** — the blocklists panel is empty until
the operator performs the opt-in above.

## Redeploy / drift correction

AdGuard Home rewrites `/etc/adguardhome/AdGuardHome.yaml` on UI edits and down-
loads lists, so the live file drifts. Re-deploying the repository baseline
wipes all drift — including **UI-added client names and enabled lists**. Only
run this when the drift is unliked; re-add named clients through the UI
afterwards (they're one-click each).

```sh
scp -i ~/.ssh/oneplus5 docs/oneplus5-adguard-dns/{AdGuardHome.yaml,adguardhome.service} glats@172.16.0.12:/tmp/
ssh -i ~/.ssh/oneplus5 glats@172.16.0.12 '
sudo install -d -o adguardhome -g adguardhome /etc/adguardhome /var/lib/adguardhome
sudo systemctl stop adguardhome
sudo install -o adguardhome -g adguardhome -m 0640 /tmp/AdGuardHome.yaml /etc/adguardhome/AdGuardHome.yaml
sudo install -o root -g root -m 0644 /tmp/adguardhome.service /etc/systemd/system/adguardhome.service
sudo systemctl daemon-reload && sudo systemctl enable --now adguardhome
'
```

Then verify: `systemctl is-active adguardhome`, `ss -tulpn | grep -E ':53|:3000'`,
`dig @172.16.0.12 example.com`, a named-TV query, and zero enabled filters;
reboot-test once after any unit change. To diff live vs. baseline:

```sh
diff <(ssh -i ~/.ssh/oneplus5 glats@172.16.0.12 'sudo cat /etc/adguardhome/AdGuardHome.yaml') \
     docs/oneplus5-adguard-dns/AdGuardHome.yaml
diff <(ssh -i ~/.ssh/oneplus5 glats@172.16.0.12 'sudo cat /etc/systemd/system/adguardhome.service') \
     docs/oneplus5-adguard-dns/adguardhome.service
```

## Rollback (TV-first)

1. Restore each TV's network settings to automatic DNS (or the router
   `172.16.0.1`). TV must load streaming apps normally again before touching
   the phone.
2. Remove the service, unit, config, state, and package:
   ```sh
   ssh -i ~/.ssh/oneplus5 glats@172.16.0.12 '
   sudo systemctl disable --now adguardhome.service
   sudo rm /etc/systemd/system/adguardhome.service
   sudo systemctl daemon-reload
   sudo rm -rf /etc/adguardhome /var/lib/adguardhome
   sudo apk del adguardhome adguardhome-openrc
   '
   ```
3. Confirm a TV still resolves through the router after its DNS was restored —
   from the router lease list or the TV's network status screen.

## Troubleshooting

- **`systemctl is-system-running` = degraded** — pre-existing, unrelated: the
  two failed units are `postmarketos-zram-swap` (`Invalid argument` from the
  6.0-kernel zram algorithm; 7.5 GB RAM, so swap loss is cosmetic) and
  `sleep-inhibitor` (`System does not support any sleep states, quitting` —
  `/sys/power/state` is empty, the phone's kernel exposes no suspend states, so
  idle-suspend killing DNS is not a risk). Ignore both.
- **DNS stopped responding / Wi-Fi flaky** — check `journalctl -u NetworkManager
  -n 50` and `ath10k-crash-watch`. The `ath10k` firmware occasionally crashes
  and the phone may rejoin the AP; this is the main 24/7 reliability risk.
- **Wi-Fi power management** — NM profiles set `wifi.powersave=2` (disable
  power save) to keep latency stable; verify with
  `nmcli -f 802-11-wireless.powersave con show JICS` if latency spikes appear.
- **Phone unreachable at all** — serial/adb line is out of scope; treat power
  loss on the phone as the DNS single point of failure for enrolled TVs and
  use the rollback section's TV restore first.
- **TV works but is silent in logs** — hardcoded resolver (see
  [hardcoded-DNS blind spot](#hardcoded-dns-blind-spot-888)).
- **Web UI not reachable from a PC on `:3000`** — the phone's curated
  nftables firewall (`/etc/nftables.nft`, input `policy drop`) allowlists
  SSH/DNS/DHCP but not the admin UI, by design. To manage from a PC use the
  SSH loopback helper: `adguard-tunnel` (see
  [Operator UI access](#operator-ui-access-via-ssh-tunnel-adguard-tunnel)) —
  SSH key auth is the access control; no firewall change is needed. Do NOT
  bypass the firewall with router or Tailscale port-forwarding, and never
  open it by a firewall rule without an explicit operator decision (drop-in
  under `/etc/nftables.d/`, e.g. a `tcp dport 3000` accept rule for `wlan*`,
  then reload nftables). Also confirm the bind in
  `/etc/adguardhome/AdGuardHome.yaml` under `http.address` is
  `172.16.0.12:3000` (never `0.0.0.0:3000`).
- **`dig` from the phone fails but the UI works** — upstream outage: the
  baseline's fallback (`1.1.1.1`) should absorb Quad9 (`9.9.9.10`) failures;
  check `journalctl -u adguardhome -n 50` for upstream errors. On the phone
  itself use `nslookup example.com 172.16.0.12` (no `dig` installed).
- **apk shows an extra `adguardhome-openrc` subpackage** — harmless on pmOS
  (systemd host); the OpenRC script is inert. Do not `rc-update` anything.
