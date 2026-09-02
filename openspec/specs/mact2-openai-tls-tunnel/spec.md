# mact2-openai-tls-tunnel Specification

## Purpose

Provide `mact2` and approved devices a stealth-hardened VLESS transport through `rog` without proxy environment variables.

## Requirements

### Requirement: TLS WebSocket Tunnel Endpoint and Cover Page

`rog` MUST accept VLESS-over-WebSocket only on a loopback listener and expose one fixed random-hex WebSocket path through `https://tun.glats.org`. It MUST reuse existing `glats.org` ACME coverage, MUST NOT open a public listener or require a DNS record while wildcard DNS resolves, and MUST NOT store the path in sops. All non-tunnel paths, including a request to the WebSocket path without Upgrade, MUST serve the static cover-page behavior.

#### Scenario: Verify transport and disguise [hosts: rog]

- GIVEN the tunnel configuration is built
- WHEN `format-nix && nix flake check --no-build`, `GET /`, and non-upgrade `GET /<ws-path>` are run
- THEN the loopback listener and the ACME-backed WebSocket path are available
- AND both HTTP responses have the configured cover-page behavior

### Requirement: Per-Device VLESS Authentication and Secret Safety

The VLESS inbound MUST use a `users` array with one named entry per approved device. Each UUID MUST be supplied from its own scalar sops key at runtime, MUST NOT occur in the Nix store or generated declarative configuration, and each UUID-bearing runtime file MUST be root-owned with mode `0400`.

#### Scenario: Authenticate an approved device [hosts: rog, mact2, Android]

- GIVEN valid and absent-or-wrong per-device UUID credentials
- WHEN each client attempts the VLESS handshake
- THEN only the valid named user connects
- AND the invalid client is rejected without exposing a UUID in the store

### Requirement: Root-Managed Full-Link Routing

`mact2` MUST run the TUN client as a root LaunchDaemon. `link.mode` MUST default to `full`: rules MUST send `ip_is_private` direct first, then `link.directDomains` and `link.directCidrs` direct, then select `home-out` as final. `link.mode = "scoped"` MUST instead tunnel only `chatgpt.com` and `auth.openai.com` and select direct as final.
`process_name` exclusions MAY supplement the direct lists but MUST NOT be their sole enforcement, because macOS process resolution is best-effort.

#### Scenario: Prove full default and direct exclusions [hosts: mact2, rog]

- GIVEN full mode and a configured LAN `link.directDomains` endpoint
- WHEN `sing-box check -c <rendered-config>`, `launchctl print system/sing-box`, an IP-echo HTTPS request, and the LAN request run
- THEN the echo service reports rog's egress IP
- AND logs show the LAN request selected `direct`, not `home-out`

#### Scenario: Flip to scoped routing [hosts: mact2]

- GIVEN the declared mode is changed to `scoped`
- WHEN the configuration is rebuilt and requests target OpenAI and a non-OpenAI HTTPS host
- THEN only `chatgpt.com` and `auth.openai.com` select `home-out`
- AND the non-OpenAI request selects `direct`

### Requirement: Self-Loop Prevention

The client MUST use `tun.glats.org` for transport connection and TLS server name and MUST configure `route.auto_detect_interface` plus a direct `route.default_domain_resolver`. If orange-cloud WebSockets fail, a DNS-only record MAY replace wildcard resolution without changing that identity.

#### Scenario: Smoke-test endpoint resolution first [hosts: mact2]

- GIVEN the client has just started
- WHEN `tun.glats.org` is resolved and requested directly
- THEN resolution and the direct request succeed without a TUN recursion

### Requirement: Proxy-Environment and MCP Isolation

> MODIFIED 2026-08-28 (PR2 runtime wiring): the original blanket rule — "The tunnel MUST NOT set `HTTP_PROXY` or `HTTPS_PROXY` anywhere in the configured environment or process tree" — is narrowed to the scoped-launcher contract below. The narrowing follows the loopback mixed inbound becoming the only working Netskope steering bypass (system-PAC route REMOVED; see design.md PR2 addendum). The MCP-child isolation invariant is unchanged and remains authoritative.

Proxy environment variables MUST be exported ONLY by the scoped `bin/opencode-home` launcher, and ONLY while the loopback mixed inbound (127.0.0.1:2080) is listening. Shell profiles and the tunnel daemon MUST NOT export `HTTP_PROXY` or `HTTPS_PROXY`. MCP child processes MUST retain clean proxy environments, enforced declaratively via `mcp.environment` in the generated opencode.json; in full mode their network traffic MAY traverse the tunnel solely by routing.

#### Scenario: Inspect MCP environments [hosts: mact2]

- GIVEN OpenCode has launched representative MCP children through the active tunnel
- WHEN `ps eww` is inspected for each child
- THEN no child contains `HTTP_PROXY` or `HTTPS_PROXY`

#### Scenario: Scoped launcher exports proxy conditionally [hosts: mact2]

- GIVEN `opencode-home` is launched once with the tunnel up and once with the tunnel down
- WHEN the opencode process environment is inspected in each case
- THEN `HTTPS_PROXY`/`HTTP_PROXY` are set to `http://127.0.0.1:2080` only while the mixed inbound listens
- AND with the tunnel down the launcher prints a stderr notice and opencode runs with a clean proxy env
- AND no shell profile exports either variable

### Requirement: Stealth Client TLS

The VLESS client TLS MUST enable uTLS with the `chrome` fingerprint for the outer connection to `tun.glats.org`.

#### Scenario: Inspect the outer ClientHello policy [hosts: mact2]

- GIVEN the rendered client configuration and an active tunnel
- WHEN `sing-box check -c <rendered-config>` and a TLS fingerprint capture are inspected
- THEN the outbound declares uTLS `chrome`
- AND the observed outer SNI is only `tun.glats.org`

### Requirement: Home Transport Proof

The active home daemon MUST support a TLS request to the OAuth host through the full tunnel before native authentication is relied on.

#### Scenario: Prove the home TLS path [hosts: mact2]

- GIVEN the daemon is active on the home network in full mode
- WHEN `curl -Iv https://auth.openai.com/` runs
- THEN the request completes with valid TLS through the tunnel
- AND its outer connection uses `tun.glats.org`

### Requirement: In-building Coexistence (OFFICE GATE)

Retirement of the old gateway MUST NOT proceed until an in-building test proves the TUN coexists with FortiClient, Netskope, and CrowdStrike; corporate, EDR, Netskope, and FortiClient management traffic remains direct; Cloudflare permits a long-lived WebSocket; outer SNI is only `tun.glats.org`; and CrowdStrike does not flag or block the root daemon.

#### Scenario: Prove office coexistence [hosts: mact2]

- GIVEN `mact2` is in the office with FortiClient and both security agents active
- WHEN tunnel traffic, management heartbeats, and a long-lived Cloudflare WebSocket are exercised
- THEN captures show only `tun.glats.org` as outer SNI and no daemon alert
- AND management and corporate traffic remain direct, healthy, and loop-free

### Requirement: Declarative Teardown

Reverting the declarative tunnel configuration MUST restore the prior network state; before retirement it MUST leave the proxy gateway available. Emergency daemon unload MAY precede that reversion.

#### Scenario: Revert the tunnel [hosts: mact2, rog]

- GIVEN the tunnel has been activated and the proxy gateway is still retained
- WHEN the daemon is booted out and the declarative tunnel changes are reverted
- THEN the TUN route and daemon are absent after rebuild
- AND the prior proxy-backed configuration remains usable
