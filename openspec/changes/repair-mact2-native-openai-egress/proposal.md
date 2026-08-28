# Proposal: Repair mact2 Native OpenAI Egress

## Intent

Replace the restored, known-broken OpenAIP gateway path on `mact2`. It forwards an incompatible NVIDIA credential to `api.openai.com`, causing the observed 401. `mact2` must instead use OpenCode's native OpenAI/ChatGPT OAuth flow, with egress isolated from MCP and other traffic.

## Scope

### In Scope
- Host scope: `mact2` and `rog` only.
- Permanently retire the OpenAIP gateway, custom `openai-proxy` provider/tier family, gateway secrets/wiring, and public `oai.glats.org` endpoint.
- Restore `mact2` to the built-in `openai` provider and native `openai-medium` tier; bootstrap OAuth from `rog` only if independently evidenced as necessary.
- Design and validate an evidence-backed egress mechanism that scopes OpenAI OAuth/Codex traffic without proxying MCP traffic or setting shell-wide `HTTP_PROXY`/`HTTPS_PROXY`.
- Define runtime tests for mact2-to-rog reachability, native OAuth refresh/request behavior, and MCP isolation before implementation.

### Out of Scope
- An OpenAI Platform API key, an OpenAI-compatible API gateway, or any public replacement endpoint.
- Deployment, secret creation/rotation, or changes to other hosts.
- Selecting a forward-proxy design before reachability and MCP effects are reproduced.

## Capabilities

### New Capabilities
- `opencode-native-oauth-egress`: mact2 OpenCode uses native ChatGPT OAuth with a verified, OpenAI-only egress path that leaves MCP traffic isolated.

### Modified Capabilities
- None; existing `boot` and `hardware-nvidia` specifications are unrelated.

## Approach

First remove the architectural mismatch in the planned target state. Then establish evidence for the smallest MCP-safe egress design (direct or narrowly process/destination scoped), including whether `rog` is required. Keep OAuth client-side; treat encrypted bootstrap as a fallback, never as an API-key substitute.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `hosts/mact2/default.nix` | Modified | Select native `openai-medium`; remove gateway selection. |
| `shared/opencode.nix`, `shared/opencode/providers-base.nix` | Modified | Remove OpenAIP credentials/provider tiers; preserve native OpenAI. |
| `hosts/rog/default.nix`, `linux/system/services/web/opencode-proxy.nix` | Removed | Retire gateway service and upstream credential use. |
| `linux/system/services/web/nginx.nix` | Modified | Remove `oai.glats.org` routing. |
| `bin/install-opencode-auth-seed` | Modified if retained | Limit fallback bootstrap to native OAuth data. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Egress mechanism remains unproven | High | Require reachability, OAuth, and MCP-isolation evidence before design/apply. |
| OAuth bootstrap token rotation | Medium | Prefer independent login; keep fallback encrypted and one-time. |

## Rollback Plan

Disable the new egress configuration and retain native local configuration/auth backups. Do not restore the gateway, public endpoint, or API-key architecture.

## Dependencies

- Verified native OpenCode OAuth behavior and, only if chosen, verified `mact2`→`rog` transport.

## Success Criteria

- [ ] `mact2` uses native `openai-medium` OAuth with no OpenAIP/API-key path.
- [ ] `oai.glats.org`, gateway code, provider tiers, and gateway secrets are absent.
- [ ] OAuth egress succeeds while MCP traffic is demonstrably unproxied and functional.
- [ ] Artifacts contain no secret values.
