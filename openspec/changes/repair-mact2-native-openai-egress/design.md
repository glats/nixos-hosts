# Design: Repair mact2 Native OpenAI Egress

## Technical Approach

This is a **preflight-gated repair**, not a proxy implementation. Retire the
known-invalid OpenAIP gateway (`nvapi-` forwarded to `api.openai.com`) rather
than repair it. `mact2` uses built-in `openai`/`openai-medium` with native
ChatGPT OAuth. An encrypted auth seed is fallback bootstrap only, never an API key.

No routing mechanism is selected now. Before any configuration change, the
preflight must prove: (1) native OAuth refresh/request behavior, (2) direct
egress and, only if it fails, mact2→rog candidate/rog egress, and (3) local MCP
child isolation. Missing evidence stops implementation. Direct native egress is
the safe fallback if no MCP-safe narrow transport is evidenced. Do not invent an
OpenCode per-provider proxy API.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Authentication | Native OpenCode ChatGPT OAuth; seed only as fallback | `sk-` key, gateway credential | OAuth matches the built-in provider; the gateway's NVIDIA credential is proven incompatible. |
| Egress | Prefer evidenced direct egress; otherwise choose only an MCP-isolated narrow mechanism | Global `HTTP(S)_PROXY`, new provider proxy API | `extraInitContent` exports enter the zsh parent and can reach child MCPs. No isolation proof exists. |
| Gateway | Delete, never fix or restore | Retarget its upstream credential | It is an API gateway/public endpoint outside the desired native-auth architecture. |

## Data Flow

```text
mact2 OpenCode -- native OAuth/Codex --> OpenAI (direct, if proven)
       |                                      
       +-- [only after gate] narrow transport --> rog --> OpenAI
       \-- local MCP children: no proxy environment / unchanged routing

fallback: encrypted { openai: OAuth object } --> mact2 local auth.json
```

The seed is recipient-encrypted and merges only `openai` after backup; do not
use its copied credential concurrently on rog and mact2.

## File Changes

| File | Action | Description |
|---|---|---|
| `hosts/mact2/default.nix`, `flake.nix` | Modify (gated) | Select `openai-medium`; remove proxy tier; no proxy export without isolation evidence. |
| `shared/opencode/providers-base.nix`, `shared/opencode.nix` | Modify (gated) | Remove custom provider/tier and gateway-key export. |
| `darwin/home/sops.nix`, `shared/sops.nix`, `hosts/rog/secrets.nix`, `.sops.yaml`, `secrets/host/rog/openai-proxy.yaml` | Modify/Delete (gated) | Remove gateway credentials; do not replace with an API key. |
| `hosts/rog/default.nix`, `linux/system/services/web/opencode-proxy.nix`, `linux/system/services/web/nginx.nix` | Modify/Delete (gated) | Remove service/import/timeout and `oai.glats.org`; add rog transport only if selected. |
| `bin/install-opencode-auth-seed` | Modify only if retained | Restrict fallback payload/merge to the `openai` OAuth object. |
| `shared/opencode/mcps-base.nix`, `shared/github-mcp-wrapper.nix` | Read-only test fixtures | Supply representative local child MCPs for isolation probes. |

## Interfaces / Contracts

The target contract is `home.opencode.activeProviderName = "openai-medium"`.
No custom provider, `baseURL`, gateway key, or claimed per-provider proxy API.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Preflight | OAuth/direct egress | Record sanitized native login and Codex request; prove direct success/failure. |
| Preflight | rog candidate | If needed, prove mact2→rog CONNECT and rog→OpenAI; otherwise do not configure rog. |
| Preflight | child isolation | Launch local GitHub/Engram MCP probes; assert proxy variables/connections are absent and MCP succeeds. |
| Static/runtime | Retirement and selected path | `format-nix`, `nix flake check --no-build`, host builds, no gateway references, native OAuth request, and MCP regression probe. |

## Threat Matrix

| Boundary | Applicability | Design response / safe failure | Planned RED test |
|---|---|---|---|
| Egress routing | Applicable | Direct or evidenced narrow routing only; failure selects direct/no change. | Direct/candidate traces; blocked candidate blocks apply. |
| Shell environment propagation | Applicable | Never use `extraInitContent` proxy exports; inherited value fails. | Parent/child environment probe. |
| MCP child-process isolation | Applicable | MCPs retain default routing; proxy variable/connection fails. | Local `github-mcp-server-*` and `engram mcp` probe. |
| Documentation-like paths | N/A — no executable classification | None | None |
| Git repository selection | N/A — no VCS command | None | None |
| Commit state | N/A — no commit automation | None | None |
| Push state | N/A — no push automation | None | None |
| PR commands | N/A — no PR automation | None | None |

## Migration / Rollout

Run preflight first. If direct works, retire the gateway and use native OAuth.
If only narrow MCP-safe transport works, deploy it with retirement. Otherwise
make no routing change. Rollback disables the selected path or reverts the
generation, never the gateway/API-key architecture.

## Open Questions

- [ ] What native OAuth endpoints/transport does the installed OpenCode binary actually use on mact2?
- [ ] Does direct mact2 egress work, and if not, is rog reachable for the required destinations?
- [ ] Is any candidate mechanism demonstrably isolated from OpenCode local MCP children?
