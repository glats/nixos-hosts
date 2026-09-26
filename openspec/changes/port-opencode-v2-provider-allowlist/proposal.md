# Proposal: Port OpenCode V2 Provider Allowlist

## Intent

V1 hardcodes `disabledProviders` (9 IDs) while V2 emits no provider policy at all, so the two runtimes expose different provider surfaces with no shared source of truth. Consolidate to one central Nix allowlist, prune dead credential exports, and re-home GROQ.

## Scope

### In Scope
- Central 6-provider allowlist (`opencode`, `opencode-go`, `anthropic`, `openai`, `github-copilot`, `nvidia`) in `shared/opencode/providers-base.nix`.
- V1 derives `disabled_providers` from the allowlist (catalog providers outside the 6).
- V2 emits `experimental.policies` = `deny *` + `allow` each of the 6.
- Prune 10 no-consumer exports (cerebras, openrouter, mistral, cohere, gemini, cloudflare×2, kilo, huggingface, aihubmix).
- Remove `GROQ_API_KEY` export from `shared/opencode.nix` (re-home to dictation).
- Preserve `nvidiaProvider`, dormant `nvidia` profile, and `NVIDIA_API_KEY` export untouched.

### Out of Scope
- Latent `nvidia/nvidia/…` vs `nvidia/…` profile bugs; porting `nvidia` to V2.
- Model-level allowlisting (V2 has no `model.use`).
- Deleting the 10 orphan sops secrets (exports only here).
- The in-progress `migrate-opencode-v1-to-v2` runtime structure.

## Capabilities

### New Capabilities
- `opencode-provider-allowlist`: central allowlist; V1 `disabled_providers` derivation; V2 `provider.use` deny-then-allow policy; mandatory runtime deny smoke.

### Modified Capabilities
- `gentle-ai-declarative-runtime`: MODIFY "Provider Credential Exports Remain Stable" — only `OPENCODE_API_KEY` + `NVIDIA_API_KEY` remain; GROQ re-homed; 10 exports removed.

## Approach

Define one allowlist list in `providers-base.nix`. V1's `disabled_providers` = curated deny set (unchanged 9 entries; `nvidia` is non-catalog, never listed). V2's `runtime-config.nix` emits `experimental.policies` (`deny *` first, then `allow` each). Strip `shared/opencode.nix` exports to `OPENCODE_API_KEY` + `NVIDIA_API_KEY`, removing GROQ for dictation re-home.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/opencode/providers-base.nix` | Modified | Central allowlist; nvidia/openai provider map preserved |
| `shared/opencode.nix` | Modified | Strip 10 exports; remove GROQ export |
| `shared/opencode/runtime-config.nix` | Modified | V1 `disabled_providers`; V2 `experimental.policies` |
| `shared/opencode-profile.nix` | Modified | `disabledProviders` becomes allowlist derivation |
| `linux/home/groq-dictation.nix` + `shared-modules.nix` | Coordination | GROQ re-home target (owned by `groq-voice-dictation`) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `provider.use` experimental | Med | Mandatory runtime deny smoke as verify gate |
| GROQ cross-change dependency | Med | Ship `groq-voice-dictation` export before/with removal |
| `nvidia` allowlist no-op in V2 | Low | Documented; harmless until profile ported |
| V1 `disabled_providers` changes | Low | Derivation is intentional; eval-gated |

## Rollback Plan

Revert the touched Nix files via git; allowlist derivation is additive, exports restorable from history. No secret deletions.

## Dependencies

- `groq-voice-dictation` must ship its own `GROQ_API_KEY` export (`linux/home/groq-dictation.nix`) before or with this removal.
- Confirm nixpkgs-pinned `opencode-v2` version at apply time.

## Success Criteria

- [ ] `nix flake check --no-build` and per-host activation evals pass
- [ ] V2 `opencode.json` gains `experimental.policies`; V1 keeps `nvidia` + re-derives `disabled_providers`
- [ ] `opencode2 models` lists only 6 providers; `opencode2 run -m groq/…` rejected
- [ ] 10 exports gone; `OPENCODE_API_KEY` + `NVIDIA_API_KEY` remain; shell-gpt regression passes
- [ ] `GROQ_API_KEY` no longer exported by OpenCode shell init
