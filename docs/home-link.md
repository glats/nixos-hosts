# mact2↔rog link: architecture and day-to-day operation

**What it is**: your corporate Mac (mact2) browses through your home server (rog) over a private TLS link that the endpoint security agent cannot inspect. This is **not an OpenAI-only tool**: it is a **general-purpose** private egress for any application — the TUN automatically covers the IP traffic the security agent lets through, and the loopback proxy `127.0.0.1:2080` is a per-app door for the categories the security agent intercepts at socket level (any app that accepts its own proxy; see the "Generic mechanism" table below). OpenCode with native OpenAI is the flagship consumer and the worked example of this doc.

## Architecture in 30 seconds

```
                        ┌── TUN (automatic: IP traffic the agent lets through) ─┐
                        │                                                       │
same rules ──────────►  │    route rules (RFC1918→direct, agent→direct,         │  ──►  VLESS+WS+TLS
same fallback           │    final → urltest auto)                              │       tun.glats.org:443
                        │                                                       │
                        └── mixed 127.0.0.1:2080 (manual: CONNECT without SNI) ─┘
                                                     │
                                         Cloudflare → nginx rog → sing-box :4011 → internet
```

**Two entry doors, one link.** The TUN captures only what the security agent lets through; the loopback proxy is the manual door for the categories the security agent intercepts (it reads the SNI at socket level, before the routing layer — the TUN never sees those flows).

**What each door is for:**

| Traffic | Door | Setup needed? |
|---------|------|---------------|
| Generic (Azure, Apple, the web) | Automatic TUN | No |
| OpenAI / domains with security-agent category routing | Loopback proxy `127.0.0.1:2080` (per-app) | Yes, once per app |
| LAN / private ranges (172.16.0.0/24, 10.x) | None — direct by design | No |
| Security-agent management (163.116.0.0/16) | Excluded — direct (if the link dies, corporate telemetry stays up) | No |

**Why the system proxy (Settings → Proxies) is ruled out**: the security agent owns the system's global proxy dictionary (`scutil --proxy` shows its keys) — whatever you put there gets shadowed. Only per-app overrides work. The PAC generator was implemented and removed for this reason.

## Domains on macOS: how to route each one

### How the client resolves domains (mechanics)

1. The TUN captures the connection and the `sniff` rule extracts the real domain from the TLS ClientHello (SNI) — it does not depend on system DNS
2. The route rules compare that domain/IP against the exclusion lists, in order
3. Whatever matches no rule goes to `final` (auto urltest: link ↔ direct). Before that, QUIC (UDP/443) is **blocked**: the sing-box urltest only probes TCP and its UDP selection does not fail over — blocking QUIC forces browsers (HTTP-3) down to TCP, the only path that crosses the link and the one with real failover
4. The hostname travels encrypted up to rog — it is rog who resolves and connects (that is why the server log shows `[mact2] inbound connection to chatgpt.com:443` with the domain, not the IP)

### The two declarative knobs (hosts/mact2/default.nix)

```nix
# Domains that must NOT ride the link (they go direct, corporate path):
link.directDomains = [ "dominio-interno.falabella.cl" ];

# IP ranges that must NOT ride the link (already configured):
link.directCidrs = [ "163.116.0.0/16" ];   # security-agent cloud
```

After a change: `nixos-build` + `linkctl restart` (raw equivalent: `sudo launchctl kickstart -k system/org.nixos.sing-box` — kickstart requires the daemon loaded; if it was down, bootstrap).

**When to use each one?**

| Situation | Knob |
|-----------|------|
| A corporate service breaks because the link changes its egress route | `link.directDomains` |
| A corporate range/subnet (NAC, intranet, VPN) unreachable via the link | `link.directCidrs` |
| A domain blocked by the security agent that you need to reach | **None** — use the per-app proxy door (it is domain-agnostic, covers everything) |

### What does NOT work on macOS (tested — do not waste time)

| Trick | Why it dies |
|-------|-------------|
| `/etc/hosts` pointing domains at rog | The security agent filters by **SNI value**, not by IP — the ClientHello with a forbidden SNI is intercepted all the same |
| System PAC proxy | The agent shadows the system's global proxy dictionary |
| Manual proxy in Settings → Network | Same — you set it, and the agent re-asserts |
| WireGuard / UDP / direct SSH to rog | Blocked by the in-building corporate firewall |

### How to verify where a domain egressed

After adjusting the domain in question, on rog:

```bash
journalctl -u sing-box --since "5 min ago" | grep "\[mact2\]" | grep -i dominio
```

- **It appears** → it went through the link (rog resolved and connected)
- **It does not appear** → it went direct (active exclusion) or the agent intercepted it (for domains with category routing without a per-app proxy)

## Day-to-day commands (on mact2)

### Start / stop / status of the link

Main interface: `linkctl` (wrapped as `bin/linkctl`, packaged in `pkgs/nixos-scripts` — systemctl-style for the link daemon on mact2). Type it bare, from any path: start/stop/restart auto-promote with sudo on their own (re-exec with the script's absolute path resolved on the fly — does not depend on root's PATH); status runs unprivileged:

```bash
linkctl start     # UP (bootstrap+kickstart if never loaded; kickstart if already loaded)
linkctl stop      # DOWN (TUN disappears → Mac 100% corporate); idempotent
linkctl restart   # RESTART — MANDATORY after any link config change
linkctl status    # STATE (state/pid; distinguishes stopped from registered-idle post-reboot)
```

> Auto-sudo will ask for the password the first time (as always). No more typing `sudo` in front: it used to fail because root's PATH does not include the user profile where `linkctl` lives. On mact2 the binary also lives in the system profile (`/run/current-system/sw/bin/linkctl`) as a backup for shells with an odd PATH.

Raw equivalent (the same `launchctl` calls `linkctl` runs):

```bash
# DOWN (TUN disappears → Mac 100% corporate):
sudo launchctl bootout system/org.nixos.sing-box

# UP (only while rog is up — the daemon does NOT autostart;
# after a reboot it stays registered but STOPPED → kickstart is enough):
sudo launchctl kickstart system/org.nixos.sing-box

# if it says "Could not find service" (it was booted out earlier):
sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.sing-box.plist
sudo launchctl kickstart system/org.nixos.sing-box

# STATE (state = running + pid):
launchctl print system/org.nixos.sing-box | grep -E "state|pid"

# RESTART — kickstart works with the daemon loaded (running or stopped); -k kills the
# previous instance if it is running:
sudo launchctl kickstart -k system/org.nixos.sing-box
```

⚠️ Manual-operation daemon (`RunAtLoad=false`, `KeepAlive=false`, verified against Apple TN2083: "run purely on demand"): never autostarts at boot and if the process dies it stays down — expected, the corporate path works without it. With plain `bootstrap` the job ends up **registered but stopped** (without MachServices there is no "demand" to wake it) — that is why UP = `kickstart`. DOWN survives reboots, switches and crashes; UP must be re-issued after every reboot. After a reboot `linkctl status` shows the job **registered, idle** (no pid) — normal; `linkctl start` raises it.

### OpenCode with native OpenAI

```bash
opencode-home          # do NOT use plain `opencode`: the wrapper scopes the proxy
                       # to the process and keeps child MCPs clean.
                       # If the link is down, it still starts (without proxy).
```

### Browser with the link (for OpenAI and whatever comes up)

```bash
# Edge/Chromium — per-launch flag:
open -a "Microsoft Edge" --args --proxy-server=http://127.0.0.1:2080
```

```text
Firefox — one-time setup (persists in the profile):
Settings → Network Settings → Manual proxy → HTTP 127.0.0.1 port 2080
(√ "also use for HTTPS") · No proxy for: localhost, 127.0.0.1
```

**New domains blocked by the security agent**: there is no list to maintain — any domain you access **through the proxy** already rides the link. The per-app door is domain-agnostic. (The `link.directDomains`/`directCidrs` lists are for the opposite: excluding domains FROM the link.)

### Generic mechanism: point ANY app at the link

The system proxy is ruled out (the security agent shadows it). For any blocked app, the question is: *"does this app accept being told a proxy through its own mechanism?"*

| App class | Mechanism | Persistence |
|-----------|-----------|-------------|
| **Chromium** (Edge, Chrome, Brave, Arc) | Launch flag `--proxy-server=http://127.0.0.1:2080`, or config file: `defaults write com.microsoft.Edge ProxyMode -string fixed_servers` + `defaults write com.microsoft.Edge ProxyServer -string 127.0.0.1:2080` | Flag: every launch · defaults: permanent (⚠️ if IT pushes Edge policies via MDM, managed wins) · localhost is excluded from the proxy automatically (OAuth callback OK) |
| **Firefox / Gecko** | Profile → Manual proxy `127.0.0.1:2080` | Permanent in the profile |
| **CLI** (curl, git, npm, pip…) | Env at invocation or wrapper: `HTTPS_PROXY=http://127.0.0.1:2080 curl …`, `git -c http.proxy=http://127.0.0.1:2080 clone …` | Per-invocation |
| **OpenCode** | `opencode-home` (repo wrapper — scoped env + clean MCPs) | Zero (auto-detects) |
| **Native CFNetwork apps** (Mail, App Store…) | No reliable per-app door — the proxy dict is stomped by the agent | — |

**General rule**: if the app has its own proxy config, point it at `127.0.0.1:2080` and all its traffic (blocked domains included) rides the link. If it only reads the system proxy, there is nothing to do without a wrapper. Never export `HTTP(S)_PROXY` in shell profiles — wrappers only (child MCPs inherit the env and must stay clean).

### Device OAuth bootstrap (the full flow)

Each device does its **own** OAuth login — auth.json is not copied between hosts (the seed script is obsolete as a mechanism; it is a dormant fallback).

```bash
# on the device, WITH the link up:
opencode-home auth login       # wrapper: the token exchange rides the link
```

1. Copy the URL opencode prints
2. Open it in a browser **with the proxy configured** (Edge flag/policy or Firefox profile)
3. Log in at auth.openai.com (the agent does not see that flow — it rides the link)
4. Redirect to `localhost:1455` → Chromium excludes localhost from the proxy → opencode captures the code
5. The token exchange is done by opencode itself **over the link** (hence the wrapper)

⚠️ Do not run bare `opencode auth login`: the token exchange is an OpenAI-bound flow the agent would intercept without the wrapper's proxy env.

### Health check (30 seconds)

```bash
# 1. The link delivers REAL certificates (not the agent's corporate CA):
curl -x http://127.0.0.1:2080 -sSIv https://auth.openai.com/ 2>&1 | grep "issuer:"
#    expected: O=Google Trust Services / Cloudflare
#    bad sign: issuer of the corporate CA (the agent intercepted)

# 2. The full link is active (TUN capturing):
curl -sS https://ipinfo.io/ip        # → 201.188.187.112 (egress via rog)

# 3. Fallback: if rog is down, the same curl keeps returning YOUR corporate
#    IP within ≤30 s and everything keeps browsing — automatic degradation.
```

### Phone (sing-box Android / SFA)

```bash
# on rog — generates link (interactive QR) or config JSON for SFA:
sudo bin/device-link phone            # vless:// link + QR (v2rayNG-class)
sudo bin/device-link phone --config   # full JSON → SFA Local profile
```

`--config` is the one that works with SFA (it does not parse `vless://`). Import: Profiles → + → Local → clipboard. The phone profile uses system DNS (`type: local`) — works on any mobile/WiFi network.

## Server commands (on rog)

```bash
systemctl status sing-box --no-pager        # server service
journalctl -u sing-box -f                   # watch connections LIVE: [mact2], [phone]
journalctl -u sing-box --since "30 min ago" | grep phone
ss -tln | grep 4011                         # loopback inbound listening
```

Every authenticated connection appears with the device name (`[mact2]`, `[phone]`) — that is how you know who is using the link and which destinations they visit (by domain; the server resolves).

## Revoke / rotate devices

Revocation is **server-authoritative**: it changes which UUIDs rog accepts; whatever the client has stored stops working.

> The UUIDs live in `secrets/shared/link-uuids.yaml` (sops), with `link/uuid_*` declarations — renamed from the historical namespace by the `naming-hygiene` change.

```bash
# ROTATE a device (new UUID, same slot):
sops secrets/shared/link-uuids.yaml         # edit uuid_phone: <new>
git add + commit + push
nixos-build                                  # rog now expects the new one
sudo bin/device-link phone                   # new link → re-import on the phone

# REVOKE completely (example: phone):
#   1. remove the "phone" entry from the users array (linux/system/services/network/sing-box-link.nix)
#   2. remove the declaration in hosts/rog/secrets.nix
#   3. remove the uuid_phone key from the sops file
#   4. nixos-build on rog
# mact2 never notices — each UUID is independent.
```

## Known failures and what they mean

| Symptom | Cause | Action |
|---------|-------|--------|
| All browsing dies | Daemon ON + rog down, not yet degraded (≤30 s) | Wait for the urltest probe (30 s interval + teardown of existing connections) |
| Falabella "Application Not Allowed" page in the browser | You are on the corporate path for that domain (link down, or browser without proxy) | Raise the link / use a browser with proxy |
| `issuer:` of the corporate CA in a test | The flow did NOT go through the loopback proxy | Check `--proxy-server` / profile |
| You changed the link config and it does not apply | launchd does not restart if the plist did not change | `linkctl restart` (or raw: `kickstart -k` if loaded, `bootstrap` if unloaded) |
| `WARN icmp is not supported by outbound` in old logs | Config older than the ICMP→direct rule | Already resolved; if it reappears post-rebuild, kickstart |

> Lesson from the 2026-08 incident (rog down 2 days): the sing-box urltest probes **TCP only** — UDP selection stayed pinned to the dead link (QUIC/HTTP-3 hanging) while TCP degraded fine to direct. That is why UDP/443 is now blocked (QUIC falls back to TCP: only TCP crosses the link) and the fallback is ≤30 s with teardown of existing connections. Also, the urltest lists `direct` first: with no probe history (boot/freshly configured) it picks the first entry — the safe default is the corporate path, not a possibly dead link.

## Where everything lives

| Piece | File |
|-------|------|
| macOS client (TUN + mixed + launchd + urltest) | `darwin/system/sing-box-link.nix` |
| rog server (multi-user VLESS, :4011) | `linux/system/services/network/sing-box-link.nix` |
| tun.glats.org vhost (cover page + WS path) | `linux/system/services/web/nginx.nix` |
| Launchers | `bin/opencode-home`, `bin/device-link`, `bin/linkctl` (packaged in `pkgs/nixos-scripts`) |
| MCP scrub (host-agnostic) | `shared/opencode/runtime-config.nix` |
| Credentials (2 UUIDs) | `secrets/shared/link-uuids.yaml` (sops; specific rule in `.sops.yaml`; `link/uuid_*` declarations) |
| Client exclusion rules | `hosts/mact2/default.nix` (`link.directCidrs`, `link.mode`) |
| Rename SDD change | `openspec/changes/naming-hygiene/` (the historical SDD change for this stack keeps its original narrative and is pending relocation out of the repo) |

## Pending (does not block day-to-day use)

- **OFFICE GATES** — validation inside the building: coexistence with FortiClient, CrowdStrike, corporate firewall (WS long-lived), observed SNI = `tun.glats.org` only.
- Phone revocation test and runtime flip to scoped mode — procedures in the historical SDD change.
- Full rollback = reverting the commits on master (everything is declarative; the UUIDs survive in sops).
