# Tasks: Enforce Review-Checkpoint Gate

## Exact Files

- `openspec/changes/opencode-review-policy-enforcement/tasks.md` (created)
- `openspec/changes/opencode-review-policy-enforcement/specs/review-gates/spec.md` (review-correction check)
- `~/.config/opencode/sdd-orchestrator.md` (primary runtime target)
- `shared/opencode/assets/opencode/sdd-orchestrator.md` (rebuild-durability source target)

## Executive Summary

Add the mandatory review-checkpoint gate to the active OpenCode orchestrator text, keep the source copy identical for rebuild durability, and keep the `review-gates` spec aligned with the final behavior.

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~40 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr-default |
| Review focus | section placement, verbatim text parity, checkpoint hard-stop behavior, spec alignment |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

## Phase 1: Spec Alignment

- [x] 1.1 Reconcile `openspec/changes/opencode-review-policy-enforcement/specs/review-gates/spec.md` with the design's canonical checkpoint-gate language.
- [x] 1.2 Confirm the `RP-005` correction still states that instruction text alone is not sufficient and that checkpoint handling is mandatory.

## Phase 2: Runtime Implementation

- [x] 2.1 Update `~/.config/opencode/sdd-orchestrator.md` to insert `Review-Checkpoint Gate (MANDATORY)` immediately after `Apply-Progress Continuity` and before `Engram Topic Key Format`.
- [x] 2.2 Apply the canonical gate behavior from the design: read the active review checkpoint after `sdd-apply`, stop on missing or blocked checkpoint, and prevent the next `sdd-verify` or `sdd-apply` until the gate clears.
- [x] 2.3 Mirror the same section verbatim into `shared/opencode/assets/opencode/sdd-orchestrator.md` so future rebuilds preserve the gate.

## Phase 3: Verification

- [x] 3.1 Diff the deployed runtime file against the source copy to confirm the section text is identical and the insertion point is correct.
- [x] 3.2 If any `.nix` files are touched while applying this change, run `format-nix` and `nix flake check --no-build`.
- [x] 3.3 Rebuild or redeploy OpenCode and verify the active `~/.config/opencode/sdd-orchestrator.md` contains the new gate section.

## Next Recommended Phase

Apply
