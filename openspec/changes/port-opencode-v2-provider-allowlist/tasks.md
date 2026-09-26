# Tasks: Port OpenCode V2 Provider Allowlist

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~240 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain (sub-400 → single-pr shape) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: stacked-to-main
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|----|---------------------|-----------------|-------------------|
| 1 | GROQ rehome then export removal | 1 | `nix eval .#homeConfigurations.rog.activationPackage.drvPath` | dictation shell owns GROQ | Revert 3 files; sops untouched |
| 2 | Central allowlist + V1/V2 emission | 1 | `nix flake check --no-build` | rog V2 runtime smoke | Revert 3 files |
| 3 | Export pruning + regression | 1 | eval grep assertions | shell-gpt regression | Revert one file |

## Phase 1: RED Tests

- [x] 1.1 RED: eval test asserting `shared/opencode/providers-base.nix` lacks `providerAllowlist`/`disabledProviders` (expected fail).
- [x] 1.2 RED: eval test asserting V2 `experimental.policies` absent from runtime JSON (expected fail).
- [x] 1.3 RED: eval test asserting `linux/home/groq-dictation.nix` missing/unregistered (expected fail).
- [x] 1.4 RED: eval test asserting `shared/opencode.nix` exports more than `OPENCODE_API_KEY` + `NVIDIA_API_KEY` (expected fail).

## Phase 2: GROQ Rehome (first per dependency order)

- [x] 2.1 Create `linux/home/groq-dictation.nix`: Linux-only HM module exporting `GROQ_API_KEY` from sops `opencode/groq_api_key`; `.sops.yaml` read-only.
- [x] 2.2 Register it in `linux/home/shared-modules.nix` pre-removal.
- [x] 2.3 GREEN: 1.3 passes.
- [x] 2.4 Remove GROQ export from `shared/opencode.nix`; keep remaining exports byte-identical.
- [x] 2.5 GREEN: 1.4 passes; dictation owns the sole GROQ export.

## Phase 3: Central Allowlist + Policy Emission

- [x] 3.1 Add ordered six-ID `providerAllowlist` and catalog-derived `disabledProviders` to `shared/opencode/providers-base.nix`; NVIDIA declarations/profiles untouched.
- [x] 3.2 Update `shared/opencode/runtime-config.nix`: sole consumer of provider-base outputs; V1 serializes `disabled_providers`; V2 emits `experimental.policies`: deny `provider.use` for `*`, then allow each ID in list order.
- [x] 3.3 GREEN: 1.1 and 1.2 pass.
- [x] 3.4 Remove option `home.opencode.disabledProviders` from `shared/opencode.nix` and its assignment in `shared/opencode-profile.nix`.

## Phase 4: Export Pruning

- [x] 4.1 Remove 10 no-consumer exports from `shared/opencode.nix` (cerebras, openrouter, mistral, cohere, gemini, cloudflare×2, kilo, huggingface, aihubmix); sops and `.sops.yaml` read-only.
- [x] 4.2 GREEN: 1.4 passes after pruning.

## Phase 5: Verification

- [x] 5.1 `nix fmt` touched Nix files.
- [x] 5.2 `go -C pkgs/nixos-scripts test ./...` — ops Go unaffected.
- [ ] 5.3 `nix flake check --no-build`; `nix eval` Linux (rog, t14, thinkcentre) + both macm5 Home Manager paths.
- [x] 5.4 Assert V1/V2 JSON: V1 keeps `nvidia` + re-derived deny set; V2 deny-then-allow over exactly six IDs.
- [ ] 5.5 Runtime deny smoke on rog post-activation: `opencode2 models` shows nothing outside six; `opencode2 run -m groq/… "hi"` rejected. Empirical deny gate; kept after evals green.

## Phase 6: Cleanup

- [x] 6.1 Document allowlist contract in `shared/opencode/providers-base.nix` header comment.
- [x] 6.2 Remove stale references to deleted `disabledProviders` option.
