---
name: sdd-model-fit
description: >
  Fit SDD phases to OpenCode models under hard stability and tool-call gates,
  and iteratively mold the named routing profiles in shared/opencode/providers-base.nix.
  Two modes: full audit (fresh market snapshot across all providers) and re-fit
  (single-phase swap driven by observed evidence). Trigger: model fit, sdd model,
  provider fit, revisar modelos, auditar providers, modelos opencode, update models,
  providers base, check models, model audit, actualiza modelos, moldear listas,
  swap model, routing fit.
metadata:
  version: "4.0"
---

## Activation Contract

Load when the user asks to fit, audit, review, update, mold, or check OpenCode
provider models or SDD phase routing. Also load before any SDD change that
touches `shared/opencode/providers-base.nix`.

The agent already knows SDD phases from the Gentle AI ecosystem (orchestrator
routes subagents, apply implements, explore reads codebase, etc.). This skill
provides the evidence framework to find which model best fits each phase and
to keep the routing lists converging toward stable providers with complete
tool-call behavior.

## Hard Rules

- Every **full audit** starts with a **fresh market snapshot** — never trust
  past BLOCKED/BROKEN/RISKY annotations as current fact; re-verify or expire them.
- Every model assignment must cite a **current data point** (uptime, benchmark,
  retention, issue). No citation, no change.
- Never search engram for stale model decisions; DO read engram for fresh
  phase-misbehavior observations (see Feedback Loop).
- A model never enters a routing list without passing **all three Hard Gates**.
- Edit Nix files directly; run `format-nix && nix flake check --no-build` after
  (unless the user explicitly waives it for the session — record the waiver).
- One re-fit changes one phase at a time. Lists evolve; they are not redesigned
  wholesale.
- Secrets rule: agents must NEVER decrypt sops secrets — read ciphertext only.

## Mode Selection

| Situation | Mode |
| --- | --- |
| New provider, new model family, or periodic review of all profiles | `full` |
| One phase misbehaved in observed use, or a single phase needs a better fit | `re-fit` |
| User reports a blocked/degraded phase or asks "why is X slow/broken" | `re-fit` (diagnose first, then swap) |
| User asks to add a whole new profile or rebalance a whole provider family | `full` |

## Auth Method Recognition

OpenCode providers use one of two auth methods; identify which applies.

### Method A: API key ⟹ needs 3-file setup

```
① shared/sops.nix
   sops.secrets."opencode/<provider>_api_key" { mode = "0400"; }
② shared/opencode.nix (programs.zsh.initContent)
   export <PROVIDER>_API_KEY="$(cat ${config.sops.secrets."...".path})"
③ shared/opencode/providers-base.nix
   provider { options.apiKey = "{env:<PROVIDER>_API_KEY}"; }
```

Examples: nvidia, groq, opencode-go, cerebras, openrouter, mistral, deepseek.

### Method B: /connect (OAuth or built-in) ⟹ no key needed

OpenCode handles auth natively via `/connect`. Only the routing profile needs
editing. Examples: anthropic, openai (ChatGPT OAuth), github-copilot, google.

### Missing key detection

Cross-reference sops.nix keys, opencode.nix env exports, and provider
definitions. Flag any gap: "Provider X has no API key configured."

## Hard Gates — non-negotiable, checked in order

### Gate 1: Tool-call completeness

The model must execute ALL tool calls reliably in OpenCode. Assign NOTHING —
not even to a light phase — to a model with an OPEN issue showing any of:

- Stream ends without `finish_reason` (truncation).
- Silent truncation persisted as a complete answer.
- Subagent "gives up", stops mid-task, or hangs awaiting manual "Proceed".
- Crash or misbehavior with concurrent/parallel tool calls.
- Requires a different transport than the provider route uses (e.g. Responses
  API vs Chat Completions / Messages) — verify the route serves the model's
  native transport before assigning.

Historical evidence to learn from (verify each fresh — some may be fixed):
muse-spark-1.2-contributor-free (no finish_reason, #43882), silent truncation
(#44385), glm-5.1 "gives up too quickly", minimax-m2.7 TUI crash on concurrent
tools (#19463), gpt-oss-120b stops mid-reasoning (#27210).

### Gate 2: Provider stability

Status per model, determined FRESH each time (sources: opencode.ai/data/,
opencode-ai/opencode issues, provider docs):

| Status | Criteria |
| --- | --- |
| ✅ Active | Uptime ≥90%, no open blocking issues |
| ⚠️ Risky | Uptime 80-90%, OR intermittent issues, OR cost-instability signal |
| 🔴 BLOCKED | Open issue with confirmed reproduction, or provider docs say deprecated |

Cost-instability signals also mark ⚠️: cache-behavior cost spikes (e.g.
deepseek-v4-flash cache drop ≈27x, #42935), usage multipliers not shown in
sticker price (e.g. gpt-5.6-luna 2x on Go), 403-for-some-accounts patterns
(#40343). A provider that silently burns quota is not stable.

### Gate 3: Live smoke test — before any NEW model enters a list

1. Connectivity minimum: `opencode run -m <provider>/<model> "hi"`.
2. The real gate: one real tool-call exchange (e.g. ask it to run a trivial
   command via tool) that COMPLETES with clean finish_reason. A "hi" that
   answers text is not proof of tool-call fitness.
3. Record the test date next to the assignment comment.

## SDD Phase Fit — Research Framework

All research uses MCP tools (exa, GitHub, context7) — never guess APIs, model
IDs, quotas, or option paths.

### Step A: Discover SDD phases

What each phase does, main vs subagent, runs-once or may-loop. Known map:
orchestrator (routes subagents, loops constantly), init/archive/onboard
(boilerplate, once), explore (read+MCP heavy, long context), propose/spec/
design (judgment writing, once), tasks (mechanical decomposition), apply
(tool-loop edits, may-loop), verify (acceptance gate, once).

### Step B: Metrics per phase

- Write/edit code → SWE-Bench (Pro/Verified), DeepSWE, Terminal-Bench, agentic
  coding index.
- Reason/plan → GPQA, AIME, intelligence index.
- Explore large repos → long-context retrieval (RULER, MRCR — a model with
  weak 8-needle retrieval is disqualified for explore even if cheap).
- Orchestrator → request headroom/quota, structured tool calls, latency —
  NOT raw reasoning; the best reasoner is often the wrong router.
- Subagent phases → instruction-following, context handling.
- May-loop phases weight cost-per-loop; once-phases tolerate cost.

### Step C: Evaluate candidates

For each candidate model: benchmarks for Step-B metrics, GitHub issues (model
name + "subagent/hang/tool_call/finish_reason"), uptime + retention at
opencode.ai/data/, real quota cost (credits per M tokens, plan windows),
thrashing signals (a cheap tier that burns 2-3x tokens to fail is not cheap).

### Step D: Document

`Phase | Model | Evidence | Why` — every assignment row carries its citation.

## Execution Steps — mode `full`

1. Fresh market snapshot: discover ALL providers (OpenCode source
   `internal/llm/provider/`, docs via context7, community via exa).
2. Auth classification (Method A/B); cross-check sops.nix + opencode.nix keys.
3. Model discovery from official docs/API; note retirement dates (e.g.
   gpt-5.4/5.4-mini removed from ChatGPT-account Codex on 2026-08-31).
4. Status verification: opencode.ai/data/ usage+retention, GitHub issues,
   provider deprecations. Apply Gates 1-2.
5. Fit evaluation per profile following the Research Framework; document the
   `Phase | Model | Evidence | Why` table.
6. Gate 3 smoke test for every model that is new to a list.
7. Update `shared/opencode/providers-base.nix` named profiles with dated
   evidence comments; update sops.nix/opencode.nix if a Method-A key is missing.
8. Validate: `format-nix && nix flake check --no-build` (honor user waiver if
   given, and say so in the report).

## Execution Steps — mode `re-fit`

1. Collect the trigger evidence: what failed, which phase, which model, which
   host (user report, engram observation, or session log).
2. Re-verify ONLY that phase: current status of the incumbent + research 2-4
   candidate replacements against the Step-B metrics for that phase. Gates 1-2
   apply; Gate 3 smoke test for any candidate not already in a list.
3. Swap one phase assignment; write the dated evidence comment (what failed,
   why the replacement).
4. Update the profile header comment if the strategy line changed.
5. Validate as in mode `full`; report the one-line delta.

## Feedback Loop

- After each SDD run, capture to engram: phase, model, host, misbehavior
  (truncation, give-up, thrash, quota burn) or notable success. Scope: project.
- A captured misbehavior is the trigger for a `re-fit` on that phase — do not
  wait for a periodic audit.
- Diagnose before swapping: a phase failing repeatedly may be a context-size
  problem (use a model with bigger retrieval, not a smarter one) or a
  transport problem (Gate 1), not a capability problem.

## Agent Biases

This skill biases the agent's decisions as follows:

1. **Stability > peak quality.** A slightly weaker model that never truncates
   tool calls beats a brilliant flaky one in looping phases (orchestrator,
   apply). Reserve strong-but-risky models for once-shot judgment phases.
2. **No citation, no change.** Assignments without a current data point are
   reverted, not debated. Vendor benchmarks are cross-checked against
   independent data and watched for thrashing.
3. **Cheap volume, scarce judgment.** Tool-loop and mechanical phases take the
   cheapest tier that passes the gates; quota reserved for judgment phases.
   Moving a volume phase onto scarce quota needs explicit cost justification.
4. **Minimal, reversible changes.** One phase per re-fit; dated comments;
   never delete a working annotation without replacing it with fresh evidence.
5. **Verify before trusting.** Smoke test in vivo before trusting any model —
   including the current favorite.

## Output Contract

- Updated `shared/opencode/providers-base.nix` named profiles with dated,
  cited evidence comments (this repo's real artifact — NOT generic
  full/medium/light/free tier lists).
- Fit evaluation table: `Phase | Model | Evidence | Why` for every changed
  assignment.
- Gap report: providers with missing keys or missing definitions.
- Fresh status annotations (✅/⚠️/🔴) with current issue references; expired
  annotations explicitly marked as re-verified or removed.
- Feedback-loop record saved to engram (mode, swaps, rationale).
- Validation status: `format-nix` + `nix flake check --no-build` result, or
  the user's explicit waiver noted.
- Registry note: after a rename/add, remind that `.atl/skill-registry.md` is
  auto-generated (`gentle-ai skill-registry refresh --force`) and that a
  rebuild redeploys skills via `pkgs/local-ai-assets`.
