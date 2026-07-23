---
name: audit-providers-models
description: >
  Discover ALL OpenCode-compatible providers, their models, and build per-provider
  SDD phase tier lists (full/medium/light/free). Detect missing API keys and flag
  them. Trigger: revisar modelos, auditar providers, modelos opencode, update models,
  providers base, model fit, check models, model audit, actualiza modelos.
metadata:
  version: "3.0"
---

## Activation Contract

Load when the user asks to audit, review, update, or check OpenCode provider models.
Also load before any SDD change that touches `shared/opencode/providers-base.nix`.

The agent already knows SDD phases from the Gentle AI ecosystem (orchestrator routes
subagents, apply implements, explore reads codebase, etc.). This skill provides the
research framework to find which models best fit each phase — see below.

## Hard Rules

- Every audit starts with a **fresh market snapshot** — never trust past BLOCKED/BROKEN
  annotations, never search engram for old model decisions.
- Discover providers by reading OpenCode source and docs, not from a hardcoded list.
- For each provider, determine auth method: API key (needs sops + env export) or
  /connect (OAuth, built-in — no key needed).
- Every model assignment must cite a current data point (uptime, benchmark, issue).
- Edit Nix files directly; run `format-nix && nix flake check --no-build` after.

## Auth Method Recognition

OpenCode providers use one of two auth methods. The skill must identify which applies.

### Method A: API key ⟹ needs 3-file setup

```
① shared/sops.nix
   sops.secrets."opencode/<provider>_api_key" { mode = "0400"; }
② shared/opencode.nix (programs.zsh.initContent)
   export <PROVIDER>_API_KEY="$(cat ${config.sops.secrets."...".path})"
③ shared/opencode/providers-base.nix
   provider { options.apiKey = "{env:<PROVIDER>_API_KEY}"; models = { ... }; }
```

Examples: nvidia, groq, opencode-go, cerebras, openrouter, mistral, deepseek,
together-ai, fireworks, huggingface.

### Method B: /connect (OAuth or built-in) ⟹ no key needed

OpenCode handles auth natively via `/connect` command. Only needs provider
definition with models in `providers-base.nix`.

Examples: github-copilot, anthropic, google (Vertex AI), gitlab-duo.

### Missing key detection

When auditing, cross-reference:
- Providers with keys in `sops.nix` (`opencode/<provider>_api_key`)
- Providers with env exports in `opencode.nix` (`export *_API_KEY=...`)
- Providers defined in `providers-base.nix`

Flag any gap: "Provider X has no API key configured. Add to sops if needed."

## Decision Gates

### Model status (determined FRESH each audit)

| Status | How to determine |
|--------|-----------------|
| ✅ Active | Uptime ≥90% on opencode.ai/data/, no open blocking issues |
| ⚠️ Risky | Uptime 80-90%, or known intermittent issues |
| 🔴 BLOCKED/BROKEN | Open GitHub issues with confirmed reproduction, or provider docs say deprecated |

Sources: opencode.ai/data/, GitHub issues (opencode-ai/opencode + provider repos), provider docs.

## SDD Phase Fit — Research Framework

All research in this section uses MCP tools (exa, GitHub, context7).

### Step A: Discover SDD phases

Research what SDD (Spec-Driven Development) phases exist and what each one does.
Search for "gentle-ai SDD phases", "opencode SDD workflow", or "spec-driven development
subagents". Determine:
- What each phase does (reads code? writes code? routes subagents? plans architecture?)
- Whether it runs as a main agent or subagent in OpenCode
- Whether it runs once or may loop on retry

### Step B: Determine evaluation metrics per phase

For each phase discovered, deduce what metrics predict good performance:
- Phases that write/edit code → SWE-bench, LiveCodeBench, MCP Atlas/Mark
- Phases that reason/plan → GPQA Diamond, Intelligence Index, AIME
- Subagent phases → instruction-following, markdown context handling
- Phases using MCP tools → MCP Atlas/Mark scores
- Runs once → cost-tolerant. May loop → weight cost higher.

### Step C: Evaluate models

For each provider, for each phase, check:
1. Benchmark scores on metrics from Step B
2. GitHub issues (`opencode-ai/opencode`) — model name + "subagent", "hang", "tool call"
3. Uptime at `opencode.ai/data/`
4. Cost at expected usage

### Step D: Document

`Phase | Model | Uptime | Benchmark | Why`

## Execution Steps

All research steps use MCP tools: exa (web search), GitHub (code/issues), context7 (docs).

1. **Market snapshot**: Discover ALL providers OpenCode supports. Search opencode-ai/opencode
   source (internal/llm/provider/), opencode docs (context7), and community providers (exa).
2. **Auth classification**: For each provider, determine: API key or /connect? Check sops.nix
   and opencode.nix to see which keys already exist.
3. **Model discovery**: For each provider, fetch current model catalog from official docs/API.
4. **Status verification**: Check uptime at opencode.ai/data/, search GitHub issues for
   model + "error/broken/hang/tool_call", check provider docs for deprecations.
5. **Fit evaluation** (per provider, per phase): Follow the Research Framework above.
   For each phase, research which model fits best using benchmarks, uptime, cost,
   and OpenCode subagent behavior. Document: `Phase | Model | Uptime | Benchmark | Why`.
   Keep blocked/broken models out.
6. **Build per-provider tiers**: From the fit evaluation, assemble full/medium/light/free
   tiers. Full = best model per phase (cost-tolerant). Medium = best after cost filter.
   Light = cheapest reliable. Free = no-cost models only.
7. **Update 3 files**: sops.nix (add missing key declarations), opencode.nix (add missing env exports),
   providers-base.nix (add/update provider definitions and phase tiers).
8. **Flag missing keys**: Report any provider that needs a key but doesn't have one configured.
9. **Validate**: `format-nix && nix flake check --no-build`.

## Output Contract

- Updated `shared/opencode/providers-base.nix` with per-provider tiers (full/medium/light/free).
- Updated `shared/sops.nix` with missing key declarations.
- Updated `shared/opencode.nix` with missing env exports.
- **Fit evaluation table** per provider: `Phase | Model | Uptime | Why` — documents
  the reasoning behind every single phase-to-model assignment.
- A gap report: providers with missing keys or missing provider definitions.
- Fresh BLOCKED/BROKEN annotations with current issue references.
- Passes `nix flake check --no-build`.
