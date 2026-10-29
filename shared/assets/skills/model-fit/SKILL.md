---
name: model-fit
description: >
  Fit ODD and review roles to OpenCode models under hard stability and tool-call gates,
  and iteratively mold the named routing profiles in shared/opencode/providers-base.nix.
  Two modes: full audit (fresh market snapshot across all providers) and re-fit
  (single-role swap driven by observed evidence). Trigger: model fit, odd model,
  provider fit, revisar modelos, auditar providers, modelos opencode, update models,
  providers base, check models, model audit, actualiza modelos, moldear listas,
  swap model, routing fit.
metadata:
  version: "4.4"
---

## Activation Contract

Load when the user asks to fit, audit, review, update, mold, or check OpenCode
provider models or ODD/review role routing. Also load before any change that
touches `shared/opencode/providers-base.nix`.

The active Gentle AI graph uses ODD roles
(orchestrator coordinates, worker implements, explore maps, verify checks). This skill
provides the evidence framework to find which model best fits each role and
to keep the routing lists converging toward stable providers with complete
tool-call behavior.

## Hard Rules

- Every **full audit** starts with a **fresh market snapshot** — never trust
  past BLOCKED/BROKEN/RISKY annotations as current fact; re-verify or expire them.
- Every model assignment must cite a **current data point** (uptime, benchmark,
  retention, issue). No citation, no change.
- Never search engram for stale model decisions; DO read engram for fresh
  phase-misbehavior observations (see Feedback Loop).
- A model never enters a routing list without passing **both evidence gates**.
- Do not run or request live model smoke tests, connectivity prompts, or paid
  tool-call probes as part of model-fit. Use read-only catalogs, documentation,
  current issues, and existing observations; never claim runtime validation
  from those sources.
- Edit only authorized source files; format touched Nix files with
  `nix fmt -- <paths>` and run `nix flake check --no-build`, plus the repository's
  separate affected Home Manager and Darwin evaluations. Record any explicit
  user waiver; never activate hosts as part of validation.
- One re-fit changes one role at a time. Lists evolve; they are not redesigned
  wholesale.
- Secrets rule: agents must NEVER decrypt sops secrets — read ciphertext only.

## Mode Selection

| Situation | Mode |
| --- | --- |
| New provider, new model family, or periodic review of all profiles | `full` |
| One role misbehaved in observed use, or a single role needs a better fit | `re-fit` |
| User reports a blocked/degraded role or asks "why is X slow/broken" | `re-fit` (diagnose first, then swap) |
| User asks to add a whole new profile or rebalance a whole provider family | `full` |

## Auth Method Recognition

Load the OpenCode skill and consult documentation for the installed runtime
version before prescribing provider configuration or authentication commands.
Trace the repository's provider definitions and rendered configuration in
`shared/opencode/runtime-config.nix`; do not copy a legacy configuration shape.

### Method A: API key

Trace declared secret names, environment wiring, and the actual provider
renderer without reading credential values. Relevant source entry points are
`shared/sops.nix`, `shared/opencode.nix`, and
`shared/opencode/providers-base.nix`; verify the current wiring before proposing
changes. Do not assume every provider needs edits in all three files.

### Method B: OAuth or built-in authentication

Verify the selected provider and installed runtime support this route using
current documentation. A routing-only edit must not initiate login or access
stored credentials. Do not infer authentication requirements from a provider
name alone.

### Missing key detection

Cross-reference sops.nix keys, opencode.nix env exports, and provider
definitions. Report missing declarative wiring as a gap, not proof that a
credential is absent or invalid. Never read secret values to resolve it.

## Evidence Gates — non-negotiable, checked in order

### Gate 1: Tool-call completeness

Assess tool-call completeness from current documentation, issues, and existing
observations, without live probes. Assign NOTHING — not even to a light phase —
to a model with an OPEN issue showing any of:

- Stream ends without `finish_reason` (truncation).
- Silent truncation persisted as a complete answer.
- Subagent "gives up", stops mid-task, or hangs awaiting manual "Proceed".
- Crash or misbehavior with concurrent/parallel tool calls.
- Requires a different transport than the provider route uses (e.g. Responses
  API vs Chat Completions / Messages) — verify the route serves the model's
  native transport before assigning.

Historical evidence (verify each fresh — closed ≠ fixed; v1-triage and
60-day-stale bots close issues without published fixes):
muse-spark-1.2-contributor-free (no finish_reason, #43882, resolved as the
`-free` lane variant), silent truncation (#44385), glm-5.1 "gives up too
quickly", minimax-m2.7 TUI crash on concurrent tools (#19463), gpt-oss-120b
stops mid-reasoning (#27210), deepseek-v4-flash cache-billing spike (#42935).

Fresh Go-gateway status verified 2026-10-24 (expire these when re-auditing):
grok-4.6/4.7 ✅ fixed 2026-10-06 (#52971 re-test); kimi-k2.6 🔴 fails at client
load — "Model unavailable" before any HTTP request, never reaches the gateway
(#52971 sweep); minimax-m3 ⚠ session-history tool-call 400 (#32608, bot-closed,
PR #32609 merge unconfirmed, fresh-session workaround); deepseek-v4.1-flash ⚠
DSML tool-call-as-text in long sessions (#50206, opened 2026-10-24);
deepseek-v4-flash and deepseek-v4-flash-vision-exp, space-bunny-free, and
longcat-2.5-preview-free retired from the live gateway after 2026-10-03.

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
sticker price (e.g. gpt-5.6-luna 2x on Go over 272K), 403-for-some-accounts
patterns (#40343). A provider that silently burns quota is not stable.

### Go gateway verification protocol

For the `opencode-go` provider specifically, always verify against the two
sources the catalog drifts between:

- **Live ground truth**: `GET https://opencode.ai/zen/go/v1/models` — the only
  list the runtime actually serves. The docs model list, models.dev, and the
  Console catalog each drift from it independently: `deepseek-v4-flash`
  survived in docs/lists while the gateway had already dropped it; `grok-4.6`,
  `omen-alpha`, `kimi-k2.6`, `minimax-m2.5/m2.7`, `qwen3.6-plus`,
  `qwen3.7-max` appear live without a published price.
- **Per-model endpoint lanes**: `openai /chat/completions`,
  `openai /responses` (grok, gpt-luna, muse-spark),
  `anthropic /messages` (claude-haiku, minimax-m3, qwen3.8/3.7, haiku) plus a
  Google lane. A wrong-route probe returns 500/503/"unavailable" that LOOKS
  like a broken model; #47463 maintainer-confirmed such reports were route
  errors. Classify a suspected outage as valid only if the probe used the
  documented lane. The built-in provider definition selects the lane itself;
  custom providers that hardcode one `baseURL` (like the `nvidia` block)
  serve exactly one lane.
- **Console-side model conditions**: Settings › Privacy blocks paid endpoints
  that train on request data (muse-spark contributors) and blocks
  China-hosted regions by default (DeepSeek needs Global enablement only
  from China). These 403-class failures live outside the repo and cannot be
  fixed in Nix.
- **Session header**: `x-opencode-session` is sent by OpenCode itself;
  missing-session 400s point at third-party harnesses, not the gateway.

## ODD Role Fit — Research Framework

All research uses MCP tools (exa, GitHub, context7) — never guess APIs, model
IDs, quotas, or option paths.

### Step A: Discover active roles

Read the actual rendered graph and profile assignments. Known roles:
`gentle-orchestrator` (coordination and judgment), `gentle-ai-explore` (read-only
mapping), `gentle-ai-worker` (bounded implementation), `gentle-ai-verify`
(read-only checking), `jd-*` (independent judgment/fix roles), and `review-*`
(Go-bound review actors). Route work through ODD roles: gentle-orchestrator, gentle-ai-explore, gentle-ai-worker, gentle-ai-verify, jd-* and review-*.
Profiles in `providers-base.nix` are flat: each `roles` attrset has exactly
these 14 role keys, with no remap layer: `gentle-orchestrator`,
`gentle-ai-explore`, `gentle-ai-worker`, `gentle-ai-verify`, `jd-judge-a`,
`jd-judge-b`, `jd-fix-agent`, `review-readability`, `review-refuter`,
`review-reliability`, `review-resilience`, `review-risk`, `review-validator`,
`neutral`. Editing a profile means editing those keys directly. Preserve every
unrelated fit and last-wins user override. Role names never grant delegation
or delivery permission. The `neutral` slot is a title-provider filler that is
never spawned as a subagent; its model choice is inert and does not consume
evidence budget or trigger swaps.

### Step B: Metrics per role

- Write/edit code → SWE-Bench (Pro/Verified), DeepSWE, Terminal-Bench, agentic
  coding index.
- Reason/plan → GPQA, AIME, intelligence index.
- Explore large repos → long-context retrieval (RULER, MRCR — a model with
  weak 8-needle retrieval is disqualified for explore even if cheap).
- Orchestrator → request headroom/quota, structured tool calls, latency —
  NOT raw reasoning; the best reasoner is often the wrong router.
- Subagent roles → instruction-following, context handling.
- Looping roles weight cost-per-loop; one-shot roles tolerate cost.

### Step C: Evaluate candidates

For each candidate model: benchmarks for Step-B metrics, GitHub issues (model
name + "subagent/hang/tool_call/finish_reason"), uptime + retention at
opencode.ai/data/, real quota cost (credits per M tokens, plan windows),
thrashing signals (a cheap tier that burns 2-3x tokens to fail is not cheap).

### Step D: Document

`Role | Model | Evidence | Why` — every assignment row carries its citation.

## Execution Steps — mode `full`

1. Fresh market snapshot: discover ALL providers from current official
   documentation and the installed runtime's catalog. Locate implementation
   paths in that version's source rather than assuming historical paths.
2. Auth classification (Method A/B); cross-check sops.nix + opencode.nix keys.
3. Model discovery from official docs/API; verify retirement dates and account
   restrictions from current sources rather than reusing historical claims.
4. Status verification: opencode.ai/data/ usage+retention, GitHub issues,
   provider deprecations. Apply Gates 1-2.
5. Fit evaluation per profile following the Research Framework; document the
   `Role | Model | Evidence | Why` table.
6. Update authorized `shared/opencode/providers-base.nix` named profiles;
   report dated evidence without adding code comments unless requested.
   Propose missing auth wiring separately; a model-fit request alone does not
   authorize credential access or authentication setup.
7. Validate using the touched-file formatting and target checks in Hard Rules
   (honor any explicit user waiver and say so in the report).

## Execution Steps — mode `re-fit`

1. Collect the trigger evidence: what failed, which role, which model, which
   host (user report, engram observation, or session log).
2. Re-verify ONLY that role: current status of the incumbent + research 2-4
   candidate replacements against the Step-B metrics for that role. Gates 1-2
    apply; no live model calls are required or requested.
3. Swap one authorized role assignment; report dated evidence explaining what
   failed and why the replacement. Add code comments only when requested.
   The repo ships without strategy comments by user decision (2026-10-23);
   do not reintroduce them.
4. Validate as in mode `full`; report the one-line delta.

## Feedback Loop

- After each ODD run, capture to engram: role, model, host, misbehavior
  (truncation, give-up, thrash, quota burn) or notable success. Scope: project.
- A captured misbehavior is the trigger for a `re-fit` on that phase — do not
  wait for a periodic audit.
- Diagnose before swapping: a phase failing repeatedly may be a context-size
  problem (use a model with bigger retrieval, not a smarter one) or a
  transport problem (Gate 1), not a capability problem.

## Agent Biases

This skill biases the agent's decisions as follows:

1. **Stability > peak quality.** A slightly weaker model that never truncates
   tool calls beats a brilliant flaky one in looping roles (gentle-orchestrator,
   gentle-ai-worker). Reserve strong-but-risky models for once-shot review roles.
2. **No citation, no change.** Assignments without a current data point are
   reverted, not debated. Vendor benchmarks are cross-checked against
   independent data and watched for thrashing.
3. **Cheap volume, scarce judgment.** Tool-loop and worker and verification roles take the
   cheapest tier that passes the gates; quota reserved for review roles.
   Moving a volume phase onto scarce quota needs explicit cost justification.
4. **Minimal, reversible changes.** One role per re-fit; dated evidence;
   never delete a working annotation without replacing it with fresh evidence.
5. **Evidence before trusting.** Re-check catalog IDs, current issues, and
   provider documentation, including for the current favorite. Distinguish
   source-backed assessment from untested runtime behavior.

## Output Contract

- Updated `shared/opencode/providers-base.nix` named profiles with dated,
  cited evidence in the report (this repo's real artifact — NOT generic
  full/medium/light/free tier lists).
- Fit evaluation table: `Role | Model | Evidence | Why` for every changed
  assignment.
- Gap report: providers with missing keys or missing definitions.
- Fresh status annotations (✅/⚠️/🔴) with current issue references; expired
  annotations explicitly marked as re-verified or removed.
- Feedback-loop record saved to engram (mode, swaps, rationale).
- Evidence limitations: state that live model tests were not run; do not
  present source-backed tool-call assessment as a completed runtime test.
- Validation status: touched-file `nix fmt -- <paths>`,
  `nix flake check --no-build`, and applicable target evaluation results, or
  the user's explicit waiver noted.
- Registry note: after a rename/add, remind that `.atl/skill-registry.md` is
  auto-generated (`gentle-ai skill-registry refresh --force`) and that a
  rebuild redeploys skills via `pkgs/local-ai-assets`.
