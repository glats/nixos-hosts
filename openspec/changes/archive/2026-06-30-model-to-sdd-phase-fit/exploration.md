## Exploration: Model-to-SDD-Phase Fit

### Current State

The NixOS config deploys opencode `v1.17.11` with 6 provider tiers. The opencode-go provider has a model gallery of 11 models (3 marked BROKEN for Qwen upstream bugs). Phase assignments for the 3 opencode-go tiers (full/medium/light) use only deepseek-v4-pro and deepseek-v4-flash — glm-5.1, kimi-k2.6, kimi-k2.7-code, mimo-v2.5, and mimo-v2.5-pro are registered in the gallery but never assigned to any SDD phase.

Host assignments: t14 = `opencode-go-full`, rog = `opencode-go-medium` (default), thinkcentre = `opencode-go-medium` (default).

### Affected Areas

- `shared/opencode/providers-base.nix` — Phase assignments for opencode-go-full, opencode-go-medium, opencode-go-light (lines 161-210). These are the only lines that need to change.
- No other files affected — the model gallery, HM module (`shared/opencode.nix`), host configs, and flake.nix are all correct.

### Approaches

1. **Validate-only (no change)** — Accept the deployed tiers as-is.
   - Pros: Zero risk, no build/test cycle
   - Cons: Leaves 5 known gaps where the deployed model is suboptimal per failure-mode analysis; glm-5.1's "best arch-judgement" for design/verify goes unused
   - Effort: None

2. **Refine with glm-5.1 for design/verify (recommended)** — Switch design and verify to glm-5.1 in full/medium tiers, upgrade LIGHT verify to ds-v4-pro.
   - Pros: Uses the model best-suited per phase (glm-5.1 Code Arena Elo 1530 for arch-judgement; ds-v4-pro reliability for LIGHT verify); low risk because glm-5.1's "gives up too quickly" is marked YES (tolerable) for design/verify phases
   - Cons: glm-5.1 rate limit 880 req/5h (vs ds-v4-pro's 3,450) — but design and verify are moderate-volume phases (15-50 req/task); no Kimi or Qwen deployment possible until upstream fixes land
   - Effort: Low (5 line changes in one file)
   - Changes:
     - MEDIUM: `design = "opencode-go/glm-5.1"` (was ds-v4-pro)
     - FULL: `design = "opencode-go/glm-5.1"` (was ds-v4-pro)
     - FULL: `verify = "opencode-go/glm-5.1"` (was ds-v4-pro)
     - FULL: `tasks = "opencode-go/deepseek-v4-pro"` (was flash)
     - LIGHT: `verify = "opencode-go/deepseek-v4-pro"` (was flash)

3. **Full redistribution per research prompt** — Deploy all recommended assignments including kim-k2.6 for onboard.
   - Pros: Maximally aligned with research
   - Cons: Kimi k2.6 blocked by hermes-agent#35180 (HTTP 400 on thinking toggle, still OPEN); Qwen blocked by 5 open bugs; too aggressive given no upstream fixes have landed
   - Effort: Medium (more phase changes, needs conditional guards for blocked models)

### Recommendation

**Approach 2 — Refine with glm-5.1 for design/verify, defer Kimi/Qwen.** The 5 changes are low-risk, directly supported by the failure-mode analysis, and use models already in the gallery. Kimi and Qwen deployments should wait for confirmed upstream fixes (hermes-agent#35180 merge, Qwen Anthropic Messages transport fix).

### Risks

1. **glm-5.1 "gives up too quickly"**: The research marks this as YES (tolerable) for design and verify phases. Design is read-only analysis — if it gives up, user retries. Verify runs deterministic test suites — single-attempt spec-match is acceptable. Low risk.
2. **glm-5.1 rate limit (880 req/5h)**: Design and verify are moderate-volume (~15-50 req each). Well within limits. Medium risk only if a host runs many parallel SDD sessions.
3. **Kimi k2.6 BLOCKED**: hermes-agent#35180 still open. Do NOT assign kimi to any phase until fix confirmed in opencode SDK build.
4. **Qwen BROKEN block stays**: All 5 documented Qwen bugs remain open. No change to the existing BROKEN comment/block.
5. **glm-5.2 cache bug #33998**: Still open. Confirms research's RISKY/FAIL verdict — glm-5.2 stays unassigned.

### Ready for Proposal

Yes. sdd-propose should draft a refinement proposal carrying: the 5 phase-rewiring changes to `providers-base.nix`, glm-5.1 deployment conditional on design/verify phase tolerance, and a guardrail comment noting that Kimi/Qwen/Copilot assignments are deferred until upstream fixes land.
