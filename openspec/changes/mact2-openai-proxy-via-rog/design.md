# Design: mact2 OpenAI Proxy via rog

## Technical Approach

`rog` becomes the trust boundary for both bootstrap and runtime. Step 1 publishes a **mact2-targeted encrypted auth seed** into the existing `glats.org/uploads/` tree; a repo-local script on `mact2` downloads, decrypts, and merges it into `~/.local/share/opencode/auth.json`. Step 2 switches `mact2` to a **new custom OpenCode provider ID** named `openai-proxy` that points at `https://oai.glats.org/v1`, where nginx reverse-proxies to a loopback-only gateway on `rog`. The gateway holds the upstream OpenAI-compatible credential and exposes only a scoped client key to `mact2`. The provider lives in its own family, so the built-in `openai` provider and the `openai-full/medium/light` tiers stay untouched for every other host.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Runtime gateway | Loopback-only LiteLLM-style OpenAI-compatible gateway on `rog`, fronted by nginx at `oai.glats.org` | nginx-only auth rewrite; reusing built-in `openai` provider | Preserves server-side upstream credentials, keeps upstream vendor configurable, and matches existing nginx + container patterns. |
| Client identity | New custom provider ID `openai-proxy` in `shared/opencode/providers-extra.nix` (separate family; built-in `openai` is left intact) | Override built-in `openai` | Avoids collisions with stored OAuth state, OpenCode built-in auth behavior, and any existing `openai` provider usage on other hosts. |
| Bootstrap distribution | Uploads artifact is **encrypted for `mact2`** and installed by a repo-local script | Raw `auth.json` in `uploads/`; manual SSH copy only | `uploads/` serves files publicly by path, so ciphertext-only distribution is the minimum acceptable posture. |

## Data Flow

### Bootstrap

```text
rog auth source -> encrypted seed file -> glats.org/uploads/... -> mact2 install script
                                                         -> decrypt + merge -> ~/.local/share/opencode/auth.json
```

### Runtime

```text
OpenCode on mact2 -> custom provider (openai-proxy) -> https://oai.glats.org/v1
  -> nginx on rog -> loopback gateway container/service -> upstream OpenAI-compatible API
```

## File Changes

| File | Action | Description |
|---|---|---|
| `linux/system/services/web/opencode-proxy.nix` | Create | New `rog` service module for the loopback gateway, env/secrets wiring, and health policy. |
| `linux/system/services/web/nginx.nix` | Modify | Add `oai.glats.org` vhost, proxy only `/v1/`, deny admin/UI routes, keep existing `uploads/` behavior. |
| `hosts/rog/default.nix` | Modify | Import the new proxy module explicitly. |
| `hosts/rog/secrets.nix` | Modify | Declare upstream API key, gateway master key, and seed-publishing inputs as host secrets. |
| `shared/opencode/providers-base.nix` | Modify | Add the custom OpenAI-compatible provider definition for `openai-proxy` (separate from the built-in `openai` provider) and the `openai-{full,medium,light}-proxy` tier family. |
| `shared/opencode.nix` | Modify | Export the new `OPENAI_PROXY_API_KEY` env var when present. |
| `shared/sops.nix` | Modify | Declare the mact2-visible client/gateway key secret. |
| `hosts/mact2/default.nix` | Modify | Switch `home.opencode.activeProviderName` to one of the new `openai-{full,medium,light}-proxy` tiers (no ad-hoc override path). |
| `shared/opencode/providers-base.nix` | Modify | Add dedicated `openai-full-proxy`, `openai-medium-proxy`, `openai-light-proxy` tiers that reference `openai-proxy/...` models. |
| `bin/install-opencode-auth-seed` | Create | Downloads the encrypted seed from `uploads/`, decrypts it, backs up `auth.json`, and merges the seed. |

## Interfaces / Contracts

```nix
services.opencodeProxy = {
  enable = true;
  domain = "oai.glats.org";
  port = 4010;               # loopback target for nginx
  clientKeyFile = config.sops.secrets."opencode/openai_proxy_client_key".path;
  upstream = {
    baseURL = "https://api.openai.com/v1"; # configurable
    apiKeyFile = config.sops.secrets."opencode/openai_proxy_upstream_key".path;
  };
  seed = {
    uploadsPath = "/run/media/stuff/droppy/nginx/opencode/mact2-auth-seed.age";
    installTarget = "~/.local/share/opencode/auth.json";
  };
};
```

`bin/install-opencode-auth-seed` contract: fetch exact URL, require local decrypt capability, create `auth.json.bak.<timestamp>`, merge only the seed payload, and fail closed on checksum/decrypt/JSON errors.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Unit | Seed merge and backup behavior | Script tests for absent file, existing file, invalid JSON, and duplicate entry handling. |
| Integration | Nix config generation | `format-nix` and `nix flake check --no-build`; inspect generated `opencode.json` for custom provider + host tier. |
| Integration | Proxy path | Build `rog` config, verify nginx vhost routes `/v1/*` to loopback and rejects non-runtime paths. |
| E2E | Bootstrap + runtime | On `mact2`, run install script, confirm `auth.json` updated, then `opencode` calls hit `oai.glats.org`. |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — no executable/doc classification logic | None | None |
| Git repository selection | N/A — no git command execution | None | None |
| Commit state | N/A — no commit automation | None | None |
| Push state | N/A — no push automation | None | None |
| PR commands | N/A — no PR automation | None | None |

## Migration / Rollout

1. Add secrets and deploy `rog` gateway + nginx vhost without switching `mact2`.
2. Publish encrypted seed into `uploads/`.
3. Run `bin/install-opencode-auth-seed` on `mact2`.
4. Switch `mact2` to the new provider tier and verify `oai.glats.org` traffic.

Rollback: revert `mact2` provider tier, remove/revoke the client key, delete the uploaded seed, and disable the `rog` proxy module/vhost. Existing `auth.json` backup allows local restore on `mact2`.

## Open Questions

- [ ] Whether `oai.glats.org` should remain internet-exposed for now or add IP/VPN restrictions once the path is proven.
