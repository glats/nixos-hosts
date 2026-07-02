# Tasks: Model-to-SDD-Phase Fit — Research Prompt

## Phase assignments (5 changes)

- [x] 1. MEDIUM/design: `opencode-go/deepseek-v4-pro` → `opencode-go/glm-5.1`
- [x] 2. FULL/design: `opencode-go/deepseek-v4-pro` → `opencode-go/glm-5.1`
- [x] 3. FULL/verify: `opencode-go/deepseek-v4-pro` → `opencode-go/glm-5.1`
- [x] 4. FULL/tasks: `opencode-go/deepseek-v4-flash` → `opencode-go/deepseek-v4-pro`
- [x] 5. LIGHT/verify: `opencode-go/deepseek-v4-flash` → `opencode-go/deepseek-v4-pro`

## Guardrail comments (2 additions)

- [x] 6. Add `# BLOCKED: kimi-k2.6 onboard — hermes-agent#35180` above kimi-k2.6 model block
- [x] 7. Add `# RISKY: glm-5.2 — cache bug opencode#33998` above glm-5.2 model block

## Validation

- [x] `nix fmt -- shared/opencode/providers-base.nix` — passed
- [x] `nix flake check --no-build` — all checks passed

## Files changed

- `shared/opencode/providers-base.nix` — 5 model reassignments + 2 guardrail comments
