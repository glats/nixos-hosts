# Apply Progress: NVIDIA NIM Model-to-SDD-Phase Fit

**Mode**: Standard (no Strict TDD)
**Batch**: 1/1 (single batch — all tasks complete)
**Commit**: `f86b18a` on master, pushed to origin
**File**: `shared/opencode/providers-base.nix` (+23/-8)

## Completed Tasks

- [x] Add 8 guardrail comments to NIM model catalogue (BROKEN: kimi-k2.6, gpt-oss-120b, qwen3.5, minimax-m2.7; RISKY: glm-5.1, step-3.7-flash, gemma-4, deepseek-v4-pro on NIM)
- [x] Update 8 NIM phase assignments (orchestrator→nemotron-ultra, explore→nemotron-ultra, propose→nemotron-ultra, spec→mistral-medium-3.5, design→mistral-medium-3.5, verify→nemotron-ultra, onboard→v4-flash, neutral→nemotron-ultra)
- [x] deepseek-v4-pro removed from all NIM phases
- [x] Run `nix fmt` — formatted
- [x] Run `nix flake check --no-build` — all checks passed

## Net Model Usage (4 models active)

| Model | Assigned Phases |
|-------|----------------|
| nemotron-3-ultra-550b-a55b | orchestrator, explore, propose, verify, neutral |
| deepseek-v4-flash | init, archive, onboard |
| mistral-medium-3.5-128b | spec, design |
| minimax-m3 | tasks, apply |

## Unchanged

init (v4-flash), tasks (minimax-m3), apply (minimax-m3), archive (v4-flash)

## Guardrail Comments Added

| Model | Status | Issue |
|-------|--------|-------|
| kimi-k2.6 | BROKEN | HTTP 500 "unhashable type: 'dict'" (opencode#26662, #26405), infinite "!!!" loops, 30 RPH |
| gpt-oss-120b | BROKEN | Multi-turn broken (opencode#27210), needs Responses API |
| qwen3.5 | BROKEN on NIM | "System message must be at beginning" (opencode#16560, #20785), fix PR #16981 not merged |
| minimax-m2.7 | BROKEN | TUI crash concurrent tools (opencode#19463), stops mid-plan (oh-my-openagent#3198) |
| glm-5.1 | RISKY | "Gives up too quickly" on failures |
| step-3.7-flash | RISKY | 11B active = low knowledge, fragile on long multi-turn, Terminal-Bench gap |
| gemma-4 | RISKY | Mixed implementation quality, "coding partner" not autonomous agent |
| deepseek-v4-pro on NIM | RISKY | Tool-call streaming may not continue in agent workflows, requires chat_template_kwargs (opencode#24264) |

## Validation

- `nix fmt -- shared/opencode/providers-base.nix` → success
- `nix flake check --no-build` → all checks passed
- All NIM model IDs in phases verified against model catalogue entries
