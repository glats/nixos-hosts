# Exploration: NVIDIA NIM Model-to-SDD-Phase Fit

## Current State

### Deployed Configuration (`shared/opencode/providers-base.nix`)

**Single-tier provider ("nvidia")** with 12 models catalogued, only 3 used across all 11 SDD phases:

| Phase | Model | Tier |
|-------|-------|------|
| orchestrator | nvidia/deepseek-ai/deepseek-v4-pro | Reasoning |
| init | nvidia/deepseek-ai/deepseek-v4-flash | Fast |
| explore | nvidia/minimaxai/minimax-m3 | Speed |
| propose | nvidia/deepseek-ai/deepseek-v4-pro | Reasoning |
| spec | nvidia/deepseek-ai/deepseek-v4-pro | Reasoning |
| design | nvidia/deepseek-ai/deepseek-v4-pro | Reasoning |
| tasks | nvidia/minimaxai/minimax-m3 | Speed |
| apply | nvidia/minimaxai/minimax-m3 | Speed |
| verify | nvidia/deepseek-ai/deepseek-v4-pro | Reasoning |
| archive | nvidia/deepseek-ai/deepseek-v4-flash | Fast |
| onboard | nvidia/deepseek-ai/deepseek-v4-pro | Reasoning |
| neutral | nvidia/deepseek-ai/deepseek-v4-pro | Reasoning |

**9 unused models**: nemotron-3-ultra-550b-a55b, step-3.7-flash, mistral-medium-3.5-128b, gemma-4-31b-it, qwen3.5-397b-a17b, gpt-oss-120b, kimi-k2.6, glm-5.1, minimax-m2.7

### Contrast with Other Providers
- **github-copilot**: 4 distinct models across 11 phases (differentiation by phase criticality)
- **opencode-go-full**: 3 distinct models (deepseek-v4-pro, deepseek-v4-flash, glm-5.1)
- **opencode-go-medium**: 2 distinct models (deepseek-v4-pro, deepseek-v4-flash)
- **opencode-free**: 3 distinct models (all free-tier variants)

The NIM provider has _more_ model diversity than any other provider (3 types), yet does NOT use NVIDIA's flagship agentic model (nemotron-3-ultra) — the model purpose-built for the NIM infrastructure.

### Existing Guardrail Comments
- **opencode-go provider** (lines 62, 71-75, 96-116): Well-documented guardrails for `glm-5.2` (cache bug), `kimi-k2.6` (HTTP 400), `qwen3.7+` series (Anthropic transport). Cites upstream issue numbers.
- **NIM provider** (lines 7-57): **ZERO guardrail comments** on any model catalog entry or phase assignment line.

## Affected Areas

- `shared/opencode/providers-base.nix` lines 7-57 — NIM model catalog (add guardrail comments, possibly mark broken models)
- `shared/opencode/providers-base.nix` lines 127-144 — NIM phase assignments (change model selection per phase)
- `shared/opencode/providers-base.nix` lines 128-229 — Provider tier structure (potentially add nvidia-full/medium/light tiers)

## NIM-Specific Failure-Mode Matrix

### Failure Categories

| Code | Failure Mode | Phase Impact |
|------|-------------|--------------|
| **A** | Thinking-burn — model enters infinite reasoning loops, can't disable thinking | ❌ All phases (blocks execution) |
| **B** | Drops-context — loses conversation state mid-session | ❌ orchestrator, explore, design, onboard |
| **C** | Low-reasoning — insufficient parameter capacity for architecture/design work | ❌ explore, design, propose |
| **D** | Rate-limit — request-per-hour caps break multi-turn agentic workflows | ❌ apply (long sessions), explore (many reads) |
| **E** | Gives-up — stops mid-plan, returns incomplete results | ❌ apply, verify, tasks |
| **F** | Tool-call-broken — HTTP 500 on tool invocation, SDK transport mismatch | ❌ ALL phases (blocks agentic work entirely) |
| **G** | Fragile-long-runs — degrades after many turns, concurrent tool call crashes | ❌ apply, explore, onboard |

### Model Assessment

| Model | A | B | C | D | E | F | G | Verdict | Best Fit |
|-------|---|---|---|---|---|---|---|---|---------|-----------|
| **deepseek-v4-pro** | — | — | — | — | — | — | — | ✅ **SAFE** (current workhorse) | All reasoning-heavy phases |
| **deepseek-v4-flash** | — | — | — | — | — | — | — | ✅ **SAFE** (current fast lane) | init, archive, tasks-light |
| **nemotron-3-ultra** | — | — | — | — | — | — | — | ✅ **SAFE** — NVIDIA's flagship agentic orchestrator. SWE-Bench 65-70.4%. 1M context. NVFP4 quant (5x throughput). OPEN WEIGHTS. **CRITICAL GAP: unused despite being recommended for orchestrator/planner roles** | orchestrator, explore, design, onboard |
| **minimax-m3** | — | — | ⚠️ | — | — | ⚠️ | ⚠️ | ⚠️ **CAUTION** — Anthropic transport (same tool-calling reliability concerns). Fast but fragile on multi-turn. Currently in explore/tasks/apply — **questionable for explore** | tasks, apply (standard complexity) |
| **mistral-medium-3.5** | — | — | — | — | — | — | — | ✅ **SAFE** — Best open-weight coding agent (8.3/10 rating). Dense 128B. Claude Sonnet 4.6-grade coding at half price. Strong instruction-following + reasoning + coding. | apply, verify, design |
| **qwen3.5-397b** | — | — | — | — | — | ⚠️ | — | ✅ **FIXED** — Tool calling was broken, now stable (Apr 2026) with new chat template + XML parser. SWE-Bench Verified 66.4% leads Nemotron Super. Community: "flawless" tool calls now. "System message at beginning" bug also fixed. | apply, verify, design |
| **step-3.7-flash** | — | — | ❌ | — | — | — | ❌ | ⚠️ **LIMITED** — #2 SWE-Bench PRO (56.3%). #1 ClawEval (67.1). But 11B active params = low knowledge storage. Tool orchestration fragile on long multi-turn. Terminal-Bench gap (59.5 vs GPT 5.5's 82.7). **Not fit for explore/design** | tasks, apply (short sessions with advisor fallback) |
| **gemma-4-31b** | — | — | ❌ | — | — | — | — | ⚠️ **LIMITED** — τ2-bench 86.4% agentic use. Native function calling. Strong codebase understanding. But 31B params = insufficient for architecture reasoning. Best as "coding partner" not autonomous developer. | apply, verify (coding partner role) |
| **glm-5.1** | — | — | ❌ | — | ✅ | — | — | ⚠️ **WEAK** — Same model as opencode-go version. "Gives up too quickly". Code Arena Elo 1530. 200K context. **Fails phase-E (gives up): blocks verify, apply.** No reason to prefer over deepseek-v4-pro or nemotron-ultra. | tasks-light (if no alternative) |
| **minimax-m2.7** | — | — | ❌ | — | ✅ | — | ❌ | ❌ **FAIL** — TUI crash with concurrent tools (opencode#19463). Stops unexpectedly (oh-my-openagent#3198). Fast (2.0s) but fragile multi-turn. **Fails phases E and G.** | ❌ Do not use for agentic phases |
| **gpt-oss-120b** | — | — | — | — | — | ❌ | — | ❌ **BROKEN** — Multi-turn tool calling broken (opencode#27210). Needs Responses API, not Chat Completions. vLLM/Ollama tool calls broken. Single-turn works, multi-turn agentic fails. **FAIL for all SDD phases** (all require multi-turn). | ❌ Do not use |
| **kimi-k2.6** | ❌ | — | — | ❌ | — | ❌ | — | ❌ **BROKEN on NIM** — HTTP 500 "unhashable type: 'dict'" (opencode#26662, #26405). Infinite "!!!" repetition loops (NVIDIA forum). thinking can't be disabled. reasoning_content missing. 30 req/hour (RPH, not per 5h!). **FAILS phases A, D, F simultaneously.** | ❌ Do not use |

### Summary Viability Spectrum

```
BROKEN (do not assign):       kimi-k2.6, gpt-oss-120b, minimax-m2.7
FRAGILE (limited phases):     glm-5.1, step-3.7-flash, gemma-4-31b, minimax-m3
SAFE (verified):              deepseek-v4-pro, deepseek-v4-flash, nemotron-3-ultra, mistral-medium-3.5
FIXED (ready):                qwen3.5-397b
```

## Cross-Reference: Phase Criticality vs Model Fit

### Phase Criticality Definitions

| Phase | Reasoning Need | Context Stability | Multi-turn Reliability | Tool-calling Safety | Speed Priority |
|-------|---------------|-------------------|----------------------|--------------------|---------------|
| **orchestrator** | HIGH | HIGH | HIGH | HIGH | LOW |
| **init** | LOW | MEDIUM | LOW | LOW | HIGH |
| **explore** | VERY HIGH | HIGH | MEDIUM | MEDIUM | LOW |
| **propose** | HIGH | HIGH | MEDIUM | MEDIUM | LOW |
| **spec** | HIGH | HIGH | MEDIUM | MEDIUM | LOW |
| **design** | VERY HIGH | HIGH | MEDIUM | MEDIUM | LOW |
| **tasks** | LOW | MEDIUM | MEDIUM | MEDIUM | HIGH |
| **apply** | MEDIUM | MEDIUM | HIGH | HIGH | MEDIUM |
| **verify** | MEDIUM | MEDIUM | MEDIUM | MEDIUM | MEDIUM |
| **archive** | LOW | LOW | LOW | LOW | HIGH |
| **onboard** | HIGH | HIGH | HIGH | MEDIUM | LOW |

### Recommended Phase Assignments

| Phase | Current | Recommendation | Rationale |
|-------|---------|---------------|-----------|
| orchestrator | deepseek-v4-pro | **nemotron-3-ultra** | NVIDIA's flagship agentic orchestrator. Built for "orchestrating complex, long-running agent workflows." 1M context. Frontier reasoning + 5x throughput. Community loves it for multi-step agent work. DeepSeek-v4-pro is also safe, but nemotron-ultra is purpose-built for this role. |
| init | deepseek-v4-flash | deepseek-v4-flash | ✅ Correct. Flash is fast and init is low-complexity. |
| explore | minimax-m3 | **nemotron-3-ultra** | ⚠️ **CRITICAL GAP**. Explore needs VERY HIGH reasoning. MiniMax M3 is a speed model with Anthropic transport fragility. Nemotron Ultra has 1M context, frontier reasoning, and is the correct model for exploration. |
| propose | deepseek-v4-pro | deepseek-v4-pro | ✅ Correct. High-reasoning model for proposal work. |
| spec | deepseek-v4-pro | deepseek-v4-pro | ✅ Correct. |
| design | deepseek-v4-pro | **nemotron-3-ultra** or **mistral-medium-3.5** | Design needs VERY HIGH reasoning. DeepSeek-v4-pro is safe but not specialized for architecture. Nemotron Ultra is NVIDIA's top reasoning model. Mistral Medium 3.5 is an open-weight alternative with Claude Sonnet 4.6-grade coding. |
| tasks | minimax-m3 | minimax-m3 or **step-3.7-flash** | Tasks is LOW reasoning, HIGH speed. MiniMax M3 fits this. Step-3.7-flash could also work (#2 SWE-Bench PRO, fast) but only for short sessions. |
| apply | minimax-m3 | **mistral-medium-3.5** or **qwen3.5-397b** | ⚠️ **GAP**. Apply needs HIGH multi-turn reliability and tool-calling safety. MiniMax M3 uses Anthropic transport (same tool-calling reliability concerns as qwen3.7+ on opencode-go). Mistral Medium 3.5 (best open-weight coding agent) or Qwen 3.5 (tool calls now "flawless") are better fits. |
| verify | deepseek-v4-pro | **qwen3.5-397b** or deepseek-v4-pro | DeepSeek-v4-pro is safe but expensive for verify (medium reasoning need). Qwen 3.5 (66.4% SWE-Bench Verified) is a strong alternative with lower cost. Mistral Medium 3.5 also valid. |
| archive | deepseek-v4-flash | deepseek-v4-flash | ✅ Correct. Fast and low-complexity. |
| onboard | deepseek-v4-pro | **nemotron-3-ultra** or deepseek-v4-pro | Onboard needs HIGH reasoning + context stability + multi-turn reliability. Nemotron Ultra with 1M context is ideal for long onboarding sessions. |
| neutral | deepseek-v4-pro | deepseek-v4-pro | ✅ Correct. Default safe choice. |

## Gap Analysis

### Gap 1: Nemotron Ultra is unused (CRITICAL)
NVIDIA's flagship agentic model — the model purpose-built for the NIM infrastructure — is catalogued but assigned to zero phases. It has 1M context, frontier reasoning, NVFP4 quantization (5x throughput), and is explicitly designed for "orchestrating complex, long-running agent workflows." The community has validated it through SWE-Bench Verified, OpenHands, and Hermes benchmarks. **This is the single biggest gap — the provider's best model has no assignment.**

### Gap 2: MiniMax M3 in explore/tasks/apply (MODERATE)
MiniMax M3's position as the speed workhorse is defensible for tasks (low reasoning, high speed). However, its placement in **explore** is incorrect — explore needs very high reasoning, and MiniMax M3's Anthropic transport introduces tool-calling reliability risks. Its placement in **apply** is also questionable given apply needs high multi-turn reliability.

### Gap 3: No broken-model guardrails (MODERATE)
Unlike the opencode-go provider which has guardrail comments on `glm-5.2`, `kimi-k2.6`, and `qwen3.7+` models citing upstream issue numbers, the NIM model catalog has zero guardrail comments. The following models should be explicitly marked:
- `kimi-k2.6` — BROKEN on NIM (HTTP 500, infinite loops, thinking can't disable)
- `gpt-oss-120b` — BROKEN multi-turn tool calling (needs Responses API)
- `minimax-m2.7` — FRAGILE (concurrent tool call crash, stops mid-plan)

### Gap 4: Single-tier limits model differentiation (LOW-MODERATE)
The NIM provider has only one tier ("nvidia"), while opencode-go has three tiers (full/medium/light/free). The NIM catalog has models at different price/speed points — a multi-tier structure would allow users to trade off cost vs capability. However, this is lower priority until the critical gaps above are addressed.

### Gap 5: qwen3.5-397b and mistral-medium-3.5 are unused (LOW-MODERATE)
Both models have strong community validation and fill gaps in the current assignment. Qwen 3.5 (66.4% SWE-Bench Verified, tool calls now "flawless") and Mistral Medium 3.5 (best open-weight coding agent, 8.3/10 rating, Claude Sonnet 4.6-grade coding at half price) are proven alternatives that could reduce dependency on deepseek-v4-pro.

## Approaches

### Approach A: Tactical model swap (minimal)

Swap only the highest-impact models. Keep single-tier structure.

| Phase | Old | New |
|-------|-----|-----|
| orchestrator | deepseek-v4-pro | nvidia/nemotron-3-ultra-550b-a55b |
| explore | minimaxai/minimax-m3 | nvidia/nemotron-3-ultra-550b-a55b |
| apply | minimaxai/minimax-m3 | mistralai/mistral-medium-3.5-128b |

Plus: Add guardrail comments on broken/fragile models.

- **Pros**: Minimal diff, addresses critical gaps, low risk.
- **Cons**: Still single-tier, doesn't use qwen3.5 or all available diversity.
- **Effort**: Low (~30 lines changed)

### Approach B: Full model differentiation

Redistribute all phases across best-fit models. Add guardrail comments. Keep single tier.

| Phase | Model |
|-------|-------|
| orchestrator | nemotron-3-ultra-550b-a55b |
| init | deepseek-v4-flash |
| explore | nemotron-3-ultra-550b-a55b |
| propose | deepseek-v4-pro |
| spec | deepseek-v4-pro |
| design | mistral-medium-3.5-128b (or nemotron-ultra) |
| tasks | minimax-m3 |
| apply | qwen3.5-397b-a17b (or mistral-medium-3.5) |
| verify | qwen3.5-397b-a17b |
| archive | deepseek-v4-flash |
| onboard | nemotron-3-ultra-550b-a55b |
| neutral | deepseek-v4-pro |

- **Pros**: Full utilization of model diversity, phase-optimized assignments.
- **Cons**: More models = more surface area for provider outages. Users must test each model.
- **Effort**: Medium (~60 lines changed including guardrails)

### Approach C: Multi-tier NIM provider (full)

Create nvidia-full, nvidia-medium, nvidia-light tiers (mirroring opencode-go pattern). Full uses nemotron-ultra + mistral-medium-3.5 + qwen3.5. Medium uses deepseek-v4-pro + deepseek-v4-flash + minimax-m3. Light uses deepseek-v4-flash + minimax-m3. Add guardrail comments.

- **Pros**: Maximum flexibility, user can choose cost/capability tradeoff. Precedent from opencode-go.
- **Cons**: Largest diff (~150+ lines), more to maintain. May fragment model usage data.
- **Effort**: High

## Recommendation

**Approach B: Full model differentiation** (with guardrails).

Rationale:
1. **Nemotron Ultra must be used** — it's NVIDIA's flagship, purpose-built for agentic orchestration, and currently has zero phase assignments. Placing it in orchestrator, explore, design, and onboard directly aligns with its design intent.
2. **MiniMax M3 must leave explore** — explore is the highest-reasoning phase outside of orchestrator. Speed models don't belong here.
3. **Mistral Medium 3.5 and Qwen 3.5 fill real gaps** — apply needs reliable multi-turn tool calling (Mistral Medium is the best open-weight coding agent, Qwen 3.5 tool calls are now "flawless"). verify benefits from Qwen 3.5's strong code understanding.
4. **Single-tier avoids fragmentation risk** — the NIM provider is new and less battle-tested than opencode-go. Multi-tier (Approach C) adds maintenance burden without enough usage data to differentiate the tiers effectively.
5. **Guardrail comments are mandatory** — the opencode-go provider sets the standard. NIM should match it.

### Migration notes
- No Nix API break — this is a configuration change within the existing module structure
- Backward compatible: `activeProviderName` selects the tier name, which stays "nvidia"
- Models remain catalogued even if not assigned — users can override via local-agent-overlays.json
- The `kimi-k2.6`, `gpt-oss-120b`, and `minimax-m2.7` entries should stay in the catalog (for eventual re-evaluation) with guardrail comments explaining why they're not assigned

## Risks

- **Nemotron Ultra throughput**: NVIDIA's NVFP4 claims "5x throughput" but benchmarks are synthetic. If real-world latency is too high for explore/onboard, fall back to deepseek-v4-pro (still catalogued).
- **Qwen 3.5 tool-calling fix**: Community reports it's fixed, but this is a recent change (Apr 2026). If regressions occur in apply/verify, fall back to mistral-medium-3.5 or minimax-m3.
- **Mistral Medium 3.5 on NIM**: Community validation is from open-weight self-hosting, not specifically NIM deployment. NIM's OpenAI-compatible transport may interact differently. If issues arise, fall back to deepseek-v4-pro for design.
- **Model rotation fatigue**: Using 6 distinct models (vs 3 today) means more model-specific quirks to track. Mitigated by the guardrail comments and fallback options.

## Ready for Proposal

**Yes** — the exploration has identified clear gaps, validated community data, and produced a recommended phase assignment matrix. The orchestrator can proceed to `sdd-propose` with the following scope:

1. Redistribute NIM provider phase assignments per Approach B
2. Add guardrail comments on kimi-k2.6, gpt-oss-120b, minimax-m2.7, glm-5.1, step-3.7-flash, gemma-4-31b
3. Keep single-tier structure
4. Maintain backward compatibility (no Nix API changes)
