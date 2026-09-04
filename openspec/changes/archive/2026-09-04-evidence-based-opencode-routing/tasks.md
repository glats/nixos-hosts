# Tasks: Evidence-Based OpenCode Routing

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 250-450 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 → PR 2 |
| Delivery strategy | single-pr (size:exception) |
| Chain strategy | not needed — single-pr exception applied |

Decision needed before apply: Resolved — user selected single-pr with size:exception.
Chained PRs recommended: Yes (not applied — user override)
Chain strategy: single-pr / size:exception
400-line budget risk: High (accepted)

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Rebuild the catalog + canonical profiles | PR 1 | `nix eval .#nixosConfigurations.t14.config.system.build.toplevel --dry-run` | `nix eval` | Revert `shared/opencode/providers-base.nix` only |
| 2 | Migrate host references and prove repo-wide safety | PR 2 | `format-nix && nix flake check --no-build` | `nix flake check --no-build` | Revert host wiring edits only |

## Phase 1: Catalog Foundation

- [x] 1.1 `shared/opencode/providers-base.nix`: split `providers` into `canonicalProviders` + `legacyProviders`, add `# LEGACY`, and assert unique names before `in`.
- [x] 1.2 Keep `allProviders` untouched; preserve `anthropic-light/medium/full` and `openai-opencode-balanced` mappings exactly, with 12 non-null phase keys each (gentle-orchestrator + 10 SDD phases + neutral).

## Phase 2: Canonical Profile Definitions

- [x] 2.1 `shared/opencode/providers-base.nix`: collapse old `alpha-free` + old `opencode-free` into one new `opencode-free` using only `opencode/*-free` IDs.
- [x] 2.2 `shared/opencode/providers-base.nix`: rename `anthropic-copilot` to `work-copilot-anthropic`, replacing any undeclared IDs with declared ones only; preserve native provider auth/transport assumptions and no fallback logic.
- [x] 2.3 `shared/opencode/providers-base.nix`: add `reliable`, `high-volume`, `quality`, and `cross-provider-review` as unique canonical entries with 12-key coverage, no `BROKEN` IDs, and evidence comments on `gentle-orchestrator` plus one heavy phase (depends on 2.1-2.2).
- [x] 2.4 Freeze the four intent profiles from declared evidence only: `reliable` = Anthropic balanced (`claude-haiku-4-5`/`claude-sonnet-4-6`/`claude-opus-4-8`), `high-volume` = OpenCode Go throughput (`glm-5.3-flash`/`deepseek-v4-flash`/`deepseek-v4-pro`), `quality` = Opus-heavy Anthropic, `cross-provider-review` = mixed Anthropic + OpenCode Go + Copilot + OpenAI prefixes; if any chosen model is account-uncertain, add a blocking smoke-test subtask before finalizing (depends on 2.3).

## Phase 3: Atomic Host Wiring

- [x] 3.1 `hosts/t14/home/default.nix`: change `home.opencode.activeProviderName` from `alpha-free` to `opencode-free`.
- [x] 3.2 `hosts/mact2/default.nix`: change `home.opencode.activeProviderName` from `anthropic-copilot` to `work-copilot-anthropic`; keep the wired Darwin/Home Manager path unchanged.
- [x] 3.3 `flake.nix` and `darwin/default.nix`: verify no stale host reference remains; edit only if a deleted provider name is still present. (Verified only — `flake.nix` thinkcentre HM block uses `openai-medium`, unaffected; root `darwin/default.nix` already used `opencode-free`, unwired dead code per design, no edit needed.)

## Phase 4: Verification and Cleanup

- [x] 4.1 Search the repo for `alpha-free` and `anthropic-copilot`, and for duplicate provider names; allow only historical mentions under `openspec/` or snapshots. (`rg` returned zero matches outside `openspec/`; `nix eval` confirmed 22/22 unique provider names.)
- [ ] 4.2 Run live smoke tests for any account-uncertain IDs used above before marking the four intent profiles ready; do not assume availability (blocker for 2.4 if needed, especially `anthropic/claude-opus-4-8` and any Copilot-gated model). **BLOCKED/PENDING — requires live account credentials not available in this environment; not run, not assumed passing.**
- [x] 4.3 Run `format-nix && nix flake check --no-build` and confirm `rog`, `t14`, `thinkcentre`, and `mact2` still evaluate without deploy/activation; fail the task if any host breaks. (`nix flake check --no-build` passed for rog/t14/thinkcentre via `checks.x86_64-linux`; `mact2` verified separately via `nix eval .#darwinConfigurations.mact2...` since darwin is excluded from `--no-build` on this linux host — evaluated cleanly to `work-copilot-anthropic`.)
