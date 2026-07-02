# Proposal: Model-to-SDD-Phase Fit

## Intent

Align `opencode-go` provider tier phase assignments with the community-validated,
failure-mode-aware fit matrix (Engram #474). Five phase assignments across three
tiers diverge from evidence-backed recommendations; this change corrects them.

## Scope

### In Scope
- 5 phase re-assignments across FULL, MEDIUM, LIGHT tiers (see Approach table)
- BLOCKED guardrail comment for kimi-k2.6 onboard (hermes-agent#35180 pending)
- RISKY guardrail comment for glm-5.2 (cache bug #33998)
- BROKEN guardrail comment for Qwen (5 upstream bugs open — preserve existing)

### Out of Scope
- Unblocking Qwen models (5 upstream bugs remain open)
- Promoting glm-5.2 beyond RISKY (cache bug #33998 unresolved)
- Adding new models or tiers
- FULL tier onboard phase change (kimi-k2.6 blocked per hermes-agent#35180)

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `opencode-provider-tiers`: Re-assign design, verify, tasks phase models per the
  failure-mode matrix. Previously spec'd in `qwen3-opencode-type-validation`;
  this is a delta update to those phase assignments.

## Approach

Single-file edit: `shared/opencode/providers-base.nix`. Each change is one line:

| # | Tier | Phase | Current → New | Rationale |
|---|------|-------|---------------|-----------|
| 1 | MEDIUM | design | ds-v4-pro → **glm-5.1** | Code Arena Elo 1530, best arch-judgement |
| 2 | FULL | design | ds-v4-pro → **glm-5.1** | Same — highest design/architecture signal |
| 3 | FULL | verify | ds-v4-pro → **glm-5.1** | Schema adherence beats raw reasoning for spec-match |
| 4 | FULL | tasks | ds-v4-flash → **ds-v4-pro** | Flash's low reasoning misses spec criteria |
| 5 | LIGHT | verify | ds-v4-flash → **ds-v4-pro** | Flash unreliable for spec-match verification |

No other phase assignments change. MEDIUM verify stays ds-v4-pro (already correct).
FULL apply stays ds-v4-pro (kimi-k2.7-code alternative requires hermes-agent#35180).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/opencode/providers-base.nix` | Modified | 5 phase assignment lines + guardrail comment block |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| glm-5.1 "gives up" during design/verify | Low | Design and verify are single-session tasks with bounded scope; glm-5.1's rate limit ceiling (3,450 req/5h) is adequate |
| glm-5.1 code-area blind spot on verify | Low | Verify matches spec to implementation, not code-gen; glm-5.1 excels at schema adherence |
| Model name mismatch in flake check | Low | All model keys verified against provider catalogue; same `opencode-go/` prefix |

## Rollback Plan

Revert the commit. All current phase assignments are preserved in git history.
No data migration, no secrets touched, no package version bumps.

## Dependencies

- **Blocked**: `opencode/opencode#35180` (hermes-agent — kimi tool-call reliability).
  When fixed, re-evaluate FULL tier `onboard` → kimi-k2.6 per research recommendation.
- **Risky**: `opencode#33998` (glm-5.2 cache bug ~500 tokens). Blocks glm-5.2 from
  any phase until resolved; comment guards this.
- **BROKEN**: 5 upstream Qwen bugs (opencode#23960, #32418, #29754, #33055, #33303).
  Existing zombie entries and comment block preserved unchanged.

## Success Criteria

- [ ] `nix flake check --no-build` passes for rog, thinkcentre, t14
- [ ] FULL tier: `design` and `verify` resolve to `opencode-go/glm-5.1`
- [ ] FULL tier: `tasks` resolves to `opencode-go/deepseek-v4-pro`
- [ ] MEDIUM tier: `design` resolves to `opencode-go/glm-5.1`
- [ ] LIGHT tier: `verify` resolves to `opencode-go/deepseek-v4-pro`
- [ ] BLOCKED/RISKY guardrail comments present above kimi, glm-5.2, Qwen entries
- [ ] `format-nix` produces no diff on changed file
