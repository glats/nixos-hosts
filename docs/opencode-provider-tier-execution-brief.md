# OpenCode Provider Tier Execution Brief

This document is for a future agent session that will update `shared/opencode/providers-base.nix`.

The key constraint is fixed: keep the currently proven providers and model IDs that are already present in the repo's current lists. Do not introduce new provider definitions or new model IDs that are not already in the file today.

## Quick path

1. Read `shared/opencode/providers-base.nix`, `shared/opencode/providers.nix`, and `shared/opencode/agents.nix`.
2. Keep all existing tiers and host mappings untouched.
3. Add one or two new cross-provider mixes using only model IDs that already exist in the current file.
4. Run `format-nix` and `nix flake check --no-build`.

## Decision summary

| Topic | Decision |
|-------|----------|
| New models | Do not add any new model IDs beyond what is already in the current lists |
| New providers | Do not add providers |
| Existing tiers | Preserve them |
| Host mappings | Do not change `activeProviderName` on any host |
| Scope now | Documentation only in this session |
| Scope next session | Update `providers-base.nix` using only current trusted models |
| Formatting style | No emojis or decorative status markers |

## Why this constraint exists

The current lists are already the user's trusted baseline:

- The current OpenAI assignments are known-good.
- The current Anthropic assignments are known-good.
- The current OpenCode assignments are known-good.
- The current Copilot-visible model list is trusted because it is already in the repo and has been exercised.

The next session should optimize phase-to-model fit without expanding the model surface area.

## Non-goals

- Do not add `claude-opus-5`, `claude-sonnet-5`, or other direct Anthropic models unless they are already in the direct Anthropic provider list. They are not today.
- Do not add new OpenCode free models or new Go models unless they already exist in the current file.
- Do not change `sops.nix` or `shared/opencode.nix`.
- Do not remap hosts to new tiers.
- Do not delete or rewrite the older tiers.

## Current trusted baseline

These are the families that the next session is allowed to reuse.

### Direct Anthropic provider

Use only the current direct Anthropic list:

- `anthropic/claude-opus-4-8`
- `anthropic/claude-sonnet-4-6`
- `anthropic/claude-haiku-4-5`

### OpenAI provider via current tiers

Use only models that are already referenced by current OpenAI tiers:

- `openai/gpt-5.5`
- `openai/gpt-5.4`
- `openai/gpt-5.4-mini`
- `openai/gpt-5.3-codex-spark`

### GitHub Copilot provider

Use only models already defined in the current Copilot list. Practical candidates for the next session:

- `github-copilot/gpt-5.5`
- `github-copilot/gpt-5.4`
- `github-copilot/gpt-5.4-mini`
- `github-copilot/gpt-5.3-codex`
- `github-copilot/claude-sonnet-4.6`
- `github-copilot/claude-sonnet-5`
- `github-copilot/claude-haiku-4.5`
- `github-copilot/gpt-5.6-terra`
- `github-copilot/gpt-5.6-luna`

Because the user is on Copilot Pro, prefer Terra and Luna over Sol.

### OpenCode Go provider

Use only current OpenCode Go entries already in the file. Preferred candidates:

- `opencode-go/deepseek-v4-pro`
- `opencode-go/deepseek-v4-flash`
- `opencode-go/minimax-m3`
- `opencode-go/mimo-v2.5`
- `opencode-go/mimo-v2.5-pro`
- `opencode-go/qwen3.7-plus`
- `opencode-go/qwen3.6-plus`

Avoid making `glm-5.3` part of a default recommended tier.

## Practical guardrails for the next agent

### Context window guardrail

Do not put smaller-context helper models on exploration-heavy phases.

- Keep `claude-haiku-4.5` away from `sdd-explore` and `sdd-spec`.
- Keep short-context code-specialized models away from repository-scale exploration.
- Prefer `deepseek-v4-pro`, `gpt-5.5`, `claude-sonnet-4.6`, or `claude-sonnet-5` for broad-context phases.

### Cost guardrail

Spend more only on critical SDD phases:

- `sdd-propose`
- `sdd-design`
- `sdd-verify`

Keep cheaper reliable models on:

- `sdd-init`
- `sdd-tasks`
- `sdd-archive`
- `sdd-onboard`

### Stability guardrail

The next agent should prefer the currently proven baseline and avoid building a tier around models that are already known to be noisy or volatile in research notes.

Specific caution:

- Keep `opencode-go/glm-5.3` out of the recommended default tiers.
- Keep `github-copilot/gpt-5.6-sol` out of scope because the user is on Copilot Pro, not Pro+.
- Keep direct Anthropic assignments on the current direct Anthropic list only.

## Suggested new tiers to add next session

The next session should add these as new tiers and leave the older ones intact.

### 1. `models-mix-current`

Balanced default using only the current trusted model lists.

| Phase | Recommended model | Reason |
|-------|-------------------|--------|
| `gentle-orchestrator` | `openai/gpt-5.5` | strong orchestrator, already trusted in current tiers |
| `sdd-init` | `github-copilot/gpt-5.4-mini` | cheap helper phase |
| `sdd-explore` | `opencode-go/deepseek-v4-pro` | strong context-heavy exploration |
| `sdd-propose` | `anthropic/claude-opus-4-8` | critical reasoning, already proven |
| `sdd-spec` | `anthropic/claude-sonnet-4-6` | structured writing with stable baseline |
| `sdd-design` | `anthropic/claude-opus-4-8` | architecture-critical |
| `sdd-tasks` | `github-copilot/gpt-5.4-mini` | cheap decomposition |
| `sdd-apply` | `openai/gpt-5.3-codex-spark` | code editing specialist already used today |
| `sdd-verify` | `github-copilot/claude-sonnet-5` | expensive enough to be strong, but not the heaviest direct Anthropic slot |
| `sdd-archive` | `github-copilot/claude-haiku-4.5` | cheap small-scope cleanup |
| `sdd-onboard` | `github-copilot/gpt-5.4-mini` | guided helper flow |
| `neutral` | `opencode-go/deepseek-v4-flash` | cheap general default |

### 2. `models-mix-current-heavy`

Same trusted baseline, but more expensive on critical review steps.

| Phase | Recommended model |
|-------|-------------------|
| `gentle-orchestrator` | `openai/gpt-5.5` |
| `sdd-init` | `github-copilot/gpt-5.4-mini` |
| `sdd-explore` | `opencode-go/deepseek-v4-pro` |
| `sdd-propose` | `anthropic/claude-opus-4-8` |
| `sdd-spec` | `anthropic/claude-sonnet-4-6` |
| `sdd-design` | `anthropic/claude-opus-4-8` |
| `sdd-tasks` | `github-copilot/gpt-5.4-mini` |
| `sdd-apply` | `openai/gpt-5.3-codex-spark` |
| `sdd-verify` | `anthropic/claude-opus-4-8` |
| `sdd-archive` | `github-copilot/claude-haiku-4.5` |
| `sdd-onboard` | `github-copilot/gpt-5.4-mini` |
| `neutral` | `github-copilot/claude-sonnet-4.6` |

### 3. Optional `go-current-budget`

Only if the next agent wants an updated Go-only value tier without touching the existing `opencode-go-*` tiers.

| Phase | Recommended model | Reason |
|-------|-------------------|--------|
| `gentle-orchestrator` | `opencode-go/deepseek-v4-pro` | strongest current Go baseline |
| `sdd-init` | `opencode-go/mimo-v2.5` | cheapest practical helper |
| `sdd-explore` | `opencode-go/deepseek-v4-pro` | context-heavy |
| `sdd-propose` | `opencode-go/deepseek-v4-pro` | reliable heavy phase |
| `sdd-spec` | `opencode-go/deepseek-v4-pro` | stable long-context writing |
| `sdd-design` | `opencode-go/deepseek-v4-pro` | avoid `glm-5.3` as default |
| `sdd-tasks` | `opencode-go/mimo-v2.5` | cheapest decomposition |
| `sdd-apply` | `opencode-go/minimax-m3` | current proven apply candidate |
| `sdd-verify` | `opencode-go/deepseek-v4-pro` | strongest stable Go review pick |
| `sdd-archive` | `opencode-go/mimo-v2.5` | cheap |
| `sdd-onboard` | `opencode-go/mimo-v2.5` | cheap |
| `neutral` | `opencode-go/deepseek-v4-flash` | low-cost default |

## Current host mappings to preserve

Do not edit these in the next session unless the user explicitly asks.

| Host | Current active provider |
|------|-------------------------|
| `rog` | `models-mix2` |
| `t14` | `openai-full` |
| `thinkcentre` | `openai-medium` |
| `mact2` | `github-copilot-safe` |
| Darwin default | `opencode-free` |

## Exact edit scope for the next session

Edit only:

- `shared/opencode/providers-base.nix`

Read for context only:

- `shared/opencode/providers.nix`
- `shared/opencode/agents.nix`
- `shared/opencode.nix`
- host files that set `home.opencode.activeProviderName`

Do not edit:

- `shared/opencode.nix`
- `shared/sops.nix`
- host `default.nix` files

## Verification checklist for the next session

- [ ] Existing tiers remain present
- [ ] No host `activeProviderName` changes
- [ ] No new model IDs outside the current lists
- [ ] New tiers use only trusted current models
- [ ] `format-nix` passes
- [ ] `nix flake check --no-build` passes
- [ ] Final diff is limited to `shared/opencode/providers-base.nix`

## Recommended completion message for the next session

The next agent should report:

1. Which new tiers were added
2. Which current models were reused
3. Why no new model IDs were introduced
4. Validation result from `format-nix` and `nix flake check --no-build`
