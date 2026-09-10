# Tasks: Prune Declared Built-in Providers

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~725 (≈715 deleted, ~10 added) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1: extras removal (T2+T3, ~445 lines) → PR 2: base reduction (T1, ~280 lines); T4-T7 gate the integrated state |
| Delivery strategy | ask-on-risk (default) |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Delete dead extras (T3+T2) | PR 1 | `git grep -n extraProviders` (zero, outside openspec) | nix eval (see T2) | Restore `providers-extra.nix` + revert `providers.nix` |
| 2 | Reduce base catalog (T1) | PR 2 | nix eval keys==[nvidia,opencode] + 22 profiles | `/tmp/opencode/prune/harness.nix` A/B | Revert `providers-base.nix` |

## Phase 1: Core Edits (T1-T3 — independent, parallelizable)

- [x] **T1** Reduce `shared/opencode/providers-base.nix`: delete `anthropicProvider` (lines 229-245 incl. header comment) and `githubCopilotProvider` (lines 247-353 incl. header comment); shrink `opencodeProvider` (74-227) to `{ opencode = { options = { timeout = 3600000; chunkTimeout = 3600000; }; }; }` (drop 33 model pins, all `thinking = false`, free-tier comment block); line 355 → `allProviders = nvidiaProvider // opencodeProvider;`. Leave `nvidiaProvider` (7-72) and all 22 profiles untouched.
  Verify: `nix eval --impure --json --expr 'let lib = (builtins.getFlake "github:NixOS/nixpkgs/a9e6d84f9c2f9012f5fe7d964a7851352300e61a").lib; f = import ./shared/opencode/providers-base.nix { inherit lib; }; in { keys = builtins.attrNames f.allProviders; n = builtins.length f.providers; }'` → `keys == ["nvidia" "opencode"]`, `n == 22`.
  Spec: Minimal Declarative Provider Catalog; OpenCode Streaming Overrides Persist.
- [x] **T2** De-thread `shared/opencode/providers.nix`: delete `extras` let (providers-extra import + `pathExists` branch) and `extraProviders` merge; body = `import ./providers-base.nix { inherit lib activeProviderName; }`. Keep header comment + args.
  Verify: `nix eval --impure --json --expr 'let lib = (builtins.getFlake "github:NixOS/nixpkgs/a9e6d84f9c2f9012f5fe7d964a7851352300e61a").lib; f = import ./shared/opencode/providers.nix { inherit lib; }; in builtins.attrNames f'` → no `extraProviders` in list.
  Spec: Unreachable Provider Extension Is Absent.
- [x] **T3** Delete `shared/opencode/providers-extra.nix` via `git rm`.
  Verify: `git grep -n -E "extraProviders|providers-extra" -- ':!openspec/**'` → zero hits; file gone from `git status`.
  Spec: Unreachable Provider Extension Is Absent.

## Phase 2: Identity & Catalog Verification (T4-T5 — depend on T1-T3)

- [x] **T4** A/B profile identity (scratch under `/tmp/opencode/prune/` only): copy `git show HEAD:shared/opencode/providers-base.nix` → `base.nix`, edited file → `pruned.nix`; run existing `harness.nix` (pinned lib a9e6d84): `nix eval --json --file harness.nix > eval.json`.
  Verify: `baseProviders == prunedProviders` (22 profiles, full JSON equality); all 12 phase keys resolve in both.
  Spec: Routing Profiles Remain Independent (scenario: Pruned and baseline routing are equivalent).
- [x] **T5** Catalog cross-check (scratch /tmp): extract unique provider/model refs from pruned `providers`, check against `https://models.dev/api.json`.
  Verify: 0 missing across anthropic(3)/github-copilot(10)/openai(7)/opencode(4)/opencode-go(5); nvidia exempt.
  Spec: Routing Profiles Remain Independent (zero-missing clause).

## Phase 3: Standard Gates (T6 — depends on T1-T5)

- [x] **T6** Run `format-nix` (or `nix fmt -- shared/opencode/providers-base.nix shared/opencode/providers.nix`), then `nix flake check --no-build`, then `nix build .#nixosConfigurations.t14.config.system.build.toplevel` (eval-only, no switch).
  Verify: all three succeed.
  Spec: MODIFIED Shared Evaluation Gate.

## Phase 4: Spec Wording Check (T7 — independent, optional)

- [x] **T7.1** Re-read `openspec/specs/gentle-ai-declarative-runtime/spec.md` (read-only): confirm the `providers-base.nix` mention (Out of Scope, line 77) is an anchor, not a stale provider-catalog reference to the deleted blocks.
  Verify: no block-count/declaration contract references the removed blocks.
- [x] **T7.2** (conditional) If T7.1 finds a stale reference, reword `openspec/specs/gentle-ai-declarative-runtime/spec.md` in place; otherwise no edit. Verify: `nix flake check --no-build` still passes.
## Apply Addendum (2026-09-09)

Applied as one batch per orchestrator instruction (no commit; tree left dirty for review). Verification ran twice: (1) against the apply candidate snapshot — profiles byte-identical to HEAD (full JSON equality over all 24); (2) re-run against the final tree, which gained **concurrent external edits** during apply (new canonical profile `opencode-go-openai`, `openai-opencode-balanced` remaps to `openai/gpt-5.6-luna` — 25 profiles on disk now). Those edits are NOT part of this change; catalog cross-check re-run on the final tree: 0 missing; flake check + t14 dry-run re-passed. My change's profile-preservation proof binds to the candidate snapshot in `/tmp/opencode/apply/pruned.nix`.
