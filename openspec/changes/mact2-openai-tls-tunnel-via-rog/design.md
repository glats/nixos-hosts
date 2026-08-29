# Design: mact2 OpenAI TLS tunnel via rog

## Technical Approach

`rog` terminates TLS for `tun.glats.org` and proxies one random, fixed WebSocket path to a loopback multi-user VLESS inbound. A root `mact2` LaunchDaemon owns a sing-box TUN. Its default is full tunnel; private, corporate, and EDR-management traffic is explicitly direct. No proxy environment variables are used.

```
mact2 TUN ──VLESS+WS+TLS/uTLS──> tun.glats.org nginx ──> rog sing-box ──> Internet
    │ direct rules first                         static cover page at all other paths
    └─ private / corporate / EDR management
```

## Architecture Decisions

| Decision | Choice and rationale |
|---|---|
| Routing interface | `darwin/system/sing-box-tunnel.nix` defines `tunnel.mode = "full" | "scoped"` (default `full`), plus mutable `tunnel.directDomains` and `tunnel.directCidrs` lists. Full emits `ip_is_private → direct`, then those CIDR/domain rules → `direct`, then `final = "tunnel-out"`; scoped emits only `chatgpt.com` and `auth.openai.com` → `tunnel-out`, then `final = "direct"`. This is a declarative, reversible flip without code edits. |
| Loop prevention | `route.auto_detect_interface = true` and `route.default_domain_resolver = "direct-dns"` are required-for-boot settings, not optional hardening. `direct-dns` is a resolver explicitly detoured to `direct`; they keep the tunnel endpoint lookup and its TCP connection out of the TUN. |
| Direct safety | IP/domain lists are the authoritative EDR/corporate bypass. `process_name` rules for known Netskope, Falcon, and FortiClient executables are best-effort only: supported by this root macOS-standalone binary, but macOS process discovery is fragile. |
| Device credentials | `secrets/shared/opencode-tunnel.yaml` holds scalar `uuid_mact2` and `uuid_phone` keys. Each host declares `sops.secrets."opencode-tunnel/uuid_*"` with that `sopsFile`, `key`, owner, and `0400` mode; the server’s VLESS `users` array uses one `_secret` UUID per device. Removing a key, declaration, and users entry then rebuilding revokes only that device. A specific `.sops.yaml` rule for this path precedes `secrets/shared/.+` and encrypts only for admin, rog, and mact2. |
| Public disguise | The WS path is one generated-once random hex constant, committed as configuration rather than sops: it is obscurity, not authentication. nginx gives that exact path `proxyWebsockets = true`; `/` uses the existing `root`/`index`/`try_files` static-page pattern, so non-WS paths serve a believable cover page rather than 404. |

## Interfaces / Contracts

```nix
tunnel = {
  mode = "full"; # enum: full | scoped
  directDomains = [ /* corporate, Netskope, Falcon, FortiClient endpoints */ ];
  directCidrs = [ /* corporate and management networks */ ];
};
```

The Darwin rendered configuration includes `auto_route`, `strict_route`, `stack = "system"`, `sniff = true`, a `direct-dns` server, and:

```json
{"tls":{"enabled":true,"server_name":"tun.glats.org","utls":{"enabled":true,"fingerprint":"chrome"}},"route":{"auto_detect_interface":true,"default_domain_resolver":"direct-dns","final":"tunnel-out"}}
```

The VLESS outbound tag is `tunnel-out`; server users are `{ name = "mact2"; uuid = { _secret = ...uuid_mact2.path; }; }` and `phone` likewise. The Android deliverable is `bin/tunnel-device-link`, which reads the rendered phone UUID at runtime and prints, never stores, `vless://<UUID>@tun.glats.org:443?encryption=none&security=tls&sni=tun.glats.org&fp=chrome&type=ws&host=tun.glats.org&path=/<path>#mact2-tunnel-phone`.

## File Changes

| File | Action | Description |
|---|---|---|
| `linux/system/services/network/sing-box-tunnel.nix` | Create | Loopback VLESS server, scalar-secret users, direct outbound. |
| `darwin/system/sing-box-tunnel.nix` | Create | `tunnel` options, root sops template, and root LaunchDaemon. |
| `bin/tunnel-device-link` | Create | Runtime-only Android link printer. |
| `secrets/shared/opencode-tunnel.yaml` | Create | Encrypted per-device UUID scalars. |
| `hosts/rog/default.nix`, `hosts/mact2/default.nix`, `hosts/rog/secrets.nix`, `.sops.yaml`, `linux/system/services/web/nginx.nix` | Modify | Flat imports, secret declarations/rule, cover-page vhost and WS proxy. |
| `shared/opencode.nix`, `shared/opencode/providers-base.nix`, `darwin/home/sops.nix` | Modify in Phase 3 | Native tier and proxy credential/export removal. |
| `linux/system/services/web/opencode-proxy.nix`, `secrets/host/rog/openai-proxy.yaml` | Delete in Phase 3 | Retire only after all gates. |

## Testing Strategy and Rollout

| Phase | Delivery and required verification |
|---|---|
| 1: transport | Add server, cover page, UUIDs, daemon, and link script; run `format-nix && nix flake check --no-build` and `sing-box check -c <rendered-config>`. Immediately after client start, resolve `tun.glats.org` and request a configured `tunnel.directDomains` endpoint; logs must show the latter direct. Confirm full default traffic uses `tunnel-out`, exclusions use `direct`, cover page works, and phone imports the generated link. Remove `uuid_phone`, rebuild, and prove mact2 remains connected while phone is denied; restore it. |
| 2: auth | Select native `openai-*`, complete device flow, prove PONG and refresh, and confirm MCP children have no `HTTP(S)_PROXY`. At the office, prove Cloudflare TLS/WS with outer SNI `tun.glats.org`, FortiClient/Netskope/Falcon coexistence, and EDR/Netskope management traffic stays direct during tunnel operation. |
| 3: retirement | Only after every home and office gate passes, remove gateway configuration/secrets and rerun `format-nix && nix flake check --no-build`. Rollback before then unloads the daemon and reverts declarative changes; after retirement, revert Phase 3. |

## Threat Matrix

| Boundary | Applicability | Design response / RED tests |
|---|---|---|
| Documentation-like paths | N/A — no executable classification. | None. |
| Git repository selection | N/A — no VCS automation. | None. |
| Commit state | N/A — no commit automation. | None. |
| Push state | N/A — no push automation. | None. |
| PR commands | N/A — no PR automation. | None. |

## Open Questions

- [ ] Office-only agent/VPN coexistence and Cloudflare WS policy remain acceptance gates, not assumptions.

## Addendum — 2026-08-29: loopback mixed inbound (steering escape hatch)

**Rationale.** The home evidence run (FAIL #2 in `home-evidence.md`, TLS-through-tunnel cert stealth) proved Netskope's local AppProxy intercepts OpenAI-bound flows at socket level BEFORE they reach the TUN: with the tunnel up, `auth.openai.com` still presented the `ca.grupofalabella.goskope.com` issuer instead of the origin cert, because Netskope steering matches the SNI of outbound connections. A loopback mixed (HTTP CONNECT + SOCKS) inbound sidesteps steering: a CONNECT/SOCKS request to `127.0.0.1` carries no SNI for Netskope to match, so the flow is not intercepted; sing-box unwraps it and the payload rides the tunnel with outer SNI `tun.glats.org` only.

**Chosen port/tag.** `type = "mixed"`, `tag = "mixed-in"`, `listen = "127.0.0.1"`, `listen_port = 2080` — loopback-only, added to `darwin/system/sing-box-tunnel.nix` alongside the TUN inbound. No inbound-specific route rules.

**Semantics in both modes.** Traffic from `mixed-in` flows through the same route rules + final as TUN traffic: in `full` mode it hits the `auto` urltest group (tunnel-out while rog is alive, direct fallback otherwise); in `scoped` mode the CONNECT/SOCKS request target is a hostname, so the `chatgpt.com`/`auth.openai.com` `domain_suffix` rules match without sniffing and everything else goes direct.

**What it enables.** Browser OAuth on `auth.openai.com` via manual proxy settings (`http://127.0.0.1:2080`) and a scoped `HTTPS_PROXY` for the opencode runtime on mact2 — both bypassing Netskope pre-TUN interception. Spec amendment (formal `HTTPS_PROXY` wiring for opencode) is deferred to PR2; this addendum records only the transport escape hatch.

### PAC generator (system-level steering bypass)

**Rationale.** The mixed inbound is only an escape hatch if clients actually use it. Netskope steering intercepts at socket level pre-TUN, so the macOS SYSTEM proxy must be told to send steered domains through the loopback proxy explicitly; a Proxy Auto-Config (PAC) scoped to a declarative domain list keeps everything else DIRECT and grows the same way the tunnel bypass lists do.

**Options.** `tunnel.pacDomains` (default `["openai.com" "chatgpt.com" "oaistatic.com" "oaiusercontent.com"]`) — domains the system proxy routes to the loopback mixed inbound; users append steered domains here as they discover them, takes effect on rebuild. `tunnel.pacNetworkServices` (default `["Wi-Fi"]`) — networksetup service names whose system proxy gets pointed at the PAC.

**Generation and deployment.** The module renders the PAC with `pkgs.writeText` (domain list embedded as a JSON array via `builtins.toJSON`) and exposes it at `/etc/tunnel.pac` through `environment.etc`, regenerated on every rebuild. Activation (`system.activationScripts.extraActivation.text`, option name verified against the pinned nix-darwin-26.05 rev) runs `/usr/bin/networksetup -setautoproxyurl <svc> "file:///etc/tunnel.pac" || true` for each service in `pacNetworkServices`, only when `pacDomains` is non-empty; `|| true` keeps activation green when a service is absent. WPAD/autodiscovery is deliberately untouched.

**Fallback semantics.** The PAC returns `"PROXY 127.0.0.1:2080; DIRECT"` for matched domains: if the sing-box daemon is down, steered domains degrade to the corporate path (Netskope block page) instead of hanging.

**Per-host overrides.** Follow the `hosts/mact2/default.nix` `tunnel.directCidrs` pattern (e.g. `tunnel.pacDomains = [ ... ];`).
