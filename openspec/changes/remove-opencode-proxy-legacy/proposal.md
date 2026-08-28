# Proposal: Remove OpenCode Proxy Legacy

## Intent

Remove the dead `mact2`→`rog` OpenAI gateway before the tunnel change. Its upstream forwards an NVIDIA NIM (`nvapi-`) credential to `api.openai.com`, which rejects it; this is a root cause, not configuration drift. Affects `rog` and `mact2` only.

## Scope

### In Scope
- Delete the gateway module, `rog` import/configuration (including its systemd timeout override), and `oai.glats.org` nginx vhost.
- Remove the `openai-proxy` provider, all `openai-*-proxy` tiers, proxy-key export, and actual sops declarations/rule/encrypted secret file.
- Change both `mact2` Home Manager entry points to `opencode-go-medium`; it uses living OpenCode Go models rather than the Netskope-blocked OpenAI namespace, and mact2 already has its `opencode-go` auth entry.
- Preserve mact2's native `openai` auth entry for the later tunnel change.

### Out of Scope
- Tunnel, native OpenAI activation, OAuth re-login, or any replacement gateway.
- Changes to other hosts or unrelated OpenCode providers.

## Capabilities

### New Capabilities
- `opencode-runtime-proxy`: Establish the canonical post-cleanup baseline: no public OpenCode proxy gateway, proxy tiers, proxy export, or proxy secrets; mact2 uses a non-OpenAI interim tier.

### Modified Capabilities
- None. `openspec/specs/` has no canonical `opencode-runtime-proxy` spec; the tunnel change's existing delta will modify this baseline later.

## Approach

Remove the complete dependency chain in one declarative cleanup, then select `opencode-go-medium` in both mact2 composition paths. Delete the encrypted proxy file with `git rm`; it remains recoverable from Git history. `shared/opencode/runtime-config.nix` was traced and contains no proxy wiring, so it is unchanged.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `linux/system/services/web/opencode-proxy.nix` | Removed | Python gateway. |
| `hosts/rog/default.nix`, `linux/system/services/web/nginx.nix` | Modified | Gateway import/config/timeout and `oai` vhost removed. |
| `shared/opencode/providers-base.nix`, `shared/opencode.nix` | Modified | Proxy provider/tiers and key export removed. |
| `hosts/rog/secrets.nix`, `darwin/home/sops.nix`, `.sops.yaml`, `secrets/host/rog/openai-proxy.yaml` | Modified/Removed | Server/client declarations, specific rule, encrypted file removed. |
| `hosts/mact2/default.nix`, `flake.nix` | Modified | Both mact2 overrides select `opencode-go-medium`. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| mact2 native OpenAI remains unavailable | High | Explicit interim non-OpenAI tier; tunnel change restores native path later. |
| nginx reload regression | Low | Evaluate rog and inspect generated nginx configuration. |
| Secret removal appears irreversible | Low | Revert restores encrypted Git-tracked file; no data loss. |

## Rollback Plan

Revert the cleanup commit to restore the gateway, vhost, tiers, declarations, and encrypted secret from Git history; no plaintext secret or data recovery is required.

## Dependencies

- None. This runs before tunnel PR1.

## Success Criteria

- [ ] `rog` and `mact2` toplevel evaluations/builds pass.
- [ ] Nix-source grep is clean for `openai-proxy`, `OPENAI_PROXY_API_KEY`, and `oai.glats.org`.
- [ ] mact2 generates `opencode.json` with `opencode-go-medium`.
- [ ] nginx has no `oai.glats.org` virtual host.
