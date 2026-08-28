# Exploration: mact2 OpenAI OAuth via rog

Feasibility study only. No Nix/config changes, no secret decryption, no build/switch, no commits.

## Current State

`mact2` (macOS, user jcuzmar) sits behind Falabella corporate TLS-MITM. Direct HTTPS to OpenAI is intercepted — reproduced this session as `curl https://api.openai.com/v1/models` → `self-signed certificate in certificate chain` (corporate proxy). The 2026-08-25 preflight (`openspec/changes/repair-mact2-native-openai-egress/preflight-evidence.md`) pinned the block as network policy (`GL_FTC_Generative_IA_C3_BLOCK`, user `jcuzmar@Falabella.cl`), not an OAuth failure.

Current wiring on master/HEAD (`008f68c`, branch `feature/repair-mact2-native-openai-egress-preflight`):
- `hosts/mact2/default.nix` still selects `activeProviderName = "openai-medium-proxy"` (the broken gateway).
- `linux/system/services/web/opencode-proxy.nix` (Python gateway, forwards `nvapi-` key to `api.openai.com` → 401) is still imported and `services.opencodeProxy.enable = true` on rog; `oai.glats.org` vhost still in nginx.
- WireGuard server infra on rog exists and is live (`wireguard.nix`): `wg0` 10.13.13.1, endpoint `guard.glats.org:51820` UDP, peer `mac` = 10.13.13.3 (publicKey pinned, PSK in sops), `networking.nat` for `10.13.13.0/24`, client conf auto-generated at `/etc/wireguard/clients/mac.conf` (exists, mode 600). `darwin/home/packages.nix` ships `wireguard-go` + `wireguard-tools` for mact2.
- `bin/install-opencode-auth-seed` exists on rog AND is already installed on mact2 (`/Users/jcuzmar/bin/`, 8241 bytes, Aug 24). `bin/publish-opencode-auth-seed` is MISSING.
- The reverted transport-proxy (tinyproxy 10.13.13.1:3128 + HTTP(S)_PROXY in mact2 zsh) lives on branch `revert/mact2-transport-proxy`, reverted in `7b8c6eb` for two judge-confirmed flaws: shell-wide proxy env leaking into MCP children, and unproven mact2→rog transport.
- OpenCode binary is pinned to `anomalyco/opencode` v1.18.18 in `pkgs/opencode/default.nix`.

## Research Findings (MCP-verified)

### R1 — OpenCode proxy env + MCP child inheritance
OpenCode reads `HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY`/`NO_PROXY` in `packages/opencode/src/util/proxy-env.ts` (`getProxyForUrl`, wildcard + port-aware `NO_PROXY`). MCP local servers are spawned with the FULL parent env: `packages/opencode/src/mcp/index.ts` uses `env: { ...process.env, ...(cmd==="opencode" ? {BUN_BE_BUN:"1"} : {}), ...mcp.environment }`. Two consequences, both doc-backed:
1. **There is NO built-in scrub option** for MCP children — any `HTTP(S)_PROXY` set in the OpenCode process propagates to every MCP child via `...process.env`. This is exactly the reverted-design flaw (b), now confirmed at source level.
2. `mcp.environment` is spread **last**, so it *can* override (but not delete) inherited keys. Setting `mcp.environment.HTTPS_PROXY = ""` yields an empty string, which `proxy-env.ts` treats as falsy → "no proxy". This is the only declarative lever to re-scope a leaked proxy per-MCP, and it requires enumerating every MCP.

Source: context7 `/anomalyco/opencode` (network.mdx + mcp/index.ts + util/proxy-env.ts).

### R2 — ChatGPT OAuth endpoints (authoritative at v1.18.18)
Fetched `packages/opencode/src/plugin/openai/codex.ts` at tag `v1.18.18` (the installed version). Constants:
- `ISSUER = "https://auth.openai.com"`, `CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"`
- `CODEX_API_ENDPOINT = "https://chatgpt.com/backend-api/codex/responses"`
- Token refresh: `POST https://auth.openai.com/oauth/token` (`grant_type=refresh_token`)
- Browser login: PKCE + localhost:1455 callback; headless: `auth.openai.com/api/accounts/deviceauth/{usercode,token}` + `/codex/device`
- The provider fetch override rewrites any `/v1/responses` or `/chat/completions` path to `CODEX_API_ENDPOINT`.

**CONTRADICTION FLAGGED**: the preflight evidence recorded the block at `https://api.openai.com/v1/responses`, but the v1.18.18 source routes model calls to `chatgpt.com/backend-api/codex/responses` and refresh to `auth.openai.com`. `api.openai.com` appears only in JWT claim namespaces, not as a fetch target. The preflight's reported URL is therefore either a corporate block-page normalization or a stale code path. **The transport allowlist must be built from the two hosts `chatgpt.com` + `auth.openai.com` (both Cloudflare-fronted CDN hosts), not `api.openai.com`.** This directly corrects assumption in the launch brief.

### R3 — per-provider baseURL override (does it help?)
Provider config `options.baseURL` / `options.endpoint` (endpoint wins) applies ONLY to custom providers declared with `npm: "@ai-sdk/openai-compatible"` (`packages/opencode/src/provider/provider.ts`; providers.mdx). The built-in `openai` provider's endpoints are **hardcoded constants** in the codex plugin; there is no `opencode.json` option to redirect them. A TS plugin option `CodexAuthPluginOptions { issuer, codexApiEndpoint }` exists but requires authoring a custom plugin, not config. **Conclusion: option (d) "local relay + per-provider baseURL" is NOT viable for the built-in `openai` provider.** It is only reachable via a custom `openai-compatible` provider — i.e., the forbidden `openai-proxy` gateway architecture. This independently confirms the preflight's "no MCP-safe narrow mechanism in OpenCode's documented options" verdict.

### R4 — macOS app-scoped proxying (prior art)
No native per-app proxy. Realistic levers: wrapper script (`export HTTPS_PROXY=…; exec opencode`) — scopes to the CLI but children inherit; `launchctl setenv` — sets launchd/GUI env, ignored by Electron apps (openai/codex#34955) and not reliably inherited by terminal-spawned opencode; pf anchor redirect (trans_proxy / linko) — transparent but system-wide, requires root, affects all traffic (violates requirement 6); Proxifier-style per-process tools (ProxyBridge) — third-party, not Nix-managed. Source: exa (trans_proxy README; openai/codex#34955; maccdn LaunchAgent guidance).

### R5 — Bun runtime proxy env
OpenCode runs on Bun. Bun's native `fetch()` honors `HTTP_PROXY`/`HTTPS_PROXY`/`NO_PROXY` automatically (bun.com/docs/guides/http/proxy). OpenCode's WebSocket path additionally resolves proxy explicitly (`ws.ts` uses `ProxyEnv.getProxyForUrl`). So setting proxy env in the OpenCode process routes both its HTTP fetch and WebSocket through the proxy. Caveat: Bun-based MCP children would honor the same env; Node-based MCPs (github-mcp-server etc.) use Node `fetch`, which does **not** auto-honor proxy env by default — the leak is real but runtime-inconsistent.

## Probe Results (sanitized, read-only)

Host: `rog` (current shell). SSH to mact2 as `glats@` failed (publickey); `jcuzmar@mact2.local` works.

| # | Probe | Result |
|---|---|---|
| P1a | `curl https://api.openai.com/v1/models` (mact2) | **BLOCKED** — `self-signed certificate in certificate chain` (corporate MITM), HTTP 000 |
| P1b | `dig +short guard.glats.org` (mact2) | `201.188.187.112` — rog's **public IP directly**, NOT Cloudflare-fronted |
| P1c | `nc -vz -u guard.glats.org 51820` (mact2) | `succeeded` — **weak evidence** (UDP "connect" = packet sent, not handshake) |
| P1d | `wg show` (mact2) | empty — no active tunnel |
| P1e | `~/Library/Application Support/WireGuard/` | absent |
| P1f | `scutil --nc list` | FortiClient VPN (corporate) present but **Disconnected** |
| P1g | utun carrying 10.13.13.x | none |
| P2a | `env \| grep -i proxy` (mact2) | clean |
| P2b | `auth.json` keys (mact2) | `["anthropic","github-copilot","openai","opencode-go"]` — **`openai` OAuth entry already present** |
| P2c | `~/bin/install-opencode-auth-seed` | present (8241B, Aug 24) |
| P2d | `opencode --version` (mact2) | **1.18.18** (matches `pkgs/opencode/default.nix`) |
| P3a | `/etc/wireguard/clients/mac.conf` (rog) | exists, mode 600 |
| P3b | `wg show wg0` (rog) | server up. **`mac` peer (9MFat…=10.13.13.3): no endpoint, no handshake, no transfer — never connected.** Other peers (thinkphone 10.13.13.6) handshaked 3h ago via NAT endpoint `172.16.0.1:1024` |
| P3c | `systemctl is-active tinyproxy` | inactive (absent) |
| P3d | `opencode-proxy` / `nginx` | active / active (old gateway still running) |

Key probe takeaways: (1) `guard.glats.org` is a **grey-cloud** A record → WireGuard endpoint is directly reachable, not behind Cloudflare (good — Cloudflare can't proxy UDP anyway). (2) The `mac` WG peer has **never** handshaken, confirming the transport is unproven at runtime; the thinkphone peer proves *some* NAT'd client can reach WG, but not that mact2 can. (3) mact2 already holds an `openai` OAuth credential, so bootstrap is a re-validate/rotate concern, not a first-time concern.

## Feasibility Verdict per Component

### F-Auth — bootstrap seed via nginx uploads + Nix installer: FEASIBLE (prior art proven, re-validate)
The pipeline was proven end-to-end 2026-08-24. Installer is live on both hosts and mact2's `auth.json` already contains the `openai` entry. Gaps to close in design: (a) `bin/publish-opencode-auth-seed` does not exist yet; (b) the installer's jq merge is "existing wins" — the prior design requires the `openai` entry to **overwrite** on merge, which the current script does not do; (c) the seed is a one-shot fallback — concurrent use with rog's copied credential triggers single-use refresh-token rotation (first refresh invalidates the other). Preferred bootstrap stays independent headless login through the transport path.

### F-Transport — mact2→rog path: CONDITIONALLY FEASIBLE
Ranked candidates:
1. **WireGuard split-tunnel + rog NAT (primary).** Mechanism: mact2 runs WG client (tools already packaged); `AllowedIPs` restricted to OpenAI host IPs + 10.13.13.0/24; rog NATs `10.13.13.0/24` (already enabled). MCPs and all other traffic keep the default corporate route by construction — no env vars, no credential in path, no public listener. **Breaks MCPs:** no. **Exposure:** none (private authenticated tunnel). **Effort:** Medium-High — requires a DNS→IP updater to keep `AllowedIPs` current because `chatgpt.com`/`auth.openai.com` are Cloudflare CDN with rotating IPs.
2. **TCP-tunneled WG fallback (wstunnel/udp2raw on rog).** Needed only if UDP 51820 egress is blocked. New service on rog; preserves split-tunnel semantics. **Effort:** High (new service + client). **Exposure:** low if auth'd.
3. **WG-bound HTTPS CONNECT proxy (tinyproxy 10.13.13.1, the reverted design).** Handles CDN rotation naturally (CONNECT is hostname-resolved on rog). **Breaks MCPs:** risk — proxy env leaks to MCP children (R1); mitigation is per-MCP `mcp.environment` empty-override or `NO_PROXY` enumeration, both fragile. **Exposure:** none (WG-only bind). **Effort:** Medium.
4. **Local relay + per-provider baseURL.** **ELIMINATED** by R3 (hardcoded endpoint; only reachable via forbidden openai-proxy gateway architecture).

Public CONNECT (option c in brief) carries the extra Cloudflare-CONNECT caveat (free tier doesn't proxy raw CONNECT; needs grey-cloud subdomain) plus public-open-proxy risk — deprioritized versus WG-bound proxy.

### F-Scope — OpenAI traffic proxied, MCP children clean: FEASIBLE (mechanism-dependent)
- **IP split-tunnel (transport #1): MCP-safe by construction** — no env variable, MCPs never see the tunnel. Cleanest for requirement 6.
- **Proxy env (transport #3): requires explicit MCP scrub** (R1/R5). The `...process.env` inheritance guarantees the leak unless every MCP is overridden. The preflight threat matrix already forbids shell-wide proxy exports; only a scoped wrapper + per-MCP scrub would qualify, and that scrub is fragile.

### F-Lifecycle — token refresh offline/direct-blocked: CONDITIONALLY FEASIBLE
Refresh is lazy, single-flight, before each request (`codex.ts` fetch override), hitting `auth.openai.com/oauth/token`. If refresh fails (revoked/expired), the request fails with "Token refresh failed: {status}" and there is **no automatic recovery** — the user must re-login. Refresh tokens are single-use (rotation), so a seed shared with rog creates contention: whichever host refreshes first invalidates the other's refresh token. Behind the proxy, refresh must also traverse `auth.openai.com` — so the transport allowlist MUST include `auth.openai.com` or sessions die silently ~1h after login. **Who refreshes:** the OpenCode client on mact2 does, in-process; rog is not involved after bootstrap.

## Overall Verdict

**CONDITIONALLY FEASIBLE.** The architecture is sound and mostly pre-built (WG server + NAT live, auth pipeline proven, OpenCode native proxy/OAuth support doc-backed). Two unknowns gate the whole design; neither is resolved by this exploration.

**Highest-risk unknown:** does `mact2` have usable UDP 51820 egress to `guard.glats.org`, and can hostname-scoped (`chatgpt.com` + `auth.openai.com`) routing survive Cloudflare IP rotation without a forward proxy? Evidence today is only suggestive: grey-cloud DNS resolves to rog's real IP, `nc -u` "succeeded" (weak), and a sibling WG peer on a NAT'd `172.16.0.0/24` endpoint handshakes successfully — but the `mac` peer has **never** connected.

## Recommended Approach
1. Prove WireGuard first: import `mac.conf` on mact2, establish handshake, verify `chatgpt.com`/`auth.openai.com` reachability through the tunnel with split `AllowedIPs`.
2. If IP-split proves unreliable against CDN rotation, fall back to the WG-bound tinyproxy (transport #3) with a scoped wrapper + declarative per-MCP `mcp.environment` scrub, re-validating the MCP-clean check (`ps eww` grep) the preflight already defined.
3. Retire the old gateway (`opencode-proxy.nix`, `oai.glats.org`, `openai-*-proxy` tiers, `OPENAI_PROXY_API_KEY`) in the same change; add `bin/publish-opencode-auth-seed`; fix installer merge to overwrite `openai`.
4. Bootstrap via independent headless login on mact2 through the proven transport; keep the seed as one-shot fallback only.

## Evidence Gates (design phase MUST satisfy)
- [ ] `wg show` on mact2 shows a handshake with rog and `10.13.13.3` assigned.
- [ ] A request to `chatgpt.com/backend-api/codex/responses` AND `auth.openai.com/oauth/token` succeeds from mact2 through the chosen transport.
- [ ] `ps eww -p <mcp-pid> | grep -i proxy` returns nothing for every MCP child (MCP-clean proof).
- [ ] No `HTTP(S)_PROXY` in any shell profile / `extraInitContent`; proxy env (if any) confined to a wrapper + scrubbed per-MCP.
- [ ] `api.openai.com` never appears in the transport allowlist (corrected per R2).
- [ ] No `sk-` key, no `OPENAI_PROXY_API_KEY`, no `oai.glats.org` remain after apply.

## Citation Quality
- **Doc-backed (source-level):** R1 (proxy-env.ts, mcp/index.ts via context7 + GitHub code search), R2 (codex.ts at v1.18.18 tag, raw fetch), R3 (provider.ts, providers.mdx), R5 (bun.com proxy guide). High confidence.
- **Assumption/unproven:** UDP 51820 egress from mact2 (weak nc signal only); Cloudflare CDN IP rotation cadence; whether corporate DNS returns real `chatgpt.com` IPs for split-tunnel resolution.
- **Runtime-observed:** api.openai.com MITM (SSL self-signed), guard.glats.org → rog public IP, `mac` peer never handshaken, old gateway active, `openai` auth present on mact2, opencode 1.18.18.

---

# Addendum — 2026-08-25 evening: decisive probes invalidate transport ranking

## Context update
User disclosed formal authorization context (DevSecOps role; findings to be published under responsible disclosure — coordinate timing with the control owner before publishing internals).

## New runtime evidence (read-only probes)

| # | Probe | Result | Meaning |
|---|---|---|---|
| A1 | `openssl s_client -connect <rog-ip>:443 -servername chatgpt.com` (mact2, in-building) | Cert subject `CN=chatgpt.com`, issuer **Falabella/Netskope CA** (`ca.grupofalabella.goskope.com`) | Interception happens **by SNI value regardless of destination IP** — connection never reaches rog |
| A2 | Same with `-servername auth.openai.com` / `api.openai.com` | Same Netskope-signed certs | Whole OpenAI namespace hijacked at ClientHello |
| A3 | Same with `-servername guard.glats.org` | Issuer **Let's Encrypt (legit)** — rog's real cert | Personal/uncategorized domains pass through **uninspected** |
| A4 | `nc -z <rog-ip> 443` without TLS | CLOSED/filtered | Non-TLS or SNI-less flows dropped |
| A5 | `nc -z guard.glats.org 22` | filtered | Direct SSH not available publicly |
| A6 | Local agent inventory | **NetskopeClientMacAppProxy systemextension running** (+ FortiClient VPN, disconnected) | Filtering enforced by a LOCAL transparent-proxy agent, not only gateway-side |

**User-reported ground truth:** WireGuard works from other networks but is blocked when physically inside the Falabella building (corporate firewall kills WG/UDP 51820). Resolves exploration unknown #1 → answer is NO from the office.

## Consequences for the transport ranking (supersedes F-Transport above)

- **Rank 1 (WG split-tunnel) — DEAD from the office.** UDP egress blocked by policy. Still valid off-site.
- **Hosts-file / SNI-transparent forwarder — DEAD everywhere in-building** (new option surfaced by A1): even pointing `chatgpt.com` at rog's own IP yields a Netskope MITM handshake. SNI-value filtering defeats destination-based tricks.
- **Only surviving family: outer TLS must carry an ALLOWED SNI (`*.glats.org`) with arbitrary payload inside.** This is the standard GFW-evasion playbook; community prior art is mature (researched 2026-08-25):
  - Dominant China pattern for API access = reverse proxy on own reachable domain (CF Worker/nginx with `proxy_ssl_server_name on`).
  - For OAuth-session CLIs hitting `chatgpt.com/backend-api`, Cloudflare JA3/JA4 fingerprint challenges exist against datacenter exits (zooclaw.ai write-up) — LOW risk here: rog's residential exit already serves Bun/OpenCode traffic today.
  - VLESS+WS+TLS behind nginx path (cover-path pattern) is the battle-tested server shape; REALITY unnecessary (Netskope is category-filtering, not adversarial DPI).
  - Client side: sing-box / Clash-style rule engine with TUN mode gives per-domain split (fake-ip DNS + SNI sniffing); documented macOS coexistence patterns with corporate VPNs/agents exist (SagerNet/sing-box#3586: `route_exclude_address`, `bind_interface`).

## Pivoted architecture (primary candidate)

```
OpenCode/mact2 ─► sing-box TUN (rules: chatgpt.com, auth.openai.com ► tunnel-out;
                   everything else ► direct)          ← MCP-safe BY CONSTRUCTION (L3, no env vars)
      tunnel-out = VLESS+WS+TLS ► tun.glats.org/<path> (nginx :443 on rog, existing cert)
                                        └► 127.0.0.1 xray/sing-box inbound ► freedom ► internet
Bootstrap unchanged: age-seed via glats.org/uploads + bin/install-opencode-auth-seed.
```

Server fits repo conventions: NixOS module (`services.xray` or `services.sing-box`) + one nginx location; UUID/keys in sops. Client fits nix-darwin home-manager declaratively (config JSON + launchd). Generalizes later: more domains = more rule lines; full-tunnel = flip `final` outbound.

## Revised verdict

**CONDITIONALLY FEASIBLE — architecture pivoted to single-URL TLS tunnel.** Auth bootstrap unchanged (FEASIBLE). Scope isolation now solved at L3 by design instead of by fragile env scrubbing.

**New highest-risk unknown:** sing-box TUN ↔ Netskope local AppProxy agent coexistence on managed macOS (both capture traffic; stacking order/rules unknown until tested live).

## Revised evidence gates (design MUST satisfy)
- [ ] Coexistence probe: with sing-box active, Netskope still functions; no route loop; corporate apps unaffected.
- [ ] From mact2 in-building: request through tunnel to `chatgpt.com/backend-api/codex/responses` AND `auth.openai.com/oauth/token` succeeds (outer SNI observed = glats.org only).
- [ ] Domain-rule proof: non-rule domains (e.g. github.com) show DIRECT path + clean MCP child envs (`ps eww` check from preflight).
- [ ] No `HTTP(S)_PROXY` anywhere in shell profiles; no API keys; old gateway fully retired (`opencode-proxy.nix`, `oai.glats.org`, `-proxy` tiers gone).
- [ ] Tunnel creds (uuid/tls) sourced from sops; teardown = revert of declarative config only.
