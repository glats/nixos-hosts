# Proposal: mact2 OpenAI Transport Proxy via rog

## Intent

Correct and supersede `mact2-openai-proxy-via-rog`, whose custom OpenAI-compatible API gateway/provider is the wrong architecture. Keep OpenCode's built-in `openai` provider on `mact2`; bootstrap auth from `rog` when needed and route its HTTPS transport through a WireGuard-bound forward proxy on `rog`.

No immediate restore or revert is required before planning. This change defines the gateway artifacts to remove, retained pieces to adapt, and replacement pieces to add during apply.

## Scope

### In Scope
- Host scope: `mact2` client configuration and `rog` proxy/bootstrap services only.
- Retire the Python API gateway, `oai.glats.org` `/v1` vhost, `openai-proxy` and `openai-*-proxy` tiers, gateway secrets, and `OPENAI_PROXY_API_KEY` wiring.
- Restore `mact2` to built-in `openai-medium`; configure scoped OpenCode `HTTP(S)_PROXY` and `NO_PROXY` through `rog` over WireGuard.
- Add a `tinyproxy` forward proxy bound to `rog`'s `10.13.13.1`, with controlled CONNECT access and sops-managed proxy credentials if required.
- Keep and correct encrypted auth bootstrap: retain the installer and uploads ciphertext channel, add the missing publisher, and prefer independent headless login on `mact2`.

### Out of Scope
- Changes to OpenAI, other hosts, or a public API gateway.
- A global macOS proxy configuration or unrestricted `rog` proxy service.
- Sharing a long-lived OAuth refresh token concurrently between hosts.

## Capabilities

### New Capabilities
- `opencode-transport-proxy`: Private WireGuard transport proxying for mact2 OpenCode traffic while retaining the built-in OpenAI provider.
- `opencode-bootstrap-seed`: Encrypted, mact2-targeted OpenCode OAuth bootstrap publication and safe installation.

### Modified Capabilities
- None.

## Approach

Use stock `services.tinyproxy` on `rog`, bound only to the existing WireGuard address. `mact2` keeps native `openai` tiers and directs OpenCode transport via proxy environment variables. Prefer a headless OpenCode login through that proxy for an independent credential; the age-encrypted seed is fallback automation and overwrites only the `openai` auth entry after backup.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `linux/system/services/web/opencode-proxy.nix` | Removed | Retire Python API gateway. |
| `linux/system/services/web/nginx.nix` | Modified | Remove `oai.glats.org` gateway vhost; retain uploads. |
| `hosts/rog/default.nix`, `hosts/rog/secrets.nix`, `shared/sops.nix` | Modified | Replace gateway with WireGuard-bound proxy and credentials. |
| `shared/opencode/providers-base.nix`, `shared/opencode.nix`, `hosts/mact2/default.nix` | Modified | Remove custom family; use native tier and proxy environment. |
| `bin/install-opencode-auth-seed`, `bin/publish-opencode-auth-seed` | Modified/New | Safe fallback seed lifecycle. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| OAuth refresh-token rotation | High | Prefer independent headless login; seed only once. |
| Proxy blocks refresh/CDN traffic | Med | Validate CONNECT and real login/refresh. |
| Proxy affects other OpenCode HTTPS | Med | Scope environment to mact2 OpenCode; document `NO_PROXY`. |

## Rollback Plan

Restore the prior gateway configuration only if the forward-proxy path fails; otherwise disable the new `tinyproxy` and mact2 proxy environment, revoke proxy credentials, and return mact2 to direct built-in OpenAI configuration. Preserve auth backups and never publish plaintext OAuth data.

## Dependencies

- Existing `mact2`↔`rog` WireGuard tunnel and rog OpenAI egress.
- NixOS `services.tinyproxy`, sops, age, and the existing uploads path.

## Success Criteria

- [ ] `mact2` uses built-in `openai-medium`, with no custom OpenAI-compatible provider family.
- [ ] OpenCode OAuth and Codex HTTPS traffic from `mact2` succeeds through a WireGuard-only `rog` forward proxy.
- [ ] Python gateway, public `/v1` endpoint, `sk-` upstream secret, and client gateway key are removed during apply.
- [ ] Bootstrap payloads are age-encrypted, safely merged, and do not expose plaintext credentials.
