# Model-to-SDD-Phase Fit — Research Prompt

**For**: Finding the perfect model fit per SDD phase on opencode-go
**Based on**: Community experience (not benchmarks) + documented failure modes
**Last updated**: 2026-06-30
**Engram**: `sdd/qwen3-opencode-type-validation/phase-model-fit-analysis` (#474)

---

## THE GOAL

For every SDD phase on the `opencode-go` subscription, determine which model has the
best fit based on **real community experience** and **documented failure modes** — not
benchmark scores. Then build tiers (full/medium/light) around those fits.

---

## 1. SDD PHASES — WHAT EACH PHASE ACTUALLY DEMANDS

| Phase | Real workload | Context | Reasoning | Tool calls | Can't tolerate |
|-------|--------------|---------|-----------|------------|----------------|
| **orchestrator** | Coordinates pipeline, delegates to sub-agents, tracks DAG | Medium | HIGH — planning, deps | Many (spawns sub-agents) | Context drops, low reasoning, giving up |
| **init** | Scans project, detects stack, builds registry | Low-Med | LOW — pattern matching | Many (reads, greps) | Rate limits (many calls) |
| **explore** | Investigates codebase + external search, synthesizes | HIGH | HIGH — synthesis | Many (reads, MCP, web) | Context burn, context drops, low reasoning, rate limits |
| **propose** | Writes proposals from exploration data | Med-High | HIGH — structured reasoning | Some (reads artifacts) | Low reasoning |
| **spec** | Writes detailed specs with scenarios | Medium | HIGH — precision | Some (reads) | Low reasoning |
| **design** | Technical design, architecture, tradeoffs | Med-High | HIGH — architecture | Some (reads code) | Context drops, low reasoning, giving up |
| **tasks** | Breaks design into implementation tasks | Medium | MED — decomposition | Some (reads design) | — (most tolerant phase) |
| **apply** | Writes code, edits files, runs validation | Med-High | MED — codegen | Many (writes, bash) | Rate limits, giving up on failed builds |
| **verify** | Runs tests, validates against specs | Medium | MED-HIGH — methodical | Many (bash, tests) | Giving up on failures |
| **archive** | Syncs delta specs, moves files | Low-Med | LOW — structured | Some (file ops) | — (easiest phase) |
| **onboard** | Walks user through SDD cycle | Low-Med | LOW — pedagogy | Few | — (easiest phase) |
| **neutral** | General fallback | Variable | Variable | Variable | Depends on task |

---

## 2. MODELS — BEHAVIOR IN AGENTIC WORKLOADS

### Working models (OpenAI-compat, `/v1/chat/completions`)

| Model | Strengths | Documented failures | Rate / 5h | Context |
|-------|----------|--------------------|----------|---------|
| **deepseek-v4-pro** | Best agentic/long-horizon (GDPval-AA 1554). Solid all-around. Zero FAILs documented. | Loops on very large repos (1 test, not widespread) | **3,450** | 1M |
| **deepseek-v4-flash** | Fast, cheapest, reliable. Good for volume. | Lower reasoning depth (expected) | 3,450 | 1M |
| **kimi-k2.6** | Strong codegen (58.6% SWE-Pro). Swarm primitive for complex tasks. | **[CRITICAL] thinking CANNOT be disabled** → 20%+ context burned on reasoning. **[CRITICAL] 87% OSS multi-turn tool-call fail**. Post-tool empty responses. Overthinking loops. | **1,150** | 256K |
| **kimi-k2.7-code** | Code-focused, ~30% fewer thinking tokens. | Same family risks as k2.6 (thinking, tool-calls). | 1,150 | 256K |
| **glm-5.2** | 1M context, strong at pure coding, MIT license. | **[CRITICAL] Drops context on multi-step** — references renamed fields. Weak pure reasoning (trails HLE/GPQA). 2x token inefficient. | 880 | 1M |
| **glm-5.1** | Best Code Arena Elo (1530). Lowest hallucination rate. Good schema adherence. MIT. | **"Gives up too quickly"** on hard retries. 200K context (smaller). | 880 | 200K |
| **mimo-v2.5** | Budget model. | **Insufficient community data** to assess reliability. | Unknown | Unknown |
| **mimo-v2.5-pro** | Better than v2.5. | **Insufficient community data**. | Unknown | Unknown |

### Known-broken models (Anthropic transport, `/v1/messages`)

| Model | Issue | Status (Jun 2026) |
|-------|-------|-------------------|
| qwen3.7-max | REQUIRES Anthropic Messages endpoint. Works IF routed correctly (60.6% SWE-Pro, #1 on Go). | Fix: PR #33547 (Jun 23). Verify opencode version. |
| qwen3.7-plus | Same transport requirement. Also affected by content-block union bug (#23960)? | #23960 still OPEN. |
| qwen3.6-plus | Streaming `invalid_union` on content blocks (#23960). | #23960 OPEN since Apr 23. |
| minimax-m3/m2.7/m2.5 | Anthropic transport. 3,200 req/5h (m3). Community uses as workhorse. | Transport routing required. |

---

## 3. PHASE CRITICALITY — What each phase CANNOT tolerate

Cross-reference: each model has failure modes (A-E). Each phase has tolerance levels.

| Failure mode | Column | Affected models |
|-------------|--------|----------------|
| **A: thinking-burn** — always reasons, no disable, burns 20%+ context | kimi-k2.6, kimi-k2.7-code |
| **B: drops-context** — loses track on multi-step chains | glm-5.2 |
| **C: low-reasoning** — insufficient depth for complex analysis | deepseek-v4-flash, mimo |
| **D: rate-limit-3x** — 1/3 the requests of competitors | kimi family |
| **E: gives-up** — stops instead of retrying on failure | glm-5.1 |

| Phase | A (thinking) | B (drops) | C (low-reason) | D (rate-lim) | E (gives-up) |
|-------|:---:|:---:|:---:|:---:|:---:|
| orchestrator | ⚠️ | ❌ | ❌ | ⚠️ | ❌ |
| init | ✅ | ✅ | ✅ | ⚠️ | ✅ |
| **explore** | ❌ | ❌ | ❌ | ❌ | ⚠️ |
| propose | ⚠️ | ⚠️ | ❌ | ✅ | ⚠️ |
| spec | ✅ | ⚠️ | ❌ | ✅ | ⚠️ |
| **design** | ⚠️ | ❌ | ❌ | ✅ | ❌ |
| tasks | ⚠️ | ⚠️ | ✅ | ✅ | ✅ |
| **apply** | ⚠️ | ⚠️ | ⚠️ | ❌ | ❌ |
| verify | ⚠️ | ✅ | ⚠️ | ⚠️ | ❌ |
| archive | ✅ | ✅ | ✅ | ✅ | ✅ |
| onboard | ✅ | ✅ | ✅ | ✅ | ✅ |

**Leyenda**: ❌ = fatal para esta fase | ⚠️ = frágil, puede fallar | ✅ = tolera

### Hard-NO phases (más restrictivas):
- **explore** ❌❌❌❌ — ningún modelo con A/B/C/D sobrevive. Solo deepseek-v4-pro califica.
- **orchestrator** ❌❌❌ — B/C/E son fatales.
- **design** ❌❌❌ — B/C/E son fatales.
- **apply** ❌❌ — D/E son fatales.

---

## 4. COMMUNITY EXPERIENCE — What real users do

> **Sources**: GitHub issues, Medium guides, Reddit, HN, gists, personal blogs.
> These are NOT benchmarks. They're what developers report after months of daily use.

### The universal pattern: multi-model routing

Every successful setup uses 2-4 models in rotation. Nobody uses one model for everything.

```
Volume/simple    → cheapest reliable model (Flash, MiMo)
Standard work    → balanced workhorse (DeepSeek V4 Pro, MiniMax M3)
Hard reasoning   → premium model (Qwen3.7 Max, Kimi K2.6)
Fallback         → chain of 3-4 models when primary fails or rate-limited
```

### Real community configs

**oh-my-openagent** (srmdn gist, most popular):
```
Ultrabrain:  DeepSeek V4 Pro → GLM-5.1 → MiniMax M2.5  (3-deep fallback)
Multimodal:  Qwen3.6 Plus
Budget:      MiniMax M2.5 Free
```

**Medium guide** (Jatin K Malik, 10k+ readers, Jun 2026):
```
Hard tasks:    Qwen3.7 Max  → Kimi K2.6  → MiniMax M3  → DeepSeek V4 Pro
Standard:      MiniMax M3   → DeepSeek V4 Pro → Kimi K2.6
Codegen:       MiniMax M3   → DeepSeek V4 Pro → Kimi K2.6
Volume:        DeepSeek V4 Flash → MiMo-V2.5
```
Key insight: *"Rate limits are not failures — they're signals to switch models."*

**BSWEN setup** (May 2026) — simplest that works:
```
Complex:      DeepSeek V4 Pro
Simple:       DeepSeek V4 Flash
```
$10/mes vs $200/mes Claude Code. "90% as good for most tasks."

**Tyler Folkman routing study** (2,415 agent turns across 6 models):
| Model | Turns | % | Role |
|-------|-------|---|------|
| Kimi K2.6 | 1,984 | 82.2% | Workhorse — PR reviews, refactors, debug |
| GPT 5.5 | 238 | 9.9% | Only when cheap path fails |
| DeepSeek V4 Flash | 38 | 1.6% | Logging, simple edits |
| DeepSeek V4 Pro | 28 | 1.2% | Different reasoning balance |
| GLM 5.1 | 21 | 0.9% | Alternative |

> Note: This was Kimi via Moonshot API (not opencode-go). Pre-dates documented bugs.

**Reddit budget setup** (Jan 2026) — $14.50/mes total:
> "Let expensive models research and plan. Smaller models implement small tasks.
> Claude for planning, GLM for daily, Gemini for big context."

### What DOESN'T work (community consensus)
- ❌ One model for everything — burns rate limits on trivial tasks
- ❌ Ignoring rate limits — "they're signals, not failures"
- ❌ Trusting benchmarks without testing your own workflow
- ❌ Using premium models for boilerplate — waste

### What DOES work
- ✅ 2-4 models in rotation with fallback chains
- ✅ Cheap model for volume, strong model for hard tasks
- ✅ Primary chosen by rate limits AND capability
- ✅ "Spec-driven development reduces API calls"
- ✅ Re-evaluate monthly — new models ship constantly

---

## 5. HOW TO FIND THE PERFECT FIT

### Step 1: Start with the Phase Criticality Matrix (Section 3)
For each phase, identify which failure modes are ❌ (fatal). This eliminates models immediately.

Example: `sdd-explore` has ❌ on columns A/B/C/D.
→ Eliminate kimi (A, D), glm-5.2 (B), v4-flash/mimo (C).
→ Only deepseek-v4-pro survives.

### Step 2: For surviving models, check community evidence (Section 4)
Does the community actually use this model for this kind of task?
Is there documented success or failure?

### Step 3: Rate limits as tiebreaker
Between two viable models, pick the one with higher request limits.
DeepSeek V4 Pro (3,450/5h) beats Kimi (1,150/5h) beats GLM (880/5h).

### Step 4: Build tiers around the fits
- **Full**: Best model for each phase, cost irrelevant. GLM-5.1 for arch phases? Qwen3.7 Max if transport works?
- **Medium**: Best balance of cost + reliability. No models with ❌ in any assigned phase.
- **Light**: Cheapest reliable per phase. No models with ❌. Maximize v4-flash where phases tolerate low reasoning.

### Step 5: Validate against new data
- Are there NEW models not in this document? Check https://opencode.ai/docs/go/
- Are documented bugs now FIXED? Check GitHub issues.
- Has community consensus shifted? Search Exa/GitHub/Reddit.

---

## 6. CURRENT FIT MATRIX (Jun 2026 baseline)

This is the reference fit matrix. Re-compute if model behavior or community consensus changes.

| Phase | v4-pro | v4-flash | kimi-k2.6 | glm-5.2 | glm-5.1 | mimo |
|-------|:------:|:--------:|:---------:|:-------:|:-------:|:----:|
| orchestrator | ✅ EXCEL | ⚠️ RISKY | ❌ FAIL | ❌ FAIL | ⚠️ RISKY | ❌ |
| init | ✅ EXCEL | ✅ EXCEL | ⚠️ RISKY | ✅ GOOD | ✅ GOOD | ⚠️ |
| **explore** | ✅ EXCEL | ⚠️ RISKY | ❌ FAIL | ❌ FAIL | ⚠️ RISKY | ❌ |
| propose | ✅ EXCEL | ⚠️ RISKY | ⚠️ RISKY | ⚠️ RISKY | ✅ EXCEL | ❌ |
| spec | ✅ EXCEL | ⚠️ RISKY | ⚠️ RISKY | ⚠️ RISKY | ✅ EXCEL | ❌ |
| **design** | ✅ EXCEL | ⚠️ RISKY | ⚠️ RISKY | ❌ FAIL | ✅ EXCEL | ❌ |
| tasks | ✅ GOOD | ✅ GOOD | ⚠️ RISKY | ⚠️ RISKY | ✅ GOOD | ⚠️ |
| **apply** | ✅ GOOD | ⚠️ RISKY | ❌ FAIL | ⚠️ RISKY | ⚠️ RISKY | ❌ |
| verify | ✅ EXCEL | ⚠️ RISKY | ❌ FAIL | ⚠️ RISKY | ✅ EXCEL | ❌ |
| archive | ✅ EXCEL | ✅ EXCEL | ✅ GOOD | ✅ GOOD | ✅ GOOD | ⚠️ |
| onboard | ✅ GOOD | ✅ GOOD | ✅ GOOD | ⚠️ RISKY | ✅ GOOD | ⚠️ |
| neutral | ✅ EXCEL | ✅ GOOD | ⚠️ RISKY | ⚠️ RISKY | ✅ GOOD | ⚠️ |

### DO NOT USE (documented failures with sources)
| Combo | Why | Source |
|-------|-----|--------|
| kimi × explore | Triple block: thinking-burn + 87% tool fail + 1,150 req | opencode#25001, MoonshotAI#128, oh-my-opencode-slim#459 |
| kimi × apply | 87% tool-call fail on writes/bash + empty post-tool | MoonshotAI#128, kimi-code#520 |
| kimi × verify | Multi-turn bash/test → 87% fail + empty | kimi-code#520 |
| kimi × orchestrator | Thinking burn + tool fail + rate limits | MoonshotAI#128, opencode#25001 |
| glm-5.2 × design | Context drops on multi-step, loses arch decisions | TowardsAI test |
| glm-5.2 × orchestrator | Loses DAG state on multi-step | TowardsAI test, opencode#33998 |
| glm-5.2 × explore | Weak synthesis + context drops + user confirmed skipped tasks | TowardsAI + direct experience |
| glm-5.1 × apply | Gives up on failed builds/tests | oh-my-opencode-slim#459 |
| mimo × any critical | No reliability data — v4-flash strictly better documented | — |
| v4-flash × design | Low reasoning misses architecture tradeoffs | Column C ❌ |

### Caveats (must re-validate each session)
- ⚠️ Kimi tool-call 87% = OSS. On opencode-go with hermes-agent#35180 fix, may be lower. Verify.
- ⚠️ Qwen3.7 Max routing: requires Anthropic Messages. PR #33547 merged Jun 23. Verify opencode version has it.
- ⚠️ GLM-5.2 context drop: intermittent. May not affect short sessions.
- ⚠️ New models ship monthly. Check https://opencode.ai/docs/go/ for additions.

---

## 7. SOURCES — Where the data comes from

### GitHub Issues (for failure mode evidence)
- opencode#23960 — Qwen3.6 streaming `invalid_union` (OPEN)
- opencode#25001 — Kimi ignores thinking:disabled (OPEN)
- opencode#29363 — limit.output capped at 32K (OPEN)
- opencode#29688 — Qwen3.7-max oa-compat unsupported
- opencode#29754 — Qwen3.7-max 401 via oa-compat
- opencode#33998 — GLM-5.2 cache bug
- MoonshotAI/Kimi-K2#128 — 87% OSS tool-call fail (OPEN)
- MoonshotAI/kimi-code#520 — Post-tool empty responses (OPEN)
- MoonshotAI/kimi-code#476 — Compaction overflow (OPEN)
- oh-my-opencode-slim#459 — Rate limits comparison

### Articles (for community patterns)
- https://opencode.ai/docs/go/ — Official model catalogue
- https://medium.com/@jatinkrmalik/opencode-go-oh-my-openagent-... — Routing guide (10k+ reads)
- https://particula.tech/blog/deepseek-v4-vs-kimi-k2-6-vs-glm-5-1 — 100-ticket SWE comparison
- https://andrew.ooo/answers/kimi-k2-6-vs-glm-5-1-vs-deepseek-v4-pro — May 2026 comparison
- https://pub.towardsai.net/i-tested-glm-5-2-5a65f965eeee — GLM-5.2 18-task test
- https://tylerfolkman.substack.com/p/i-tested-6-ai-models — 2,415-turn routing study
- https://docs.bswen.com/blog/2026-05-07-deepseek-opencode-go-guide — Daily driver setup
- https://julien.cloud/blog/opencode-go-models-2026 — Model capability survey
- https://gist.github.com/srmdn/448d142a122208c47e586a0d78323b3e — Community config
- https://codersera.com/blog/kimi-k2-6-vs-deepseek-v4-vs-glm-5-1 — 3-way comparison

### Repo files (for implementation context)
- `shared/opencode/providers-base.nix` — model catalogue + tier definitions
- `shared/opencode.nix` — HM module, activeProviderName option
- `hosts/t14/home/omarchy.nix` — t14 override
- `pkgs/opencode/default.nix` — opencode version (check for Qwen routing fix)

---

## 8. CURRENT TIERS (Deployed Jun 30, 2026)

Applied as baseline. Re-compute using this document when new data arrives.

### opencode-go-full — Best fit per phase
```
orchestrator → v4-pro     init → v4-flash      explore → v4-pro
propose → v4-pro          spec → v4-pro        design → v4-pro
tasks → v4-flash          apply → v4-pro       verify → v4-pro
archive → v4-flash        onboard → v4-flash   neutral → v4-pro
```

### opencode-go-medium — Balance (DEFAULT)
```
orchestrator → v4-pro     init → v4-flash      explore → v4-pro
propose → v4-pro          spec → v4-pro        design → v4-pro
tasks → v4-flash          apply → v4-flash     verify → v4-pro
archive → v4-flash        onboard → v4-flash   neutral → v4-flash
```

### opencode-go-light — Cheapest reliable
```
orchestrator → v4-flash   init → v4-flash      explore → v4-pro
propose → v4-pro          spec → v4-pro        design → v4-pro
tasks → v4-flash          apply → v4-flash     verify → v4-flash
archive → v4-flash        onboard → v4-flash   neutral → v4-flash
```

### Host assignments
| Host | Tier |
|------|------|
| rog, thinkcentre | opencode-go-medium (default) |
| t14 | opencode-go-full (explicit override) |
| mact2 | github-copilot (unchanged) |
