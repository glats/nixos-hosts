# Exploration: oneplus5-adguard-dns

## Current State

The goal is LAN-wide per-device DNS visibility into smart-TV telemetry, with optional blocking via Hagezi blocklists, by making the always-on OnePlus 5 (postmarketOS) the LAN DNS server. The Xiaomi MiWiFi router (stock firmware, PPPoE + DHCP, no shell) would hand the phone's IP to DHCP clients as their resolver.

**Network facts (verified read-only over SSH, 2026-09-09):**

- LAN is `172.16.0.0/24`, gateway `172.16.0.1` (Xiaomi). The phone's `wlan0` (connection `JICS`) is currently **DHCP** (`inet 172.16.0.12/24 scope global dynamic noprefixroute`, DNS `172.16.0.1`). A DNS server needs a **static** IP; `.12` is currently lease-assigned, so making it static risks a future DHCP collision unless it sits outside the router's lease pool (pool range not observable without router access).
- `tailscale0` is `100.81.179.26/32` (Tailscale MagicDNS `100.100.100.100` lives on the tailnet). `ss -tulpn` confirms **nothing is bound to :53 or :3000** today, and tailscaled does not bind LAN :53 — so it will not conflict with a LAN-facing DNS bind. Binding AdGuardHome to `172.16.0.12` (not `0.0.0.0`) keeps the DNS service off the tailnet.
- `systemd-resolved` is **active** but its stub listener (`127.0.0.53:53`) is **not listening** (only `MulticastDNS=no` drop-in present, no `resolved.conf`). The phone resolves via `nss-resolve` → resolved → `172.16.0.1`. No :53 conflict for AdGuardHome.
- `systemctl is-system-running` = `degraded` due to two failed units — **neither blocks this change**:
  - `postmarketos-zram-swap.service`: `zramctl: /dev/zram0: failed to set algorithm: Invalid argument` (kernel 6.0.0 lacks the configured zram algo). Cosmetic; phone has 7.5 GB RAM.
  - `sleep-inhibitor.service`: exits 1 with `System does not support any sleep states, quitting`. `/sys/power/state` is **empty** and `/sys/power/mem_sleep` absent — the kernel has **no suspend support at all**, so the phone physically cannot suspend. This removes the #1 operational risk (idle suspend) that the orchestrator flagged; the 4 registered `systemd-inhibit` "sleep" locks are inert because sleep is impossible.

**Service conventions on the phone (for the systemd unit):** unit files live in `/etc/systemd/system/`, `User=`/`Group=` set explicitly, `Restart=always`. Already running: `tailscaled`, `NetworkManager`, `avahi-daemon`, `ddclient` (Dynamic DNS updater), `cobalt` (node media-downloader API on :9015), `link-grabber-bot` (Go bot, depends on cobalt), `ath10k-crash-watch`.

## Affected Areas

- `openspec/changes/oneplus5-adguard-dns/` — this change's artifacts (proposal/specs/design/tasks).
- `docs/oneplus5-adguard-dns.md` (proposed) — operational runbook, matching `docs/sops-new-host.md` / `docs/wg-peer.md` convention.
- Versioned device artifacts (proposed new location, see Recommendation): `AdGuardHome.yaml` config + `adguardhome.service` systemd unit. There is **no `devices/` dir today** and no home for external (non-NixOS) device configs.
- `linux/system/networking/firewall.nix` — **confirmed irrelevant**: it only sets `networking.firewall.enable = false` on NixOS hosts; the phone is an external postmarketOS device, not a NixOS host, so no repo firewall code is touched.
- No Nix build/eval impact: `nix flake check --no-build` output is unaffected by a doc + device-config change (the phone is not in `flake.nix` hosts).

## Approaches

1. **Phone runs `adguardhome` from apk + authored systemd unit** (recommended)
   - pmOS edge `community` repo ships `adguardhome-0.107.79-r0` (arch `all`, built from source, ~35 MiB). The Alpine package installs `/usr/bin/adguardhome` and creates a dedicated `adguardhome` user/group, but its **only** init subpackage is `-openrc` (`/etc/init.d/adguardhome` + `/etc/conf.d/adguardhome`) — confirmed from the aports `APKBUILD` (`subpackages="$pkgname-openrc"`). **No systemd unit ships**, so we author `adguardhome.service` ourselves (standard `ExecStart=/usr/bin/adguardhome -s run --config /etc/adguardhome/AdGuardHome.yaml --work-dir /var/lib/adguardhome`, `User=adguardhome`).
   - Pros: native aarch64 binary, no container runtime, smallest footprint, package-maintained updates via `apk upgrade`, matches the box's existing systemd-unit conventions.
   - Cons: we own the unit file + config versioning; config is stateful on the phone (not declarative in Nix).
   - Effort: **Low–Medium**.

2. **Phone runs AdGuard Home via container (podman/docker)**
   - Pros: process isolation, pinned image version, easy rollback.
   - Cons: no container runtime is present on pmOS edge; adds daemon + storage overhead on a phone; must still manage systemd unit + port 53 (host networking) anyway; the apk binary already exists, so a container buys little.
   - Effort: **Medium–High**.

3. **Cloud DNS with logs (NextDNS per-device profiles)**
   - Pros: zero infra, works without touching the router, per-device DoT/DoH profiles and query logs out of the box.
   - Cons: requires configuring each TV individually (many TVs hardcode or restrict custom DNS); sends all LAN DNS to a third party; recurring subscription for full retention; no visibility into devices you cannot reconfigure.
   - Effort: **Low** (but weaker fit for "LAN-wide per-device visibility + optional blocking").

4. **Phone serves DHCP too (AdGuard Home's built-in DHCP server), replacing router DHCP** (escalation of Approach 1)
   - This is the realistic path to LAN-wide coverage given the stock-router limitation (below). Because the MiWiFi stock UI does not expose a LAN-DHCP DNS override, the only way to make *all* LAN clients use the phone's DNS without touching each device is to disable the router's DHCP server and let AdGuard Home assign leases with itself as DNS.
   - Pros: true LAN-wide, per-device visibility with zero per-TV configuration; AdGuard Home names clients by hostname automatically.
   - Cons: requires disabling the Xiaomi router's DHCP in its web UI (possible on stock MiWiFi per user reports, but not yet verified for this exact model) — a single point of failure; if the phone goes down, the LAN loses DHCP+DNS.
   - Effort: **Medium** (builds on Approach 1).

Fallback if neither router-DHCP override nor DHCP replacement is acceptable: set a static DNS (`172.16.0.12`) manually on each TV. `rog` as the DNS host was already rejected (not always-on due to the S5 shutdown hang).

## Recommendation

**Approach 1 (apk `adguardhome` + authored systemd unit), with Approach 4 (AdGuard Home DHCP server) documented as the escalation path** to achieve true LAN-wide coverage, and manual per-TV static DNS as the zero-router-change fallback.

Ship three versioned artifacts: a `docs/oneplus5-adguard-dns.md` runbook, a versioned `AdGuardHome.yaml`, and a `adguardhome.service` unit. Because the phone is an external device (not a NixOS host) and there is no `devices/` directory, keep it minimal: put the runbook in `docs/` and the two device artifacts alongside it under `docs/oneplus5-adguard-dns/` (a new `devices/oneplus5/` top-level dir is justified only if more external devices follow — for now that is speculative, so `docs/` wins on YAGNI).

**No new operational script is needed** (Go-only policy in AGENTS.md is respected). The change is a runbook + versioned config + one systemd unit — there is no recurring command to wrap in `pkgs/nixos-scripts/cmd/`. If a helper ever becomes necessary (e.g. re-sync the YAML to the phone), it should be a Go binary under `pkgs/nixos-scripts/cmd/`, but that is out of scope now.

Config essentials (verified from AdGuard Home source/docs): bind to `dns.bind_hosts: ["172.16.0.12"]` and `dns.port: 53`; `upstream_dns` to the router/ISP resolvers (or Quad9 `9.9.9.10` as the box already uses); `cache_size`/`cache_optimistic` for the phone; `statistics_interval` for per-client stats; query-log `interval` (1/7/30/90 days) for retention; `clients:` block for static per-client names. Web UI listens on `0.0.0.0:3000` by default — bind it to the LAN or localhost. Blocking is optional and can start in log-only mode (no Hagezi lists, `protection_enabled` on but empty filters) to first answer the "do my TVs phone home" question, then add Hagezi TV lists.

## Risks

- **Static IP collision**: making `.12` static without knowing the Xiaomi DHCP lease pool could cause a collision. Mitigation: pick an IP outside the observed pool or add a DHCP reservation (needs router access) — unresolved until router DHCP range is known.
- **Router DHCP override is unverified**: stock MiWiFi exposes WAN/Internet DNS but (per user reports) not LAN-DHCP DNS; the pineapple.net.au "Configure DNS Manually" is the *WAN* setting, not LAN DHCP. Confirmed limitation is the main reason Approach 4 or per-TV static DNS may be required. Must be verified against the user's exact MiWiFi model before promising LAN-wide coverage.
- **WiFi power-save / ath10k**: suspend is impossible (verified), but WiFi power-save (`wifi.powersave=2` in NetworkManager) and the known `ath10k-crash-watch` instability are the remaining reliability risks for a 24/7 DNS server; both belong in the runbook as config tasks.
- **DNS server is a phone**: if the phone reboots or drops WiFi, the whole LAN loses DNS. A secondary resolver (e.g. keep the router as fallback via DHCP option, or accept the outage window) should be decided in design.
- **Stateful config drift**: AdGuard Home config lives on the phone, not in Nix; the versioned YAML in the repo can drift from the live phone. The runbook must make "repo is source of truth, copy to phone + `-s reload`" explicit.

## Ready for Proposal

**Yes.** Recommend the orchestrator tell the user: (1) the phone cannot suspend (kernel has no sleep states), so the biggest risk is already gone — the remaining reliability risks are WiFi power-save and ath10k crashes; (2) the Alpine `adguardhome` package ships only an OpenRC init script, so we will author a systemd unit; (3) the stock Xiaomi router almost certainly cannot assign a custom LAN-DHCP DNS server, so LAN-wide coverage needs either per-TV manual DNS or moving DHCP to the phone (AdGuard Home's built-in DHCP) — the user should confirm which router model/firmware they have and whether they're willing to disable router DHCP. Scope the proposal to Approach 1 first (log-only, no blocking) with the Hagezi blocking and DHCP-server step as later, opt-in tasks.
