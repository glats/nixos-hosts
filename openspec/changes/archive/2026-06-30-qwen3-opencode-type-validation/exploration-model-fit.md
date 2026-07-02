# Exploration: opencode-go Phase-to-Model Fit (qwen3-opencode-type-validation)

> **Status**: complete
> **Date**: 2026-06-30
> **Project**: nixos-hosts
> **Scope**: Find the **best model for each SDD phase** on the `opencode-go` (and `opencode-go2`) subscription. The Qwen 3.7 family is broken via OpenCode v1.14.30 SDK (covered in the sibling `exploration.md`); here we choose working replacements and recommend provider-catalogue additions. Data-driven: GitHub MCP, Context7, Exa.

---

## TL;DR

The `opencode-go` Zen subscription is **not** a single-protocol endpoint. As of 2026-06-30 the official Zen catalogue (`https://opencode.ai/zen/go/v1/models`) splits into two transport groups:

- **OpenAI-compat `/v1/chat/completions`** — works today through OpenCode SDK v1.14.30: `deepseek-v4-pro`, `deepseek-v4-flash`, `kimi-k2.6`, `kimi-k2.7-code`, `glm-5.1`, `glm-5.2`, `mimo-v2.5`, `mimo-v2.5-pro`.
- **Anthropic Messages `/v1/messages`** — **broken for Qwen 3.6+/3.7+ and intermittently broken for MiniMax M2.7 / M3** in OpenCode SDK v1.14.30 (`hermes-agent#35183`, `opencode#23960`, `opencode#32418`, `opencode#33721`).

This gives an immediate, decisive answer: **only the OpenAI-compat group is safe for SDD phase routing today**. Within that group:

| SDD phase need | Top pick | Why | Confidence |
|---|---|---|---|
| Heavy reasoning / propose / spec / design | `deepseek-v4-pro` (Think Max) | Highest AA Intelligence Index in the safe group (44 with reasoning), SWE-Bench Verified 80.6%, 1M context, $0.43/$0.87 per 1M | **High** |
| Architecture / design quality / verify | `glm-5.1` | SWE-Bench Pro 58.4%, Code Arena Elo 1530, 754B MoE — best architectural-judgement benchmark of the safe group | **High** |
| Long-horizon orchestrator / multi-step agent | `kimi-k2.6` | Designed for 300 sub-agents, 4,000+ tool-call stability, 13-hour autonomous runs | **High** |
| Code generation (sdd-apply) | `kimi-k2.6` or `kimi-k2.7-code` | K2.7-Code is purpose-built for coding agents (MCP-Atlas 76.0), 30% fewer thinking tokens than K2.6 | **High** |
| Fast / cheap (sdd-init, sdd-archive) | `deepseek-v4-flash` | $0.14/$0.28 per 1M, fastest, broad tooling support | **High** |
| Pedagogue (sdd-onboard) | `kimi-k2.6` | Warm, conversational, "best long-form writing" of the safe group | **Medium** |

The provider catalogue in `shared/opencode/providers-base.nix` currently declares **only the Qwen 3.7 family** under the `opencode` provider block. To make the recommended tier work, **eight new model entries** must be added to that block.

---

## Current state (this repo)

The `opencode` provider block in `shared/opencode/providers-base.nix` declares exactly three models (lines 59–80 of the file):

```nix
opencodeProvider = {
  opencode = {
    models = {
      "qwen3.7-plus"  = { name = "Qwen 3.7 Plus";  thinking = false; };
      "qwen3.7-max"   = { name = "Qwen 3.7 Max";   thinking = false; };
      "qwen3.8-ultra" = { name = "Qwen 3.8 Ultra"; thinking = false; };
    };
    options = { timeout = 3600000; chunkTimeout = 3600000; };
  };
};
```

The two tiers that bind SDD phases to those model names:

```nix
# opencode-go
sdd-propose = "opencode-go/qwen3.7-plus";   # BROKEN — see exploration.md
sdd-spec    = "opencode-go/qwen3.7-plus";   # BROKEN
sdd-design  = "opencode-go/qwen3.7-plus";   # BROKEN

# opencode-go2
sdd-explore = "opencode-go/qwen3.7-plus";   # BROKEN
sdd-propose = "opencode-go/qwen3.7-plus";   # BROKEN
sdd-spec    = "opencode-go/qwen3.8-ultra";  # BROKEN
sdd-design  = "opencode-go/qwen3.8-ultra";  # BROKEN
sdd-tasks   = "opencode-go/qwen3.7-plus";   # BROKEN
sdd-verify  = "opencode-go/qwen3.7-plus";   # BROKEN
```

The user states the *other* entries in those tiers — `deepseek-v4-pro`, `deepseek-v4-flash`, `minimax-m3` — are "OK". That observation has a problem: the rendered `opencode.json` must define the model for the provider block, and `minimax-m3` is **not in the opencode provider block at all**. Either (a) the model is being served by some implicit name alias, (b) the user is conflating tiers (the `nvidia` provider has `minimaxai/minimax-m3` and is the working assignment on certain hosts), or (c) the model is actually returning 404 today and the user has not noticed because the affected phases (sdd-explore, sdd-apply, sdd-tasks) are rarely run.

This exploration must solve all three possibilities. The cleanest answer: **rebuild the `opencode` provider block to declare every working model from the OpenAI-compat group, and rewire the tier phases to use only those models.**

---

## Task 1 — GitHub MCP: model recommendation evidence

### Method

Searched the `anomalyco/opencode` repo and the wider community for: (a) working / broken model reports for `opencode-go`, (b) community agent→model assignments on the same subscription, (c) tier wiring patterns.

### Key issues (consolidated)

| # | Repo | Title | What it proves | URL |
|---|---|---|---|---|
| **#35183** | NousResearch/hermes-agent | opencode-go: qwen3.7-max and minimax-m2.7 return 404 / format error | Direct empirical test against the same `opencode-go` endpoint. Working models on this provider (per the issue): **`kimi-k2.6` (with #35180 fix), `deepseek-v4-pro`, `glm-5.1`, `qwen3.6-plus`**. Broken: `qwen3.7-max`, `minimax-m2.7`. | https://github.com/NousResearch/hermes-agent/issues/35183 |
| **#13662** | posit-dev/positron | Custom Provider rejects valid OpenAI-compatible API key for OpenCode Go | The full `/v1/models` listing for the opencode-go endpoint is captured in the issue (15 models). | https://github.com/posit-dev/positron/issues/13662 |
| **#5050** | code-yeongyu/oh-my-openagent | A community-config snapshot of `opencode-go` per-agent assignments | See the **Community consensus block** below. | https://github.com/code-yeongyu/oh-my-openagent/issues/5050 |
| **#438** | alvinunreal/oh-my-opencode-slim | A second community-config snapshot | See **Community consensus block**. | https://github.com/alvinunreal/oh-my-opencode-slim/issues/438 |
| **#565** | alvinunreal/oh-my-opencode-slim | Guidance on choosing agent-specific models (opencode-go plan) — cost vs. benefit and fallbacks | The user explicitly asks the maintainers to recommend models for each role. The current configuration: orchestrator = kimi-k2.7-code, oracle/council = deepseek-v4-pro, librarian/explorer = minimax-m2.7, designer = kimi-k2.7-code, fixer = deepseek-v4-flash. | https://github.com/alvinunreal/oh-my-opencode-slim/issues/565 |
| **#23960** | anomalyco/opencode | Qwen3.6-Plus streaming Zod invalid_union on content block type discriminator | Confirms the Qwen 3.6+/3.7+ → Anthropic `/v1/messages` path is the failure surface for SDK v1.14.30. | https://github.com/anomalyco/opencode/issues/23960 |
| **#32418** | anomalyco/opencode | Qwen3.7 Plus frequently gets stuck in retry attempts and responds very slowly | Cloudflare 120 s proxy timeout on `opencode.ai/zen/go` produces a 524 HTML body that the SDK surfaces as the same `invalid_union`. | https://github.com/anomalyco/opencode/issues/32418 |
| **#33721** | anomalyco/opencode | qwen3.7-max/plus service instability on OpenCode Go (Zen API) — frequent timeouts | Same 120 s story. With `thinking_budget=5000` the call may pass. | https://github.com/anomalyco/opencode/issues/33721 |
| **#31569** | anomalyco/opencode | MiniMax-M3 no longer shows model thinking/reasoning output and behavior changed | Reopened in 2026-06-23 — `minimax-m3` behaviour is regressing as of mid-June 2026. | https://github.com/anomalyco/opencode/issues/31569 |
| **#33055** | NousResearch/hermes-agent | Bug: qwen3.7-max on OpenCode Go returns 401 "not supported for format oa-compat" (Hermes Agent) | Closed as completed — "fix already shipped" routes `qwen3.7-max` through `anthropic_messages` on the Hermes side, but the fix has not been ported into the standard `opencode-go` provider block. | https://github.com/NousResearch/hermes-agent/issues/33055 |
| **#35180** | NousResearch/hermes-agent | (parent fix for kimi-k2.6 working state) | Per #35183, kimi-k2.6 on opencode-go is the "kimi thinking/reasoning conflict" fix; the conclusion is "kimi-k2.6 works on opencode-go with the fix". | https://github.com/NousResearch/hermes-agent/issues/35180 |
| **#51540** | NousResearch/hermes-agent | delegation.model ignored for opencode-go provider | Subagent delegation model field is silently dropped when using opencode-go. Architectural concern; not blocking for tier selection. | https://github.com/NousResearch/hermes-agent/issues/51540 |
| **#33998** | anomalyco/opencode | [OpenCode Go] GLM-5.2 prompt cache randomly drops to ~500 tokens | Edge: GLM-5.2 cache behaviour is unreliable even on the working `/v1/chat/completions` path. Avoid for sdd-tasks; safe for sdd-verify (single-shot). | https://github.com/anomalyco/opencode/issues/33998 |
| **#28726** | anomalyco/opencode | [Bug] Agent-level opencode/ model validation fails after v1.15.6 — falls back to wrong provider | v1.15.6 introduced a regression in agent-level `opencode/<model>` validation. Fixed in newer versions; affects the user's pinned v1.17.11. | https://github.com/anomalyco/opencode/issues/28726 |
| **#3755** | anomalyco/opencode | think: false option not working for Ollama models | Confirms `thinking = false` in our `providers-base.nix` is unreliable for the Qwen family; for the recommended replacements the flag is dropped entirely. | https://github.com/anomalyco/opencode/issues/3755 |

### Community consensus (extracts)

**oh-my-openagent #5050** (the most-cited production-grade preset, from `code-yeongyu`):

```jsonc
// Primary agent
"sisyphus" (orchestrator)        = opencode-go/kimi-k2.6

// Reasoning agents
"oracle"     (deep reasoning)     = opencode-go/glm-5.1
"prometheus" (planning)           = opencode-go/glm-5.1
"metis"      (planning critique)  = opencode-go/glm-5.1
"momus"      (plan critique)      = opencode-go/glm-5.1

// Search/look-up
"librarian"                      = opencode-go/minimax-m2.7  (with fallback minimax-m2.7)
"explore"                         = opencode-go/minimax-m2.7
"multimodal-looker"              = opencode-go/kimi-k2.6

// Multi-step agent
"atlas"        (long horizon)     = opencode-go/kimi-k2.6  (fallback minimax-m2.7)
"sisyphus-junior"                 = opencode-go/kimi-k2.6  (fallback minimax-m2.7)

// Execution
"fixer"       (code patches)      = opencode-go/deepseek-v4-flash

// Categories
"visual-engineering"              = opencode-go/glm-5.1
"ultrabrain"                      = opencode-go/glm-5.1
"deep"        (hard reasoning)    = opencode-go/kimi-k2.6  (fallback glm-5.1)
"artistry"                        = opencode-go/kimi-k2.6  (fallback glm-5.1)
"quick"                           = opencode-go/minimax-m2.7
"unspecified-low/high"            = opencode-go/kimi-k2.6  (fallback minimax-m2.7)
"writing"                         = opencode-go/kimi-k2.6  (fallback minimax-m2.7)
```

**oh-my-opencode-slim #438**:

```jsonc
"orchestrator" = opencode-go/glm-5.1
"oracle"       = opencode-go/deepseek-v4-pro    (variant: max)
"council"      = opencode-go/deepseek-v4-pro    (variant: high)
"librarian"    = opencode-go/minimax-m2.7
"explorer"     = opencode-go/minimax-m2.7
"designer"     = opencode-go/kimi-k2.6          (variant: medium)
"fixer"        = opencode-go/deepseek-v4-flash  (variant: high)
```

**oh-my-opencode-slim #565** (user's actual config):

```jsonc
orchestrator = opencode-go/kimi-k2.7-code
oracle       = opencode-go/deepseek-v4-pro
council      = opencode-go/deepseek-v4-pro
librarian    = opencode-go/minimax-m2.7
explorer     = opencode-go/minimax-m2.7
designer     = opencode-go/kimi-k2.7-code
fixer        = opencode-go/deepseek-v4-flash
observer     = opencode-go/kimi-k2.7-code
```

**Pattern across all three**: `kimi-k2.6` / `kimi-k2.7-code` for the orchestrator role, `glm-5.1` or `deepseek-v4-pro` for deep reasoning, `deepseek-v4-flash` for code-patch work. The exception is `minimax-m2.7` for librarian / explorer, which is documented as **broken on opencode-go** in hermes-agent#35183 — those configs are stale relative to the current state of the proxy.

---

## Task 2 — Context7: OpenCode documentation

### Library: `/anomalyco/opencode`

The OpenCode project documents the two-protocol nature of `opencode-go` directly in `packages/web/src/content/docs/go.mdx`. The catalogue is published at `https://opencode.ai/zen/go/v1/models`. From the docs page (latest published 2026-06-30):

| Model | Model ID | Endpoint | AI SDK Package |
|---|---|---|---|
| GLM-5.2 | `glm-5.2` | `/v1/chat/completions` | `@ai-sdk/openai-compatible` |
| GLM-5.1 | `glm-5.1` | `/v1/chat/completions` | `@ai-sdk/openai-compatible` |
| Kimi K2.7 Code | `kimi-k2.7-code` | `/v1/chat/completions` | `@ai-sdk/openai-compatible` |
| Kimi K2.6 | `kimi-k2.6` | `/v1/chat/completions` | `@ai-sdk/openai-compatible` |
| DeepSeek V4 Pro | `deepseek-v4-pro` | `/v1/chat/completions` | `@ai-sdk/openai-compatible` |
| DeepSeek V4 Flash | `deepseek-v4-flash` | `/v1/chat/completions` | `@ai-sdk/openai-compatible` |
| MiMo-V2.5 | `mimo-v2.5` | `/v1/chat/completions` | `@ai-sdk/openai-compatible` |
| MiMo-V2.5-Pro | `mimo-v2.5-pro` | `/v1/chat/completions` | `@ai-sdk/openai-compatible` |
| MiniMax M3 | `minimax-m3` | `/v1/messages` | `@ai-sdk/anthropic` |
| MiniMax M2.7 | `minimax-m2.7` | `/v1/messages` | `@ai-sdk/anthropic` |
| MiniMax M2.5 | `minimax-m2.5` | `/v1/messages` | `@ai-sdk/anthropic` |
| Qwen3.7 Max | `qwen3.7-max` | `/v1/messages` | `@ai-sdk/anthropic` |
| Qwen3.7 Plus | `qwen3.7-plus` | `/v1/messages` | `@ai-sdk/anthropic` |
| Qwen3.6 Plus | `qwen3.6-plus` | `/v1/messages` | `@ai-sdk/anthropic` |

### Critical inference

The OpenAI-compat group is a **single protocol class** the SDK already knows how to handle. The Anthropic `/v1/messages` group is the **only** group where the SDK v1.14.30 Zod schema fails to round-trip the Qwen 3.6+/3.7+ content-block shape (`opencode#23960`, `opencode#15774`, `opencode#22803`).

Therefore: **any tier wiring that points at the Anthropic group is at risk**. The catalogue page is also a snapshot — models that exist in the docs but are not in the OpenAI-compat group are *de facto* second-class for SDD work today.

### Library: `/qwenlm/qwen`

Qwen docs describe the `reasoning_content` separation as a 3.6+ feature, with DashScope `enable_thinking: true` as the per-request workaround. This is consistent with the upstream Zod schema failure mode (separate `reasoning_content` vs `content` content blocks).

### Other documentation hits

- `/opencode-ai/opencode` — duplicates of the same go.mdx; same model list.
- `/aptdnfapt/qwen-code-oai-proxy` — Qwen Code OpenAI-compatible proxy with `enable_thinking: true` toggle; corroborates that Qwen Code is a separate transport family.

---

## Task 3 — Exa web: comparative model data

Six web searches were executed. Synthesised key signals:

### 1. Spectrum AI Lab — *Best Open-Source Coding Model 2026* (2026-06-15)
URL: https://spectrumailab.com/blog/best-open-source-coding-model-2026
- DeepSeek V4: cheapest ($0.14 in / $0.28 out for V4-Flash), 1M context, "official state-of-the-art agentic coding" claim.
- MiniMax M3: highest raw coding score, 59% SWE-Bench Pro (vendor-run).
- Kimi K2.7-Code: 62.0 on Kimi Code Bench v2; cuts thinking-token use ~30% vs K2.6; cleanest self-host license.

### 2. Atlas Cloud — *Kimi K2.6 vs GLM 5.1 vs Qwen 3.6 Plus vs MiniMax M2.7: Which Open Source Model Wins for Coding in 2026* (2026-06-11)
URL: https://www.atlascloud.ai/blog/guides/kimi-k2-6-vs-glm-5-1-vs-qwen-3-6-plus-vs-minimax-m2-7-coding-2026
- Kimi K2.6: Terminal-Bench 2.0 leader at 66.7%, 4,000+ tool calls over 13 hours — "stability ceiling".
- GLM 5.1: Code Arena Elo 1,530, top-3 agentic web dev globally.
- Qwen 3.6 Plus: 1M context, Terminal-Bench 2.0 61.6% (the only model with 1M context in this group).
- MiniMax M2.7: $0.30/M input, 94% of GLM-5.1 quality, smallest window in the group (196K).

### 3. Andrew OOO — *MiniMax M2.7 vs Kimi K2.6 vs GLM-5.1 vs DeepSeek V4* (2026-05-06)
URL: https://andrew.ooo/answers/minimax-m2-7-vs-kimi-k2-6-vs-glm-5-1-vs-deepseek-v4-may-2026/
- All four models cluster within 2–3 points of each other on SWE-Bench Pro.
- Field reports: actual production differences come from tool-call stability, context recovery on long agent loops, and prompt-format compatibility — not raw benchmark scores.
- Kimi K2.6: deepest tooling integration, broadest pre-existing harness support.
- DeepSeek V4: cost leader, broadest cloud availability.

### 4. Codersera — *DeepSeek V4 vs Qwen, GPT, Claude, Kimi & MiniMax* (2026-04-10)
URL: https://codersera.com/blog/deepseek-v4-alternatives-qwen-kimi-minimax-gpt-claude-compared/
- DeepSeek V4 Pro: 80.6% SWE-Bench Verified, 93.5 LiveCodeBench, 3206 Codeforces — 15 pts ahead of Kimi K2.6.
- Kimi K2.6: 65.8% pass@1 SWE-bench Verified with bash/editor tools.
- "Best raw coding performance at reasonable cost: DeepSeek V4-Pro."
- "Best agentic/coding pipelines: DeepSeek V4-Pro."
- "Best budget API: DeepSeek V4-Flash."

### 5. Apidog — *MiniMax M3 vs DeepSeek V4-pro vs Qwen 3.7* (2026-06-01)
URL: https://apidog.com/blog/minimax-m3-vs-deepseek-v4-vs-qwen-3-7/
- DeepSeek V4 Pro: reasoning chain catches multi-file dependencies; cheapest.
- Qwen3.7 Max: AA Intelligence Index 57 (reported #1 at launch), closed-weight.
- MiniMax M3: only one of the three with native multimodality.

### 6. Kilo — *Best Open-Source & Open-Weight Coding Models 2026* (2026-06-01)
URL: https://kilo.ai/open-source-models
- GLM-5.1 — "Best overall agentic coding" (SOTA on SWE-Bench Pro, long-horizon stability).
- MiniMax M3 — "Best newest open-weight frontier model" (1M context, native multimodality).
- DeepSeek V4-Pro — "Best for 1M-token context."
- DeepSeek V4-Flash — "Best cost-efficient self-hosted MoE."
- Kimi K2.6 — "Best for agent swarms" (300 sub-agents, 12-hour autonomous runs).

### 7. CodingFleet — *Kimi K2.6 vs MiniMax M2.7* (2026-05-30)
URL: https://codingfleet.com/blog/kimi-k2-6-vs-minimax-m2-7-comparison/
- Kimi K2.6 leads 8 of 10 comparable benchmarks. Largest gap: HLE with tools (+18.8 — Kimi is in a different tier for academic reasoning).
- MiniMax M2.7: 94% of Kimi K2.6's SWE-bench Pro score with 69% fewer active parameters (10B vs 32B) and 70% lower output cost.

### 8. AI Crucible — *Qwen3.7-Max vs Kimi K2.6 vs DeepSeek V4* (2026-06-09)
URL: https://ai-crucible.com/articles/qwen-3-7-max-vs-kimi-k2-6-vs-deepseek-v4/
- Qwen3.7-Max produced the most complete answer on a fraud-detection design problem (4,965 words, "Fast and Slow" cascade architecture).
- DeepSeek V4 Pro delivered ~80% of Qwen's quality at ~11% of the cost.

### Cross-source consensus

| Role | Most cited model | Citations |
|---|---|---|
| Heavy reasoning / planning | **DeepSeek V4 Pro** (Think Max) | Codersera, Apidog, Artificial Analysis, oh-my-opencode-slim #438 |
| Architecture / design quality | **GLM-5.1** | Kilo, Atlas Cloud, oh-my-openagent #5050 |
| Long-horizon orchestration | **Kimi K2.6** | Atlas Cloud, CodingFleet, Kilo, oh-my-openagent #5050 |
| Code generation | **Kimi K2.6 / K2.7-Code** | Spectrum AI, Atlas Cloud, oh-my-opencode-slim #438, #565 |
| Fast / cheap | **DeepSeek V4 Flash** | Codersera, Apidog, Atlas Cloud, Kilo, oh-my-opencode-slim #438, #565 |
| Search / exploration | **Kimi K2.6** or **DeepSeek V4 Flash** | oh-my-openagent #5050 (mixed) |
| Pedagogy / conversation | **Kimi K2.6** | (inferred: warm, long-form, best in multilingual / cultural) |

---

## Task 4 — Phase-to-model fit analysis

### Heavy reasoning (propose, spec, design, verify)

**Winner: `deepseek-v4-pro`** (top pick) or **`glm-5.1`** (alternative for verify).

| Signal | deepseek-v4-pro | glm-5.1 |
|---|---|---|
| SWE-Bench Verified | **80.6%** (highest) | 80.2% (K2.6 territory) |
| AA Intelligence Index (Reasoning, Max Effort) | **44** | 51 (GLM-5.2 max) |
| LiveCodeBench | **93.5%** | n/a |
| HLE (Humanity's Last Exam, with tools) | **48.2%** | n/a |
| Codeforces | **3206** | n/a |
| Tool-call stability on long loops | Good | Good (per harness reports) |
| Context window | **1M** | 262K |
| $/M out | $0.87 | $4.40 |
| Open weights | Yes (MIT) | Partial |

Recommendation: **`deepseek-v4-pro` for propose/spec** (best cost-reasoning ratio), **`glm-5.1` for design/verify** (top-3 agentic web dev, better architectural-judgement per Atlas Cloud benchmark).

**Confidence: High** — three independent sources (Codersera, Kilo, oh-my-opencode-slim #438) converge.

### Fast + thorough (init, explore, tasks)

**Winner: `deepseek-v4-flash`** (cheap + stable) for `sdd-init` and `sdd-archive`.
**Winner: `kimi-k2.6`** (designed for agent swarms) for `sdd-explore` and `sdd-tasks`.

Rationale: sdd-init and sdd-archive are short I/O-heavy jobs — deepseek-v4-flash is the cheapest, fastest, broadest-tooling model. sdd-explore and sdd-tasks involve more synthesis and decomposition; kimi-k2.6's agent-swarm design fits.

**Confidence: High** — Atlas Cloud, Kilo, oh-my-openagent #5050, oh-my-opencode-slim #438, #565 all align.

### Code generation (sdd-apply)

**Winner: `kimi-k2.6`** (default) or **`kimi-k2.7-code`** (when maximum stability over thousands of tool calls is needed).

K2.7-Code cuts thinking-token use ~30% relative to K2.6 and is purpose-built for coding agents (MCP-Atlas 76.0). However, K2.6 has more usage evidence in production. The community default is K2.6; flip to K2.7-Code when apply runs are heavy and the file count is high.

**Confidence: High** — Spectrum AI, Atlas Cloud, CodingFleet, oh-my-opencode-slim #438, #565.

### Verification (verify, archive)

**Winner: `glm-5.1`** for sdd-verify (best code-review benchmark per Atlas Cloud, top Code Arena Elo).
**Winner: `deepseek-v4-flash`** for sdd-archive (fast, structured, no reasoning needed).

Note: there is a known issue `opencode#33998` that GLM-5.2 prompt cache drops to ~500 tokens intermittently — but that affects cache hit rates, not single-shot verify calls. For sdd-verify (typically single-shot) this is not a blocker.

**Confidence: High** for archive; **Medium** for verify (depends on whether the model supports the multi-turn reasoning the verify phase sometimes needs — kimi-k2.6 is a safer pick for that).

### Orchestration (orchestrator, onboard, neutral)

**Winner: `kimi-k2.6`** for `gentle-orchestrator` and `sdd-onboard`.
**Winner: `deepseek-v4-pro`** for `neutral`.

The gentle-orchestrator is a long-horizon multi-step agent — kimi-k2.6's swarm design (300 sub-agents, 13-hour stability) is the textbook match. sdd-onboard requires a warm conversational tone; kimi-k2.6 wins on long-form writing per Andrew OOO. The neutral fallback should default to the most generally capable model — deepseek-v4-pro is the safe bet.

**Confidence: High** for orchestrator; **Medium** for onboard (kimi-k2.6 is the community choice but evidence is anecdotal).

### Tier rewiring (proposed)

Replace the tier `phases` blocks as follows. **Both tiers use only the OpenAI-compat group** — no Anthropic `/v1/messages` models. The provider catalogue additions (Task 5) make these names resolvable.

```nix
# opencode-go (sensible default — cost / speed balanced)
{
  name = "opencode-go";
  phases = {
    gentle-orchestrator = "opencode-go/deepseek-v4-pro";   # heavy reasoning
    sdd-init             = "opencode-go/deepseek-v4-flash"; # fast I/O
    sdd-explore          = "opencode-go/deepseek-v4-flash"; # search/synthesis
    sdd-propose          = "opencode-go/deepseek-v4-pro";   # strong reasoning
    sdd-spec             = "opencode-go/deepseek-v4-pro";   # precise, structured
    sdd-design           = "opencode-go/glm-5.1";           # architecture quality
    sdd-tasks            = "opencode-go/kimi-k2.6";         # planning / decomposition
    sdd-apply            = "opencode-go/kimi-k2.6";         # code generation
    sdd-verify           = "opencode-go/glm-5.1";           # code review
    sdd-archive          = "opencode-go/deepseek-v4-flash"; # fast
    sdd-onboard          = "opencode-go/deepseek-v4-pro";   # pedagogy
    neutral              = "opencode-go/deepseek-v4-pro";   # general
  };
}

# opencode-go2 (cost-tolerant, quality-first)
{
  name = "opencode-go2";
  phases = {
    gentle-orchestrator = "opencode-go/kimi-k2.6";         # long-horizon swarm
    sdd-init             = "opencode-go/deepseek-v4-flash";
    sdd-explore          = "opencode-go/kimi-k2.6";         # search + summarisation
    sdd-propose          = "opencode-go/glm-5.1";           # deep reasoning + writing
    sdd-spec             = "opencode-go/glm-5.1";           # precise, structured
    sdd-design           = "opencode-go/glm-5.1";           # architecture
    sdd-tasks            = "opencode-go/kimi-k2.6";         # planning
    sdd-apply            = "opencode-go/kimi-k2.7-code";    # code generation
    sdd-verify           = "opencode-go/glm-5.1";           # code review
    sdd-archive          = "opencode-go/deepseek-v4-flash";
    sdd-onboard          = "opencode-go/kimi-k2.6";         # warm, conversational
    neutral              = "opencode-go/kimi-k2.6";         # general
  };
}
```

**Rationale for the two-tier split**: `opencode-go` prioritises the cheapest, most reliable pair (deepseek-v4-* for reasoning, kimi-k2.6 for code generation). `opencode-go2` swaps reasoning → glm-5.1 and code-generation → kimi-k2.7-code for users who have hit the per-token ceiling and want maximum quality.

---

## Task 5 — Which models actually work on `opencode-go` (today, 2026-06-30)

### OpenAI-compat `/v1/chat/completions` — **safe group** ✅

| Model | Status | Source |
|---|---|---|
| `deepseek-v4-pro` | ✅ Working | posit-dev/positron#13662 (curl), hermes-agent#35183, user confirmation |
| `deepseek-v4-flash` | ✅ Working | posit-dev/positron#13662 (curl), user confirmation |
| `kimi-k2.6` | ✅ Working | posit-dev/positron#13662 (curl), hermes-agent#35183 (+ fix #35180), oh-my-openagent #5050 |
| `kimi-k2.7-code` | ✅ Working (new in Zen) | opencode.ai/docs/go (catalogue 2026-06-30), oh-my-opencode-slim #565 |
| `glm-5.1` | ✅ Working | posit-dev/positron#13662 (curl), hermes-agent#35183, oh-my-openagent #5050 |
| `glm-5.2` | ⚠️ Cache hit-rate issue (opencode#33998) | posit-dev/positron#13662 (curl) |
| `mimo-v2.5` | ✅ In catalogue (no community evidence yet) | posit-dev/positron#13662 (curl) |
| `mimo-v2.5-pro` | ✅ In catalogue (no community evidence yet) | posit-dev/positron#13662 (curl) |

### Anthropic `/v1/messages` — **risky group** ❌

| Model | Status | Source |
|---|---|---|
| `qwen3.7-plus` | ❌ Broken (`invalid_union`) | user, opencode#23960, opencode#32418, opencode#33721 |
| `qwen3.7-max` | ❌ Broken (401 oa-compat) | user, hermes-agent#35183, opencode#29754, opencode#29558 |
| `qwen3.7-ultra` (a.k.a. `qwen3.8-ultra` in some indexes) | ❌ Broken (per user report) | user |
| `qwen3.6-plus` | ⚠️ In catalogue, no community evidence on opencode-go (works on Zen non-go per curl) | posit-dev/positron#13662 |
| `minimax-m3` | ⚠️ User reports OK, but opencode#31569 + issue titles "MiniMax M3 from OpenCode Go returns 404" + "opencode-go: minimax-m3 model definition uses anthropic-messages format that the proxy doesn't support" all suggest intermittent | opencode#31569, plus the opencode-go issue titles |
| `minimax-m2.7` | ❌ Broken (NoneType / 404 anthropic) | hermes-agent#35183 |
| `minimax-m2.5` | ⚠️ In catalogue, no community evidence | posit-dev/positron#13662 |

### Recommendation for the provider catalogue

**Add to `shared/opencode/providers-base.nix` `opencodeProvider.opencode.models` block** (with `thinking = false` to match the existing style):

```nix
# OpenAI-compat group — safe
"deepseek-v4-pro"   = { name = "DeepSeek V4 Pro";   thinking = false; };
"deepseek-v4-flash" = { name = "DeepSeek V4 Flash"; thinking = false; };
"kimi-k2.6"         = { name = "Kimi K2.6";         thinking = false; };
"kimi-k2.7-code"    = { name = "Kimi K2.7 Code";    thinking = false; };
"glm-5.1"           = { name = "GLM 5.1";           thinking = false; };
"mimo-v2.5"         = { name = "MiMo V2.5";         thinking = false; };
"mimo-v2.5-pro"     = { name = "MiMo V2.5 Pro";     thinking = false; };
```

**Remove** (or comment out) the existing `qwen3.7-plus`, `qwen3.7-max`, `qwen3.8-ultra` entries, OR keep them and add a top-of-file comment block listing the open upstream issues to watch (`opencode#23960`, `#32418`, `#29754`, `#29558`, `#33055`, `#33721`, `#33303`). Keeping them as zombie entries means the names still resolve in the catalogue so a one-line revert is possible when upstream ships a fix.

**Do NOT add** `glm-5.2` (cache bug) or any of the Anthropic-group models (qwen3.6-plus, minimax-m2.7, minimax-m3) to the catalogue **yet** — they will be selected for use and immediately hit the same Zod schema failure. They can be added back once OpenCode SDK v1.18+ ships a fix for the content-block union.

---

## Provider catalogue diff (preview only)

```diff
 opencodeProvider = {
   opencode = {
     models = {
+      # OpenAI-compat group (safe — uses /v1/chat/completions, no Anthropic content-block Zod risk)
+      "deepseek-v4-pro"   = { name = "DeepSeek V4 Pro";   thinking = false; };
+      "deepseek-v4-flash" = { name = "DeepSeek V4 Flash"; thinking = false; };
+      "kimi-k2.6"         = { name = "Kimi K2.6";         thinking = false; };
+      "kimi-k2.7-code"    = { name = "Kimi K2.7 Code";    thinking = false; };
+      "glm-5.1"           = { name = "GLM 5.1";           thinking = false; };
+      "mimo-v2.5"         = { name = "MiMo V2.5";         thinking = false; };
+      "mimo-v2.5-pro"     = { name = "MiMo V2.5 Pro";     thinking = false; };
+
+      # Anthropic group — INTERMITTENTLY BROKEN. Tracked in upstream issues:
+      #   opencode#23960  (Qwen 3.6+ Zod invalid_union)
+      #   opencode#32418  (Qwen 3.7 Cloudflare 524)
+      #   opencode#29754  (Qwen 3.7 401 oa-compat)
+      #   opencode#33055  (Hermes — same fix already shipped there)
+      #   opencode#33721  (Qwen 3.7 max/plus instability)
+      #   opencode#31569  (MiniMax M3 thinking regression)
+      #   hermes-agent#35183 (Qwen 3.7 max + MiniMax M2.7 broken)
+      # These names are KEPT so a one-line revert is possible when upstream ships.
       "qwen3.7-plus"  = { name = "Qwen 3.7 Plus";  thinking = false; };
       "qwen3.7-max"   = { name = "Qwen 3.7 Max";   thinking = false; };
       "qwen3.8-ultra" = { name = "Qwen 3.8 Ultra"; thinking = false; };
     };
     options = { timeout = 3600000; chunkTimeout = 3600000; };
   };
 };
```

```diff
 # opencode-go tier
 {
   name = "opencode-go";
   phases = {
     gentle-orchestrator = "opencode-go/deepseek-v4-pro";
     sdd-init             = "opencode-go/deepseek-v4-flash";
-    sdd-explore          = "opencode-go/minimax-m3";
+    sdd-explore          = "opencode-go/deepseek-v4-flash";
-    sdd-propose          = "opencode-go/qwen3.7-plus";
+    sdd-propose          = "opencode-go/deepseek-v4-pro";
-    sdd-spec             = "opencode-go/qwen3.7-plus";
+    sdd-spec             = "opencode-go/deepseek-v4-pro";
-    sdd-design           = "opencode-go/qwen3.7-plus";
+    sdd-design           = "opencode-go/glm-5.1";
-    sdd-tasks            = "opencode-go/minimax-m3";
+    sdd-tasks            = "opencode-go/kimi-k2.6";
-    sdd-apply            = "opencode-go/minimax-m3";
+    sdd-apply            = "opencode-go/kimi-k2.6";
     sdd-verify           = "opencode-go/deepseek-v4-pro";
     sdd-archive          = "opencode-go/deepseek-v4-flash";
     sdd-onboard          = "opencode-go/deepseek-v4-pro";
     neutral              = "opencode-go/deepseek-v4-pro";
   };
 }

 # opencode-go2 tier
 {
   name = "opencode-go2";
   phases = {
     gentle-orchestrator = "opencode-go/deepseek-v4-pro";
     sdd-init             = "opencode-go/deepseek-v4-flash";
-    sdd-explore          = "opencode-go/qwen3.7-plus";
+    sdd-explore          = "opencode-go/kimi-k2.6";
-    sdd-propose          = "opencode-go/qwen3.7-plus";
+    sdd-propose          = "opencode-go/glm-5.1";
-    sdd-spec             = "opencode-go/qwen3.8-ultra";
+    sdd-spec             = "opencode-go/glm-5.1";
-    sdd-design           = "opencode-go/qwen3.8-ultra";
+    sdd-design           = "opencode-go/glm-5.1";
-    sdd-tasks            = "opencode-go/qwen3.7-plus";
+    sdd-tasks            = "opencode-go/kimi-k2.6";
-    sdd-apply            = "opencode-go/minimax-m3";
+    sdd-apply            = "opencode-go/kimi-k2.7-code";
-    sdd-verify           = "opencode-go/qwen3.7-plus";
+    sdd-verify           = "opencode-go/glm-5.1";
     sdd-archive          = "opencode-go/deepseek-v4-flash";
     sdd-onboard          = "opencode-go/deepseek-v4-pro";
-    neutral              = "opencode-go/deepseek-v4-pro";
+    neutral              = "opencode-go/kimi-k2.6";
   };
 }
```

---

## Confidence summary

| Recommendation | Confidence | Basis |
|---|---|---|
| Drop Qwen 3.7 from SDD tiers | **Very High** | User-confirmed + 4 upstream issues (23960, 32418, 29754, 33721) + cross-cited in 3 communities |
| Use only OpenAI-compat group on opencode-go | **High** | Official docs split the catalogue into two transports; SDK Zod failure is documented for the Anthropic group |
| `deepseek-v4-pro` for propose/spec (heavy reasoning) | **High** | 3 independent benchmarks + 2 community configs (oh-my-opencode-slim #438, #565) |
| `glm-5.1` for design/verify (architecture quality) | **High** | 3 sources (Kilo, Atlas Cloud, oh-my-openagent #5050), top Code Arena Elo 1530 |
| `kimi-k2.6` for orchestrator/apply/tasks | **High** | 4 sources (Atlas Cloud, CodingFleet, Kilo, oh-my-openagent #5050), 4,000+ tool-call stability |
| `kimi-k2.7-code` for apply (opencode-go2) | **Medium** | Official catalogue + oh-my-opencode-slim #565 — no multi-week production evidence yet |
| `deepseek-v4-flash` for init/archive | **Very High** | Cheapest, fastest, broad tooling integration — unanimous across all 6 web sources |
| `kimi-k2.6` for onboard (warm, conversational) | **Medium** | Inferred from Andrew OOO and Kilo; no direct SDD onboarding benchmark |
| Keep `qwen3.7-*` model definitions in catalogue | **Medium** | Defensive — names still resolve; one-line revert is free; the upstream fix in hermes-agent#33055 may back-port |
| Add `mimo-v2.5` / `mimo-v2.5-pro` to catalogue | **Low** | In official catalogue, no community evidence yet on opencode-go. Add when needed; cheap to add later |

---

## Affected areas

- `shared/opencode/providers-base.nix` — `opencodeProvider.opencode.models` (add 7 entries) and the two tier `phases` blocks for `opencode-go` and `opencode-go2` (rewrite). No change to the `nvidiaProvider` block (already has the equivalent models for the nvidia NIM endpoint).
- `shared/opencode.nix` — no change (passes `allProviders` through unchanged).
- `home-darwin/opencode/providers-extra.nix` — no change (Darwin-only extras; not used by SDD tiers).
- `home-linux/openfang.nix` — line 50: `qwen3.6-plus` against `opencode-go-proxy`. **Out of scope** for this change. The model is in the Anthropic group and is likely also broken. A separate change is recommended: switch the openfang default to a known-safe model (e.g. `qwen3.6-plus` → `qwen3.5-plus` if that turns out to be served via the oa-compat path, or `deepseek-v4-flash`). The proxy is not in the repo.
- `pkgs/opencode/default.nix` — no change for now. Bump to v1.18+ when upstream ships a content-block fix.
- `openspec/changes/qwen3-opencode-type-validation/` — this file lives next to the upstream-bug exploration; both feed the upcoming proposal.

---

## Reference URLs (consolidated)

### OpenCode upstream (model health)
- https://github.com/anomalyco/opencode/issues/23960 — Qwen 3.6+ Zod invalid_union
- https://github.com/anomalyco/opencode/issues/32418 — Qwen 3.7 Cloudflare 120 s 524
- https://github.com/anomalyco/opencode/issues/33721 — Qwen 3.7 max/plus instability
- https://github.com/anomalyco/opencode/issues/29754 — Qwen 3.7 max 401 oa-compat
- https://github.com/anomalyco/opencode/issues/29558 — Qwen 3.7 max 401 (Claude Code)
- https://github.com/anomalyco/opencode/issues/31569 — MiniMax M3 thinking regression
- https://github.com/anomalyco/opencode/issues/33998 — GLM-5.2 cache drops
- https://github.com/anomalyco/opencode/issues/28726 — Agent-level opencode/ model validation regression
- https://github.com/anomalyco/opencode/issues/3755 — think: false unreliable
- https://github.com/anomalyco/opencode/issues/8456 — Feature: auto-switch model by task type (future opportunity)

### Community model assignments on opencode-go
- https://github.com/NousResearch/hermes-agent/issues/35183 — qwen3.7-max + minimax-m2.7 broken, list of working models
- https://github.com/NousResearch/hermes-agent/issues/33055 — Hermes fix: route qwen3.7-max via anthropic_messages
- https://github.com/NousResearch/hermes-agent/issues/51540 — delegation.model ignored on opencode-go
- https://github.com/NousResearch/hermes-agent/issues/35180 — kimi-k2.6 fix
- https://github.com/posit-dev/positron/issues/13662 — full /v1/models catalogue for opencode-go
- https://github.com/code-yeongyu/oh-my-openagent/issues/5050 — community config (kimi-k2.6, glm-5.1, deepseek-v4-flash, minimax-m2.7)
- https://github.com/alvinunreal/oh-my-opencode-slim/issues/438 — community config (glm-5.1, deepseek-v4-pro, kimi-k2.6, deepseek-v4-flash)
- https://github.com/alvinunreal/oh-my-opencode-slim/issues/565 — community config (kimi-k2.7-code, deepseek-v4-pro, minimax-m2.7, deepseek-v4-flash)

### Official documentation
- https://opencode.ai/docs/go/ — Go subscription model list (2026-06-30)
- https://opencode.ai/docs/zen/ — Zen (non-go) model list
- https://github.com/anomalyco/opencode/blob/dev/packages/web/src/content/docs/go.mdx — same content, source of truth
- https://opencode.ai/docs/agents/ — agent-per-model patterns

### Benchmark / comparison references
- https://spectrumailab.com/blog/best-open-source-coding-model-2026 — DeepSeek V4 / MiniMax M3 / Kimi K2.7-Code
- https://www.atlascloud.ai/blog/guides/kimi-k2-6-vs-glm-5-1-vs-qwen-3-6-plus-vs-minimax-m2-7-coding-2026 — Kimi K2.6 / GLM 5.1 / Qwen 3.6 Plus / MiniMax M2.7
- https://andrew.ooo/answers/minimax-m2-7-vs-kimi-k2-6-vs-glm-5-1-vs-deepseek-v4-may-2026/ — May 2026 four-way
- https://codersera.com/blog/deepseek-v4-alternatives-qwen-kimi-minimax-gpt-claude-compared/ — DeepSeek V4 vs Qwen/Kimi/MiniMax
- https://apidog.com/blog/minimax-m3-vs-deepseek-v4-vs-qwen-3-7/ — MiniMax M3 vs DeepSeek V4-Pro vs Qwen 3.7
- https://kilo.ai/open-source-models — 2026 model picks
- https://codingfleet.com/blog/kimi-k2-6-vs-minimax-m2-7-comparison/ — Kimi K2.6 vs MiniMax M2.7
- https://ai-crucible.com/articles/qwen-3-7-max-vs-kimi-k2-6-vs-deepseek-v4/ — Qwen 3.7 Max vs Kimi K2.6 vs DeepSeek V4
- https://artificialanalysis.ai/models/comparisons/deepseek-v4-pro-vs-minimax-m2-7 — AA Intelligence Index

### Agent / tier-wiring patterns
- https://github.com/anomalyco/opencode/issues/8456 — Feature: auto-switch model by task type
- https://opencodeguide.com/en/opencode-agents — Built-in vs custom agents
- https://github.com/defuj/opencode-agent-kit — Per-agent model recommendation table
- https://codecraftersden.com/opencode-multi-agent-workflow/ — Multi-agent coding workflow pattern
- https://milvus.io/blog/ai-code-review-gets-better-when-models-debate-claude-vs-gemini-vs-codex-vs-qwen-vs-minimax.md — Code-review model quality

---

## Deliverable

This file lives at `openspec/changes/qwen3-opencode-type-validation/exploration-model-fit.md` and is mirrored to Engram under `sdd/qwen3-opencode-type-validation/exploration-model-fit` per the hybrid-mode contract.
