# Proposal: mact2 OpenAI Proxy via rog

## Intent

Enable `mact2` to use OpenAI-compatible OpenCode access without assuming native OpenAI OAuth will succeed on macOS. This change encodes a two-step path: bootstrap blocked auth state from `rog`, then route runtime HTTP traffic through `rog`.

## Scope

### In Scope
- Host scope: `mact2` client path and `rog` server path only.
- Bootstrap delivery of a seed/auth artifact from `rog` to `mact2` via the existing nginx `uploads/` path.
- Runtime API proxying through a dedicated endpoint such as `https://oai.glats.org/v1`.
- A host-scoped OpenCode provider/config switch on `mact2` that uses a custom OpenAI-compatible provider (`openai-proxy`), not native OpenAI OAuth.

### Out of Scope
- Other hosts (`t14`, `thinkcentre`, `rog` as client).
- Replacing all OpenCode auth with pure OAuth removal.
- Final upstream choice beyond “server-side OpenAI-compatible credential on `rog`”.

## Capabilities

### New Capabilities
- `opencode-bootstrap-seed`: Deliver a bootstrap artifact from `rog/uploads/` to `mact2` for initial auth seeding.
- `opencode-runtime-proxy`: Route `mact2` OpenCode runtime calls through `oai.glats.org` backed by a server-side credential on `rog`.

### Modified Capabilities
- None.

## Approach

Use `rog` as the trust boundary. Step 1 distributes a bootstrap file over the existing nginx-served `uploads/` channel. Step 2 configures `mact2` to call a new OpenAI-compatible endpoint on `rog` (`oai.glats.org`) using a dedicated custom provider ID (`openai-proxy`) and client/gateway secret from sops. The exact upstream on `rog` remains open (direct OpenAI API, Azure OpenAI, or another OpenAI-compatible backend) as long as it stays server-side.

This change adds a separate proxy-backed provider family and tier family (`openai-full-proxy`, `openai-medium-proxy`, `openai-light-proxy`) so that the built-in `openai` provider/tier family stays intact for other hosts (`rog`, `thinkcentre`, `t14`).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `hosts/mact2/default.nix` | Modified | Switch `home.opencode.activeProviderName` to one of the new `openai-*-proxy` tiers; no ad-hoc override path |
| `hosts/rog/default.nix` | Modified | Import proxy/bootstrap service path |
| `linux/system/services/web/nginx.nix` | Modified | Add `oai.glats.org` vhost and preserve `uploads/` delivery |
| `shared/opencode/providers-base.nix` | Modified | Add custom OpenAI-compatible provider ID `openai-proxy` and the `openai-{full,medium,light}-proxy` tier family |
| `shared/opencode.nix` / `shared/opencode/runtime-config.nix` | Modified | Wire endpoint/key/runtime config |
| `hosts/rog/secrets.nix` / `shared/sops.nix` | Modified | Declare server/client secrets |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Bootstrap artifact mishandled | Med | Limit scope to `mact2`, use explicit seed path, document rotation/removal |
| Public proxy exposure on `oai.glats.org` | Med | Restrict routes, keep admin loopback-only, use scoped client key |
| Upstream credential choice changes | Med | Keep provider backend abstract at proposal/spec level |

## Rollback Plan

Disable the `mact2` proxy tier, remove `oai.glats.org` routing, revoke client/gateway secrets, and stop distributing the bootstrap artifact from `uploads/`. `mact2` returns to its prior OpenCode configuration without changing other hosts. The built-in `openai` provider and its `openai-full/medium/light` tiers stay intact on every host.

## Dependencies

- Existing wildcard TLS/nginx on `rog`
- Existing `uploads/` publication path
- Sops-managed client and server secrets

## Success Criteria

- [ ] `mact2` can obtain the bootstrap artifact from `rog/uploads/` through a documented host-scoped flow.
- [ ] `mact2` runtime OpenCode traffic targets `oai.glats.org`, not native OpenAI OAuth.
- [ ] Upstream credential material stays server-side on `rog`; `mact2` receives only scoped client access.
