# Delta Spec: opencode-provider-tiers — Model-to-SDD-Phase Fit

## Context

Refinement of the `opencode-provider-tiers` capability originally spec'd in `qwen3-opencode-type-validation`. This delta replaces ALL `kimi-k2.6` and `glm-5.2` phase assignments with safe models from the failure-mode-aware fit matrix (Engram #474).

## MODIFIED Requirements

### Requirement: Tier Phase Routing (table updated)

| Phase | opencode-go-full | opencode-go-medium | opencode-go-light |
|-------|-----------------|-------------------|------------------|
| gentle-orchestrator | deepseek-v4-pro | deepseek-v4-pro | deepseek-v4-flash |
| sdd-init | deepseek-v4-flash | deepseek-v4-flash | deepseek-v4-flash |
| sdd-explore | deepseek-v4-pro | deepseek-v4-pro | deepseek-v4-pro |
| sdd-propose | deepseek-v4-pro | deepseek-v4-pro | deepseek-v4-pro |
| sdd-spec | deepseek-v4-pro | deepseek-v4-pro | deepseek-v4-pro |
| sdd-design | glm-5.1 | glm-5.1 | deepseek-v4-pro |
| sdd-tasks | deepseek-v4-pro | deepseek-v4-flash | deepseek-v4-flash |
| sdd-apply | deepseek-v4-pro | deepseek-v4-flash | deepseek-v4-flash |
| sdd-verify | glm-5.1 | deepseek-v4-pro | deepseek-v4-pro |
| sdd-archive | deepseek-v4-flash | deepseek-v4-flash | deepseek-v4-flash |
| sdd-onboard | deepseek-v4-flash | deepseek-v4-flash | deepseek-v4-flash |
| neutral | deepseek-v4-pro | deepseek-v4-flash | deepseek-v4-flash |

### Scenario constraint updates

- **FULL tier allowed models**: `glm-5.1`, `deepseek-v4-pro`, `deepseek-v4-flash` (was `kimi-k2.6`, `deepseek-v4-pro`, `deepseek-v4-flash`, `glm-5.2`)
- **MEDIUM tier allowed models**: `glm-5.1`, `deepseek-v4-pro`, `deepseek-v4-flash` (was `kimi-k2.6`, `deepseek-v4-pro`, `deepseek-v4-flash`)
- **LIGHT tier allowed models**: `deepseek-v4-pro`, `deepseek-v4-flash` (was `kimi-k2.6`, `deepseek-v4-pro`, `deepseek-v4-flash`)

## Specific Changes

| # | Tier | Phase | Old | New | Rationale |
|---|------|-------|-----|-----|-----------|
| 1 | FULL | design | glm-5.2 | glm-5.1 | glm-5.2 RISKY (cache bug #33998); glm-5.1 best arch-judgement (Code Arena Elo 1530) |
| 2 | FULL | verify | glm-5.2 | glm-5.1 | glm-5.2 RISKY; glm-5.1 schema adherence for spec-match |
| 3 | FULL | tasks | kimi-k2.6 | deepseek-v4-pro | kimi-k2.6 BLOCKED (hermes-agent#35180); ds-v4-pro reliable for spec-criteria |
| 4 | FULL | orchestrator | kimi-k2.6 | deepseek-v4-pro | Same BLOCKED; ds-v4-pro for orchestrator routing |
| 5 | FULL | explore | glm-5.2 | deepseek-v4-pro | glm-5.2 RISKY; ds-v4-pro reliable for exploration |
| 6 | FULL | apply | kimi-k2.6 | deepseek-v4-pro | kimi-k2.6 BLOCKED; ds-v4-pro |
| 7 | FULL | onboard | kimi-k2.6 | deepseek-v4-flash | kimi-k2.6 BLOCKED; ds-v4-flash for lower-cost phase |
| 8 | FULL | neutral | kimi-k2.6 | deepseek-v4-pro | kimi-k2.6 BLOCKED; ds-v4-pro |
| 9 | MEDIUM | orchestrator | kimi-k2.6 | deepseek-v4-pro | kimi-k2.6 BLOCKED |
| 10 | MEDIUM | explore | kimi-k2.6 | deepseek-v4-pro | kimi-k2.6 BLOCKED |
| 11 | MEDIUM | design | deepseek-v4-pro | glm-5.1 | Best arch-judgement signal for design |
| 12 | MEDIUM | tasks | kimi-k2.6 | deepseek-v4-flash | kimi-k2.6 BLOCKED; ds-v4-flash sufficient for task breakdown |
| 13 | MEDIUM | apply | kimi-k2.6 | deepseek-v4-flash | kimi-k2.6 BLOCKED; ds-v4-flash |
| 14 | MEDIUM | verify | kimi-k2.6 | deepseek-v4-pro | kimi-k2.6 BLOCKED; ds-v4-pro for spec-match |
| 15 | LIGHT | orchestrator | kimi-k2.6 | deepseek-v4-flash | kimi-k2.6 BLOCKED; ds-v4-flash |
| 16 | LIGHT | apply | kimi-k2.6 | deepseek-v4-flash | kimi-k2.6 BLOCKED |
| 17 | LIGHT | verify | deepseek-v4-flash | deepseek-v4-pro | Flash unreliable for spec-match verification |

Note: kimi-k2.6 and glm-5.2 remain in the model catalogue (for future re-evaluation) with BLOCKED/RISKY guardrail comments.
