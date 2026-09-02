# Exploration: mact2 OpenAI TLS tunnel via rog (single-URL)

Feasibility study only. No Nix/config changes outside this directory, no secret decryption, no build/switch, no commits. Probes are read-only.

## Current State

`mact2` (macOS 26.6.2 Intel, user `jcuzmar`) carries **two always-on security agents**: the Netskope Mac AppProxy system extension (`com.netskope.client.Netskope-Client.NetskopeClientMacAppProxy` 138.1.12, a local transparent-proxy / SNI-interception extension) **and** CrowdStrike Falcon (`com.crowdstrike.falcon.Agent` 7.39), plus Netskope Endpoint DLP. `scutil --proxy` shows no explicit proxy (`BypassAllowed: 0`) — interception is transparent, enforced by the local AppProxy extension. This means the Netskope MITM is **always on wherever mact2 is**, not just in the office (re-verified today from the home LAN).

mact2 is currently wired to the **broken** `openai-proxy` gateway: live `~/.config/opencode/opencode.json` shows provider `openai-proxy` (baseURL `https://oai.glats.org/v1`) and the orchestrator/neutral agents use `openai-proxy/gpt-5.4`. That gateway 401s on every request (root cause identified this session — see Probe P8). mact2's `auth.json` already holds an `openai` OAuth entry, so bootstrap is a re-login concern, not a first-time concern.

Relevant repo wiring (read this session):
- `linux/system/services/web/nginx.nix` — wildcard ACME for `glats.org` + `*.glats.org` (Cloudflare DNS-01), many loopback proxy vhosts already using `proxyWebsockets = true`; `oai.glats.org` vhost still live.
- `linux/system/services/web/opencode-proxy.nix` — the broken gateway: Python/uvicorn loopback proxy that rewrites `Authorization` to an upstream key and forwards to `baseURL`.
- `hosts/rog/default.nix` — `services.opencodeProxy.enable = true`, `upstream.baseURL = "https://api.openai.com"`.
- `hosts/rog/secrets.nix` — `openai_proxy/upstream_key` + `openai_proxy/client_key` from `secrets/host/rog/openai-proxy.yaml`.
- `linux/system/services/network/wireguard.nix` — WG server live (`wg0` 10.13.13.1, `guard.glats.org:51820`), peers incl. `mac` = 10.13.13.3.
- `shared/opencode/providers-base.nix` — `openai-proxy` provider + `openai-{full,medium,light}-proxy` tiers (gateway family to retire).
- `shared/opencode.nix` — exports `OPENAI_PROXY_API_KEY` from `openai_proxy/client_key` in zsh init.
- `.sops.yaml` — creation rules; the `secrets/host/rog/openai-proxy.yaml` rule encrypts for admin+rog+mact2.
- `pkgs/opencode/default.nix` — pins `anomalyco/opencode` **v1.18.18**.

## Research Findings (MCP-verified)

### R1 — NixOS service modules: `services.sing-box` EXISTS, `services.xray` DOES NOT
Verified via nixos MCP + nixpkgs source at `nixos-26.05`.
- `services.sing-box` (module `nixos/modules/services/networking/sing-box.nix`): options `enable`, `package` (`sing-box` 1.13.x), and `settings` (freeform JSON). `settings` values containing secrets may be set to `{ _secret = "/path/to/file"; }` — the module's `ExecStartPre` runs `genJqSecretsReplacementSnippet` to substitute file contents at runtime. This is the sops integration path. The service runs as an **unprivileged `sing-box` system user** — sufficient for the server side (loopback VLESS+WS inbound, no TUN/capabilities needed).
- `services.xray`: **no NixOS module exists** — `xray` (26.2.6) is a package only. sing-box is the declarative choice.
- sing-box package (26.05) builds pure-Go (`CGO_ENABLED=0`, tags `with_gvisor with_quic with_utls ...`), no `meta.platforms` restriction → available on `x86_64-darwin` (mact2 Intel) as well as Linux.

### R2 — nix-darwin launchd: root daemon + user agents both exist
Verified via nixos MCP (`source=darwin`):
- `launchd.daemons.<name>` — root LaunchDaemons with generated plists (`command` / `script` / `serviceConfig`). **Required for TUN** (root needed to create `utun`).
- `launchd.agents.<name>` — per-user LaunchAgents (not sufficient for TUN).
- `environment.launchDaemons.<name>` — raw plist symlinks into `/Library/LaunchDaemons` (fallback).

### R3 — sing-box VLESS+WS+TLS behind nginx path (context7 + exa)
Battle-tested "cover-path" pattern (v2fly guide; `hansvlss/sing-box-vps`; `Secret-Sing-Box`). Server shape:
- sing-box server: VLESS inbound on `127.0.0.1:<port>` with `transport: {type: ws, path: "/<path>"}`, outbound `direct`. TLS handled by nginx, **not** by sing-box.
- nginx location: `proxy_pass http://127.0.0.1:<port>; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade";` — equivalent to the repo's existing `proxyWebsockets = true` pattern (already used by `jelly`, `gonic`, `openfang/ws`, `mkProxyVhost`).
- Client outbound: `vless` + `tls.enabled` + `server_name: tun.glats.org` + `transport: {type: ws, path: "/<path>"}`.
- **Gotcha (sing-box#1728)**: nginx passes the location path through to the backend, so sing-box server's `ws.path` must equal the nginx location prefix (or use a trailing-slash `proxy_pass` to strip). Keep them identical.
- WebSocket (not HTTP transport) is the safe choice behind nginx/Cloudflare.

### R4 — sing-box TUN on macOS (context7 + exa)
- TUN inbound supported on macOS (`type: tun`), key options: `interface_name`, `address`, `mtu`, `auto_route`, `strict_route`, `route_exclude_address`, `stack` (`system` uses `utun`), `sniff`.
- **Requires root** on macOS (utun). Run via a root LaunchDaemon (`launchd.daemons`), not a user agent.
- Domain-rule routing: `route.rules[].domain_suffix` matches the **sniffed** domain (`metadata.Domain` from TLS SNI) falling back to FakeDNS `Destination.Fqdn`. For HTTPS targets, **SNI sniffing (`sniff: true` on the TUN inbound) is sufficient** — no FakeDNS required for `chatgpt.com`/`auth.openai.com`.
- Coexistence prior art: sing-box TUN is a raw `utun`, **not** a NetworkExtension, so it does not consume macOS's "one DNS-proxy/content-filter NetworkExtension" slot (jamf thread). `route_exclude_address` + `route.auto_detect_interface` are the documented levers to keep corporate VPN/agent subnets on the default route (sing-box#3586). Real-world reference config (Jinmiao Luo, macOS 26.2) uses `auto_route + strict_route + stack mixed + hijack-dns` and auto-starts via launchd.

### R5 — Transport-family comparison (exa: NexTunnel/Valebyte/ClashBaike/GreatFirewall 2026)
See the ranked verdict below. Summary: the threat model here is **category-based SNI filtering by a transparent proxy (Netskope)**, not adversarial GFW DPI. The requirement is simply: *outer TLS SNI must be a non-blocked hostname (`*.glats.org`)* and *traffic must be TCP/443 TLS*.

### R6 — OAuth endpoints re-derived from the pinned source (NOT inherited)
Fetched `packages/opencode/src/plugin/openai/codex.ts` at tag `v1.18.18` (anomalyco/opencode). Constants and flows, read directly:
- `ISSUER = "https://auth.openai.com"`; `CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"`.
- `CODEX_API_ENDPOINT = "https://chatgpt.com/backend-api/codex/responses"`.
- The provider fetch override rewrites any `/v1/responses` or `/chat/completions` path to `CODEX_API_ENDPOINT`.
- Token exchange/refresh: `POST https://auth.openai.com/oauth/token`.
- Browser flow: PKCE + localhost `:1455/auth/callback`; authorize URL at `auth.openai.com/oauth/authorize`.
- **Headless device flow**: `POST auth.openai.com/api/accounts/deviceauth/usercode` → poll `POST .../deviceauth/token` → exchange at `.../oauth/token` (redirect_uri `https://auth.openai.com/deviceauth/callback`); user visits `https://auth.openai.com/codex/device` in a browser.
- The string `api.openai.com` appears **only** in the JWT claim namespace `"https://api.openai.com/auth"`, never as a fetch target.
- **Conclusion (re-derived): the native OpenAI OAuth + Codex flow hits exactly two hosts — `chatgpt.com` and `auth.openai.com`.** The TUN allowlist must cover both, plus any subdomains the browser flow touches (`auth.openai.com` covers the OAuth issuer).

## Probe Results (read-only, sanitized)

Host `rog` (current shell); mact2 via `ssh jcuzmar@mact2.local` (key auth). No secret values printed.

| # | Probe | Result | Meaning |
|---|---|---|---|
| P1 | `dig +short tun.glats.org` (rog + mact2) | `172.67.218.149`, `104.21.86.114` | Resolves via the existing `*.glats.org` wildcard, **orange-cloud** (Cloudflare-fronted). No new DNS record needed. |
| P2 | `dig +short guard.glats.org` | `201.188.187.112` | Grey-cloud (direct to rog public IP). |
| P3 | `wg show wg0` (rog) | `mac` peer `9MFatUr…=10.13.13.3`: no endpoint, **no handshake, no transfer**; no peer has a current handshake | WG transport unproven at runtime. |
| P4 | `systemctl is-active nginx opencode-proxy` | both `active` | Old gateway still running. |
| P5 | `curl https://oai.glats.org/v1/models` (rog, no auth) | `401 {"error":"unauthorized"}` | Proxy's own client-key gate (expected, no header sent). |
| P6 | `curl` oai.glats.org **with real client key** (mact2, key read from `~/.config/sops-nix/secrets/openai_proxy/client_key`, never echoed) | `401 {"error":{"message":"Incorrect API key provided: nvapi-Er…JO_1 …","code":"invalid_api_key"}}` | **Root cause confirmed**: the gateway forwards an `nvapi-` NVIDIA NIM key to `api.openai.com`, which rejects it. |
| P7 | `opencode --version` (mact2) | `1.18.18` | Matches `pkgs/opencode/default.nix`. |
| P8 | `systemextensionsctl list` (mact2) | `com.netskope…NetskopeClientMacAppProxy` + `com.crowdstrike.falcon.Agent`, both `activated enabled`; `Netskope Endpoint DLP` running | Two security agents coexist today. |
| P9 | `scutil --proxy` (mact2) | empty dict (`BypassAllowed: 0`) | Transparent interception, not explicit proxy. |
| P10 | `ls /dev/utun*` (mact2) | none | No active VPN/tun today. |
| P11 | `sudo -n true` (mact2) | password required | TUN must run as a root LaunchDaemon (nix-darwin), not user sudo. |
| P12 | `nc -z 172.16.0.5 22/443` (mact2→rog LAN) | both **open** | mact2 reaches rog on the home LAN (only relevant from home). |
| P13 | `curl https://guard.glats.org` (mact2, home) | `HTTP 200`, `remote_ip=201.188.187.112`, `ssl_verify=0`, LE cert | Grey-cloud SNI pass-through works from home. |
| P14 | `curl https://api.openai.com/v1/models` (mact2, home) | `SSL cert problem: self-signed … (19)`, HTTP 000 | Netskope MITM **is active from home too**. |
| P15 | SNI issuer probes (mact2, home): `api.openai.com`, `chatgpt.com`, `auth.openai.com` | issuer `… CN=ca.grupofalabella.goskope.com` (Netskope CA) | Whole OpenAI namespace hijacked at ClientHello by SNI value. |
| P16 | SNI issuer probe `tun.glats.org` (mact2, home) | issuer `C=US, O=Google Trust Services, CN=WE1` (Cloudflare edge) | `*.glats.org` SNI passes uninspected (today, from home). |
| P17 | deployed `opencode.json` (mact2) | provider `openai-proxy` (baseURL `oai.glats.org/v1`); agents `openai-proxy/gpt-5.4` | mact2 fully wired to the broken gateway. |
| P18 | `auth.json` keys (mact2) | `openai` present (+ anthropic, github-copilot, opencode-go) | `openai` OAuth credential already exists. |

## Inherited Claims Audit

Load-bearing claims from the three prior changes, re-verified independently this session.

| # | Inherited claim | Source | Verdict | Evidence |
|---|---|---|---|---|
| C1 | Direct native OpenAI egress from mact2 is blocked by corporate TLS MITM | preflight 1.1 / oauth-via-rog | **CONFIRMED** | P14/P15: `api.openai.com`/`chatgpt.com`/`auth.openai.com` all re-signed by `ca.grupofalabella.goskope.com` from home today. |
| C2 | Block is network-policy / category-based, not an OAuth failure | preflight 1.1 / oauth-via-rog | **CONFIRMED** (as class) | Netskope transparent SNI interception reproduced; exact policy id `GL_FTC_Generative_IA_C3_BLOCK` is in-building evidence → **UNVERIFIED-today**. |
| C3 | OAuth fetch targets are `chatgpt.com` + `auth.openai.com`, NOT `api.openai.com` | oauth-via-rog R2 | **CONFIRMED** (re-derived) | R6: read `codex.ts` at v1.18.18; `api.openai.com` is JWT-claim namespace only. |
| C4 | Preflight recorded the block at `api.openai.com/v1/responses` as the fetch target | preflight 1.1 | **REFUTED** (as literal fetch target) | R6: fetch override rewrites to `chatgpt.com/backend-api/codex/responses`. The preflight URL was a block-page normalization, not the real target. |
| C5 | No MCP-safe narrow per-provider `baseURL` for the built-in `openai` provider | oauth-via-rog R3 | **CONFIRMED** | R6: `CODEX_API_ENDPOINT` is a hardcoded const; only custom `@ai-sdk/openai-compatible` providers accept baseURL. |
| C6 | MCP children inherit parent env (`...process.env`) | oauth-via-rog R1 | **CONFIRMED** (prior source-level; not re-fetched this session) | Non-load-bearing now: TUN is L3 and uses no proxy env at all. |
| C7 | WireGuard `mac` peer (10.13.13.3) has never handshaken | oauth-via-rog P3b | **CONFIRMED** | P3: no endpoint/handshake/transfer for `9MFatUr…`. |
| C8 | WG UDP 51820 blocked in-building | addendum A/user | **UNVERIFIED-today** | Can only be tested on the office network. |
| C9 | Public SSH to rog:22 filtered in-building | addendum A5 | **UNVERIFIED-today** | In-building only. |
| C10 | Non-TLS flows to rog:443 dropped in-building | addendum A4 | **UNVERIFIED-today** | In-building only. |
| C11 | `*.glats.org` SNI passes with a legit cert | addendum A3 | **CONFIRMED** | P16: `tun.glats.org` → Google Trust Services (Cloudflare edge), not Netskope. |
| C12 | Netskope hijacks OpenAI SNI regardless of destination IP | addendum A1/A2 | **CONFIRMED** | P15: SNI-value interception reproduced from home today. |
| C13 | Gateway (oai.glats.org / opencode-proxy) broken with upstream 401 | proxy-via-rog / oauth-via-rog | **CONFIRMED + root cause** | P6: `nvapi-` NVIDIA key sent to `api.openai.com` → `invalid_api_key`. |
| C14 | Gateway upstream is `api.openai.com` | read opencode-proxy.nix + rog default.nix | **CONFIRMED** | `upstream.baseURL = "https://api.openai.com"`. |
| C15 | mact2 opencode 1.18.18 matches the pin | oauth-via-rog P2d | **CONFIRMED** | P7. |
| C16 | mact2 already has an `openai` OAuth credential | oauth-via-rog P2b | **CONFIRMED** | P18. |
| C17 | mact2 wired to `openai-medium-proxy` | AGENTS.md / flake.nix | **CONFIRMED** | P17: live opencode.json uses `openai-proxy`. |
| C18 | `services.sing-box` or `services.xray` exists | addendum | **PARTIAL** | `services.sing-box` **exists** (R1); `services.xray` **does not** (package only). |
| C19 | REALITY unnecessary (category filtering, not adversarial DPI) | addendum | **CONFIRMED** | P15/P16: category-based SNI filter, not DPI. |

## Transport Family Comparison (ranked)

Evaluated on: (a) survives SNI-value filtering in-building, (b) MCP-safe scoping, (c) NixOS + nix-darwin declarative fit (verified option names), (d) maintenance burden.

| Rank | Family | Survives SNI filter | Nix fit | Maintenance | Verdict |
|---|---|---|---|---|---|
| **1** | **VLESS + WS + TLS behind nginx path** (cover-path) | ✅ outer SNI = `tun.glats.org` (verified passing, P16) | ✅ `services.sing-box` (NixOS) + `launchd.daemons` (darwin) | Low — 1 module + 1 nginx location + 1 sops secret | **RECOMMENDED** |
| 2 | Trojan + WS + TLS behind nginx path | ✅ same outer SNI | ✅ same sing-box module (`type: trojan`) | Low — password instead of UUID | Equivalent; VLESS+WS chosen as the more standard/documented combo for this exact shape |
| 3 | VLESS + REALITY / Trojan (raw TCP :443) | ✅ (but not nginx/CF compatible) | ⚠️ requires nginx `stream` + `ssl_preread` SNI-mux surgery on :443 | High — conflicts with existing HTTP vhosts, no Cloudflare | Overkill; REALITY is for adversarial DPI, not category filtering |
| 4 | Hysteria2 (UDP/QUIC) | ❌ UDP blocked in-building (C8-class); needs dedicated port | ⚠️ sing-box module supports it | Medium | Fails the in-building UDP constraint |
| 5 | Shadowsocks-2022 | ❌ non-TLS custom port, "unknown encrypted" traffic | ⚠️ | Low | Doesn't survive SNI/category or port policy |

**Ranked verdict: VLESS+WS+TLS behind nginx path.** It reuses the existing nginx `:443` + wildcard ACME + Cloudflare (no new public port), carries an allowed `*.glats.org` SNI (defeats both Netskope's always-on category MITM and the in-building gateway firewall's TLS-only policy), is scoped at L3 (MCP-safe by construction), and maps to a first-class `services.sing-box` NixOS module + nix-darwin `launchd.daemons`. One secret (VLESS UUID).

## Feasibility Verdict per Component

- **F-Server (rog)**: **FEASIBLE.** New portable module `linux/system/services/network/sing-box-tunnel.nix` (or reuse `services.sing-box` inline in rog) with a loopback VLESS+WS inbound + `direct` outbound; one nginx vhost `tun.glats.org` with a path-routed `proxyWebsockets` location; UUID via sops `_secret`. Runs as unprivileged `sing-box` user. No new DNS record (wildcard already resolves).
- **F-Client (mact2)**: **FEASIBLE.** nix-darwin `launchd.daemons.sing-box-tunnel` (root) running `sing-box run -c /etc/sing-box-tunnel/config.json`; TUN inbound (`auto_route`, `strict_route`, `sniff: true`, `stack: system`), VLESS+WS outbound to `tun.glats.org/<path>`, `route.rules` with `domain_suffix: ["chatgpt.com","auth.openai.com","oaistatic.com","openai.com"] → tunnel`, `final: direct`. Config JSON written declaratively; UUID from sops.
- **F-Scope (MCP-safe)**: **FEASIBLE by construction.** L3 TUN domain rules — no `HTTP(S)_PROXY` env, no per-MCP scrubbing, MCP children keep default routing.
- **F-OAuth bootstrap**: **FEASIBLE.** Headless device flow (R6) through the tunnel; or the browser flow (localhost:1455 callback) — the browser's request to `auth.openai.com` also matches the `domain_suffix` rule and traverses the tunnel. Refresh (`auth.openai.com/oauth/token`) must stay in the allowlist or sessions die ~1h after login.
- **F-Coexistence (sing-box TUN + Netskope + CrowdStrike)**: **UNVERIFIED — the gating unknown.** Both agents run today (P8). sing-box TUN is a raw utun (not a NetworkExtension), and `route_exclude_address`/`auto_detect_interface` are documented levers, but actual stacking order and whether CrowdStrike's EDR flags a root TUN daemon can only be proven in-building.

## Overall Verdict

**CONDITIONALLY FEASIBLE.** The architecture hypothesis survives zero-assumption re-verification at every layer testable from home: SNI-category filtering is reproduced (P15), `*.glats.org` passes uninspected (P16), `tun.glats.org` already resolves via the wildcard (P1), the OAuth host set is re-derived as `chatgpt.com`+`auth.openai.com` (R6), and both `services.sing-box` and `launchd.daemons` are verified option names (R1/R2). The two gating unknowns are in-building only: (1) sing-box TUN coexistence with the Netskope AppProxy + CrowdStrike Falcon agents, and (2) whether the corporate gateway lets TCP/443 TLS to a Cloudflare IP through (very likely, but unproven).

## Recommended Approach

1. **Server (rog)**: add `services.sing-box` config (VLESS+WS inbound on `127.0.0.1:4xxx`, path `/tun-<random>`), a `tun.glats.org` nginx vhost with a path-routed `proxyWebsockets` location, and a new sops secret `secrets/shared/opencode-tunnel.yaml` (`uuid`) encrypted for admin+rog+mact2 (new creation rule mirroring `openai-proxy.yaml`, placed before the generic catch-alls).
2. **Client (mact2)**: nix-darwin `launchd.daemons` (root) running sing-box with a TUN inbound + domain rules (`chatgpt.com`, `auth.openai.com` → tunnel; `final: direct`), UUID from the same sops file.
3. **Bootstrap**: independent headless device-flow login (`opencode auth login` → "ChatGPT Pro/Plus (headless)") with the tunnel up; keep the age-seed (`bin/install-opencode-auth-seed`) as a one-shot fallback only.
4. **Retire old gateway** (gated on transport proof, follow-up scope): delete `linux/system/services/web/opencode-proxy.nix`, the `oai.glats.org` nginx vhost, `services.opencodeProxy` in rog, `openai-proxy` provider + `openai-*-proxy` tiers in `providers-base.nix`, the `openai_proxy/client_key`/`upstream_key` sops decls + `openai-proxy.yaml`, `OPENAI_PROXY_API_KEY` export, and switch mact2's `activeProviderName` to a native `openai-*` tier.

## Evidence Gates

### (a) Validatable TODAY from home
- [x] SNI category filter reproduces (`api/chatgpt/auth.openai.com` → Netskope CA; `tun.glats.org` → real cert) — P15/P16.
- [x] `tun.glats.org` resolves via wildcard, orange-cloud — P1.
- [x] mact2 reaches rog (LAN + public grey/guard) from home — P12/P13.
- [x] Gateway root cause (`nvapi-` key → `api.openai.com`) — P6.
- [ ] (post-implementation) `opencode run -m openai/gpt-5.4 "PONG"` succeeds from mact2 **on the home LAN** with the tunnel up — proves the transport + OAuth end-to-end (not the in-building path).
- [ ] `ps eww` of every MCP child shows no `HTTP(S)_PROXY` (TUN design keeps this trivially true).

### (b) Only validatable in-building
- [ ] sing-box TUN coexists with Netskope AppProxy + CrowdStrike Falcon: no route loop, corporate apps unaffected, `route_exclude_address`/`auto_detect_interface` keeps corporate subnets on the default route.
- [ ] From the office: a request through the tunnel to `chatgpt.com/backend-api/codex/responses` AND `auth.openai.com/oauth/token` succeeds, with outer SNI observed = `tun.glats.org` only.
- [ ] Corporate gateway does not block long-lived TCP/443 TLS to the Cloudflare IP (expected pass).
- [ ] CrowdStrike EDR does not flag/block the root sing-box TUN daemon.

## Citation Quality

- **Source-level (high confidence):** R6 (`codex.ts` at v1.18.18, raw fetch); R1/R2 (nixpkgs/nix-darwin option names via MCP + nixpkgs source); R3/R4 (context7 sing-box docs + exa prior art); R5 (exa transport comparisons).
- **Runtime-observed (high confidence):** P6 (gateway root cause), P14–P16 (SNI MITM vs pass-through today), P3 (WG never handshaken), P8 (both agents active).
- **Unverified / in-building only:** C8–C10 (gateway firewall blocks), F-Coexistence, Cloudflare JA3 challenge risk (low, residential exit).
- **Not re-fetched this session:** C6 (mcp/index.ts `...process.env`) — prior source-level, non-load-bearing for the TUN design.

# Addendum 2 — 2026-08-28: full-tunnel + multi-device + stealth pivot

Scope pivot only. Re-verified prior findings (Netskope SNI filtering, VLESS+WS+TLS choice, `services.sing-box`, `launchd.daemons`) are NOT re-litigated here. This addendum covers the three new requirement clusters: **full-tunnel default**, **per-device auth (N UUIDs)**, and **stealth hardening** (uTLS + cover page + unguessable WS path). Version pinned: `sing-box` **1.13.14** (nixpkgs `nixos-26.05`, rev `4382ed2`).

## Research Findings (MCP-verified)

### R1 — Multi-user VLESS inbound (context7 `/sagernet/sing-box`, `docs/configuration/inbound/vless.md`)
The VLESS inbound `users` field is an **array** of `{ name, uuid, flow }` objects (`option/vless.go: VLESSUser{Name, UUID, Flow}`). N devices = N array entries on one inbound — no extra inbounds needed. Example shape: `{ "type": "vless", "users": [ {"name":"mact2","uuid":"…"}, {"name":"phone","uuid":"…"} ], "transport": {"type":"ws","path":"/…"} }`. `flow` is per-user and defaults empty (our WS path uses no flow — flow is only for TLS-in-sing-box REALITY/Vision, which we don't use behind nginx).

### R2 — Full-tunnel route config (context7 `inbound/tun.md`, `route/index.md`, `manual/proxy/client.md`)
Full-tunnel = TUN inbound with `auto_route: true` + `route.final = "tunnel"` outbound tag, with exclusion rules ordered before the final catch-all:
1. `{"action":"sniff"}` + `{"protocol":"dns","action":"hijack-dns"}`,
2. `{"ip_is_private": true, "outbound": "direct"}` — RFC1918/ULA → direct (documented matcher),
3. `rule_set` (geoip/geosite or custom `.srs`) + `ip_cidr` for corporate/EDR endpoints → direct,
4. `process_name` rules for EDR binaries → direct (R3),
5. `domain_suffix` for corporate/Netskope/CrowdStrike management → direct,
6. `final: "tunnel"`.

macOS-relevant interplay (all confirmed present in 1.13): `route.auto_detect_interface` ("Only Linux/Windows/macOS") binds the tunnel's own outbound connection to the physical NIC so `tun.glats.org` doesn't loop back into the TUN — **required** for full-tunnel on macOS (or set `route.default_interface`). `route.default_domain_resolver` (since **1.12.0**, available here) must point at a *direct* resolver so the `tun.glats.org` hostname resolves without tunnel recursion (chicken-and-egg). Recommended macOS TUN values per docs + community references: `auto_route: true`, `strict_route: true` (prevents DNS leaks / unreachable-marking), `stack: "system"` (native `utun`; `gvisor` works but `system` is needed for process resolution — see R3), `sniff: true`, `mtu` **omit** (defaults; example's `9000` is the schema's max placeholder — over WS+TLS a lower MTU avoids fragmentation). Scoped mode = the same TUN with `final: "direct"` + `domain_suffix: [openai domains] → tunnel` (the prior single-URL config). Config flip = swap the route block.

### R3 — process_name on macOS (context7 `route/rule.md`; exa: sing-box internals process searcher, Apple features page, issues #3934/#4004/#3430)
`process_name` / `process_path` / `process_path_regex` are documented "Only supported on **Linux, Windows, and macOS**". Critical caveat from the **Apple features page**: they are "only supported in the **macOS standalone** and iOS jailbreak versions" — i.e. **NOT** in the SFI/SFM NetworkExtension apps. mact2 runs the standalone `sing-box` binary via a root launchd daemon, so process rules ARE available. macOS process resolution walks `sysctl net.inet.tcp.pcblist_n`/`net.inet.udp.pcblist_n` + `proc_info`; the PCB list format is **undocumented and version-dependent** (struct size via `kern.osrelease` is "fragile but necessary"). **`find_process_mode` does not exist in sing-box** — the actual option is `route.find_process` (bool), which only enables process search *for logging when no process rules exist*; process rules themselves auto-trigger the searcher (rule-sets track `ContainsProcessRule`). Limitations/risks: (a) per-connection sysctl walk is expensive → high CPU under many connections (issue #3934); (b) the searcher fires on non-local/LAN traffic too → `process not found` log noise (issue #4004); (c) macOS searcher can error (`not implemented error 0`, issue #3430). Verdict: process exclusions for EDR are **feasible** on macOS standalone, but treat them as best-effort and back them with IP/domain exclusions as the authoritative gate.

### R4 — uTLS client fingerprint (context7 `configuration/shared/tls.md`)
Outbound TLS accepts `"utls": { "enabled": true, "fingerprint": "chrome" }`; fingerprints: `chrome`, `firefox`, `edge`, `safari`, `360`, `qq`, `ios`, `android`, `random`, `randomized` (chrome is the default when unspecified). It applies to the VLESS client outbound's `tls` block (the VLESS outbound schema has `"tls": {}` → shared TLS). It operates at the ClientHello layer, so it **works over WS+TLS** — the WS transport is inside the TLS record stream, and uTLS only shapes the outer ClientHello (which is exactly what Netskope's SNI/ClientHello inspection sees). Caveat: sing-box's own docs say uTLS is "not recommended" (repeated fingerprinting vulnerabilities, light maintenance, browser stacks can't be perfectly copied) — acceptable for our use (defeating a category SNI filter, not adversarial DPI). Note uTLS only shapes the tunnel's outer TLS to `tun.glats.org`; traffic *inside* the tunnel egresses rog normally.

### R5 — Android import (exa: sing-box `clients/android` SFA, sub2sing-box parser, OpexDevelop converter)
The SagerNet **sing-box for Android (SFA)** app imports **both** a `vless://` share link (paste-from-clipboard or QR) **and** a full sing-box JSON config (import-from-file or remote subscription URL). VLESS link param names (from the `vless` parser + converter, standard v2rayN URI scheme) that sing-box understands: `encryption`, `security`, `sni`, `fp`, `flow`, `type`, `host`, `path`, `serviceName`, `alpn`, `allowInsecure`/`insecure`; the `#name` fragment becomes the profile name. For our WS+CDN shape the link is `type=ws&host=<WS Host header>&path=/<path>&security=tls&sni=tun.glats.org&fp=chrome`. Link gives the phone a working tunnel quickly (app-side per-app or full-VPN toggle); a full JSON gives deterministic full-tunnel + exclusions parity with mact2.

> **CORRECTION (2026-08-28, runtime-verified):** R5's SFA claim was **wrong**. Code search of `SagerNet/sing-box-for-android` shows **zero** `vless` share-link parsing — SFA only accepts (a) a Remote profile = `https` URL to a full sing-box config JSON, or (b) a Local profile = full config JSON via file/clipboard. Pasting/scanning a `vless://` link yields `not a valid sing-box remote profile URI`. The `vless://` link remains valid for v2rayNG/NekoBox/Hiddify-class clients. Fix shipped in `bin/tunnel-device-link --config` (full JSON for SFA Local-profile import, validated with `sing-box check`).

### R6 — Cover page (read `linux/system/services/web/nginx.nix`)
Static-root convention confirmed: `glats.org`/`localhost` vhosts use `root = "/srv/glats/nginx/html"; index = "index.html";` + `try_files $uri $uri/ =404;` (`repo.`/`maquiroot.` use their own roots). Path-routed proxies use `locations."/<path>" = { proxyPass = "http://127.0.0.1:<port>"; proxyWebsockets = true; };`. Cover-page approach: a `tun.glats.org` vhost with `useACMEHost = "glats.org"` + `forceSSL = true`, `root` (static believable site — reuse `/srv/glats/nginx/html` or a dedicated small root) for `/`, and one `locations."/<unguessable-path>"` proxying to the sing-box loopback WS port. Everything not matching the WS path serves the static page (no bare 404). Matches the existing `oai.glats.org` deny-then-proxy structure.

### R7 — `services.sing-box` `_secret` substitution shape (nixpkgs `nixos/lib/utils.nix` `genJqSecretsReplacement`, rev `4382ed2`)
`settings` is freeform JSON (`pkgs.formats.json`). The `ExecStartPre` runs `genJqSecretsReplacementSnippet cfg.settings`, which walks the whole settings tree (including arrays, via `[index]` prefixes) and replaces any attrset containing `_secret`. Two modes, both available: `{ _secret = "/path"; }` (default `quote = true` → file content embedded as a **JSON string**) or `{ _secret = "/path"; quote = false; }` (file content **`fromjson`-parsed** → arbitrary JSON object/array). So the **whole `users` array CAN be secret-substituted** (`users = { _secret = ".../users.json"; quote = false; }`) — but sops-nix decrypts YAML by default, and `fromjson` would choke on YAML. **Decision: per-UUID scalar substitution** (default string mode) — one sops YAML with N keys, each `uuid` field set to `{ _secret = <path>; }`, e.g. `users = [ { name = "mact2"; uuid = { _secret = …mact2_uuid.path; }; } { name = "phone"; uuid = { _secret = …phone_uuid.path; }; } ]`. This is the well-trodden string path, avoids the JSON-vs-YAML sops pitfall, and keeps each device's UUID independently revocable.

## Feasibility Verdict per New Requirement

| Requirement | Verdict | Notes |
|---|---|---|
| Full-tunnel default + exclusions | **FEASIBLE** | R2 route shape is first-class; `auto_detect_interface` + `default_domain_resolver` (1.12+) cover the macOS loop/DNS-recursion pitfalls. Gate = in-building coexistence. |
| Scoped-mode config flip | **FEASIBLE** | Same TUN, swap `final`/rules. Can be a Nix option (`mode = "full" | "scoped"`) or two config variants. |
| N UUIDs on one inbound | **FEASIBLE** | R1 `users` array; R7 per-UUID `_secret` files scale to N. |
| Phone share link / import | **FEASIBLE** | R5 link (params verified) or full JSON. |
| uTLS chrome fingerprint | **FEASIBLE** | R4 outbound `utls`; applies to tunnel ClientHello; works over WS+TLS. Minor doc caveat (not "recommended"). |
| nginx cover page + unguessable path | **FEASIBLE** | R6 reuses existing static-root + path-proxy conventions. |
| process-based EDR exclusion | **FEASIBLE (best-effort)** | R3 macOS-standalone only; undocumented PCB format = fragile; back with IP/domain rules. |

## Updated Architecture Sketch

**Server (rog — unchanged + multi-user + cover page):** `services.sing-box` with a loopback VLESS+WS inbound, `users` = N entries (per-UUID `_secret`), `transport.path` = unguessable value; nginx `tun.glats.org` vhost: static cover page at `/`, WS path-proxy location to the sing-box port. `direct` outbound.

**Client (mact2 — full-tunnel default):** root launchd daemon → `sing-box run`. TUN inbound `{ auto_route: true, strict_route: true, stack: system, sniff: true }`. `route.rules` (ordered): sniff → hijack-dns → `ip_is_private → direct` → corporate/EDR `ip_cidr`+`rule_set` → direct → `process_name [falcon*, nsproxy*, forticlient*] → direct` → corporate/EDR `domain_suffix → direct` → `final: tunnel`. `route.auto_detect_interface = true`; `route.default_domain_resolver = <direct resolver>`. Outbounds: `tunnel` (vless + `tls.enabled` + `server_name: tun.glats.org` + `utls.chrome` + `transport.ws {path, host}`), `direct`, `block`. Scoped flip: `final: direct` + `domain_suffix [chatgpt.com, auth.openai.com, oaistatic.com, openai.com] → tunnel`.

**Secret shape (R7 decision):** one sops YAML `secrets/shared/opencode-tunnel.yaml` with keys `mact2_uuid`, `phone_uuid`, … (N), each declared as its own `sops.secrets."opencode-tunnel/<name>"` with `key = "<name>"` → N scalar files; `users[].uuid = { _secret = path; }`.

**Android share-link template (parameters only, no real UUID):**
`vless://<UUID>@tun.glats.org:443?encryption=none&security=tls&sni=tun.glats.org&fp=chrome&type=ws&host=tun.glats.org&path=/<unguessable-path>#mact2-tunnel-phone`

## Risks Specific to the Pivot

1. **FortiClient route conflict (NEW):** if the corporate VPN (FortiClient) is present on mact2, its NetworkExtension + routes compete with sing-box TUN's `auto_route` default-route claim. sing-box TUN is a raw `utun` (not a NetworkExtension) and `route_exclude_address`/`auto_detect_interface` are the levers, but the actual stacking order with FortiClient + Netskope AppProxy + CrowdStrike is **in-building-only-verifiable**. Full-tunnel makes this conflict more likely than the scoped design.
2. **EDR/management traffic must stay direct (NEW, load-bearing):** Netskope mgmt, CrowdStrike Falcon cloud, and FortiClient mgmt MUST be excluded (process_name + IP/domain rules). If a tunnel outage silently takes EDR heartbeats with it, the endpoint may be flagged/quarantined by corporate policy. This inverts the scoped design's "only OpenAI is tunneled" safety property.
3. **Traffic-shape anomaly (NEW):** full-tunnel concentrates ALL mact2 traffic into one long-lived TLS/WS flow to a Cloudflare IP from rog's residential egress — a visible volume/behavior change vs. the scoped design. Netskope telemetry may flag the shift; rog's uplink becomes mact2's bandwidth ceiling.
4. **macOS process-search fragility (R3):** undocumented, version-dependent PCB format on macOS 26.6 → process_name rules may silently fail after OS updates; keep IP/domain exclusions as the authoritative gate.
5. **uTLS maintenance caveat (R4):** sing-box docs deprecate uTLS for robustness; acceptable for category-filter evasion, but pin expectations.

## Updated Evidence Gates

### (a) Validatable from home (post-implementation)
- [ ] `opencode run -m openai/gpt-5.4 "PONG"` succeeds from mact2 with full-tunnel active (default route = tunnel).
- [ ] Full-tunnel active while **FortiClient is disconnected/unloaded** — proves sing-box TUN owns the default route independently of the corporate VPN.
- [ ] Scoped-mode flip works: flip to scoped → only OpenAI domains traverse the tunnel; everything else direct.
- [ ] Phone imports the `vless://` link (or JSON) and connects; the `phone` UUID authenticates on the multi-user inbound; OpenAI reachable from the phone.

### (b) Only validatable in-building
- [ ] **Corporate exclusions verified**: Netskope/CrowdStrike/FortiClient management endpoints reachable directly (not via tunnel); `process_name` rules match the EDR binaries on the running macOS build.
- [ ] sing-box TUN coexists with Netskope AppProxy + CrowdStrike Falcon **and FortiClient** (no route loop, no default-route fight).
- [ ] CrowdStrike EDR does not flag/block the root sing-box TUN daemon.
- [ ] Cover page serves on non-tunnel paths; only the unguessable WS path proxies to sing-box.
