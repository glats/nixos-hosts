# Proposal: mact2 OpenAI TLS tunnel via rog

## Intent

Provide stealth-hardened, authenticated VLESS transport for `mact2` OpenAI and general traffic, plus independently revocable Android access. Affects `rog`, `mact2`, and Android.

## Scope

### In Scope
- Server and `mact2` full-tunnel default, with RFC1918/ULA, corporate, and EDR/Netskope-management traffic direct; scoped OpenAI-only mode is a config flip.
- Two sops UUIDs (`mact2`, Android), multi-user inbound, Android `vless://` link, uTLS Chrome, unguessable WS path, and cover page.
- Native `openai-*` auth; retire the old gateway only after home and office proof.

### Out of Scope
- Clients on `t14`/`thinkcentre`; full tunnel on other hosts; WireGuard; REALITY; and Android configuration beyond the share link.

## Capabilities

### New Capabilities
- `mact2-openai-tls-tunnel`: Multi-device VLESS+WS+TLS transport with full-tunnel `mact2` routing and exclusions.
- `mact2-openai-native-auth`: Device flow and native tier.
- `tunnel-device-onboarding`: Per-device UUID lifecycle and Android share-link delivery.

### Modified Capabilities
- `opencode-runtime-proxy`: Retire the broken gateway and proxy tiers after proof.

## Approach

Use the addendum architecture: scalar keys in `secrets/shared/opencode-tunnel.yaml` populate VLESS `users`. nginx proxies only the matching unguessable WS path and otherwise serves a cover page. `mact2` defaults to `final: tunnel`; ordered direct exclusions are `ip_is_private`, corporate/EDR IP/domain, then best-effort `process_name`. `auto_detect_interface` and direct `default_domain_resolver` are mandatory against self-loops. uTLS is Chrome; scoped mode swaps in direct-final OpenAI routing.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `linux/system/services/network/`, `hosts/rog/default.nix` | New/Modified | Multi-user server. |
| `linux/system/services/web/nginx.nix` | Modified | Cover-page vhost, WS proxy, gated `oai` removal. |
| `hosts/rog/secrets.nix`, `darwin/home/sops.nix`, `.sops.yaml`, `secrets/shared/opencode-tunnel.yaml` | Modified/New | Scalar UUIDs and rule. |
| `darwin/system/sing-box-tunnel.nix`, `hosts/mact2/default.nix` | New/Modified | Full-tunnel client and native tier. |
| `shared/opencode.nix`, `shared/opencode/providers-base.nix`; `linux/system/services/web/opencode-proxy.nix`, `secrets/host/rog/openai-proxy.yaml` | Modified/Removed | Gated gateway retirement. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| TUN conflicts with Netskope/CrowdStrike | Med | Office proof; direct routes; unload + revert. |
| Corporate policy blocks Cloudflare TCP/443 | Med | Hard gate before retirement. |
| Cloudflare disrupts orange-cloud WebSockets | Low | Test; grey-cloud exposes rog IP. |
| DNS self-loop deadlock | Med | Mandatory direct resolver and auto-detected interface. |
| FortiClient route conflict | Med | Office coexistence gate; direct corporate routes. |
| EDR management is silenced on outage | Med | Authoritative IP/domain exclusions; process rules supplement. |
| Full-tunnel traffic anomaly | Med | User accepted; validate before retirement. |
| macOS process-rule fragility | Med | Best-effort only; IP/domain rules backstop. |

## Rollback Plan

Unload the `mact2` daemon and revert declarative tunnel/native-tier changes. Keep the gateway until proof; post-retirement rollback restores its configuration and secrets.

## Dependencies

- Existing wildcard DNS/ACME; orange-cloud `tun.glats.org` needs no record.
- `services.sing-box`, root nix-darwin LaunchDaemons, and sops for both hosts.
- Physical office access for final validation.

## Success Criteria

- [ ] **Home:** native `opencode run -m openai/gpt-5.4 "PONG"` succeeds; device flow/refresh use `chatgpt.com` and `auth.openai.com`.
- [ ] **Home:** full tunnel is default; RFC1918/ULA and corporate endpoints are direct; scoped flip works.
- [ ] **Home:** required resolver/interface prevent self-loops; tunnel ClientHello has uTLS Chrome.
- [ ] **Home:** non-WS paths serve the cover page; only the unguessable WS path proxies to sing-box.
- [ ] **Home:** Android connects via delivered `vless://`; removing either UUID denies only that device.
- [ ] **Home:** no `HTTP(S)_PROXY`; every MCP-child `ps eww` is clean; no `api.openai.com` allowlist entry or `sk-` key.
- [ ] **Office-only:** TUN coexists with Netskope/CrowdStrike/FortiClient; corporate and EDR-management channels stay direct.
- [ ] **Office-only:** Cloudflare TCP/443/WS works with outer SNI `tun.glats.org`; Codex/OAuth works and CrowdStrike permits the daemon.
- [ ] Retirement follows those proofs; teardown is declarative reversion only.
