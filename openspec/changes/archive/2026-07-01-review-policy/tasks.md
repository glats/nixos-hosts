# Tasks: SDD Review Policy — Binary Iteration Gate

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~120 (114 policy + 3 nix edits) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | single PR |
| Delivery strategy | single-pr (auto-detect: < 400 lines) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Full review policy deployment | PR 1 | Single PR to main — policy file + nix integration + verify |

## Phase 1: Policy Content

- [x] 1.1 Create `shared/opencode/sdd-review-policy.md` with review policy text covering RP-001 through RP-006: hard gate, binary iteration, re-explore protocol, artifact lifecycle, instruction text enforcement, proceed escape hatch
- [x] 1.2 Include guard lines (`Rework level`, `Iteration decision needed`) per RP-005 spec

## Phase 2: Nix Integration

- [x] 2.1 Add `"sdd-review-policy.md"` to `instructions` array in `shared/opencode.nix` (line ~72)
- [x] 2.2 Add `home.file` entry in `shared/opencode.nix` for `.config/opencode/sdd-review-policy.md` — `force=true`, `source=./opencode/sdd-review-policy.md` (after existing SYSTEM_RULES.md entry)
- [x] 2.3 Add `sdd-review-policy.md` to activation script for-loop in `shared/opencode.nix` (line ~147)

## Phase 3: Verification

- [x] 3.1 Run `nix flake check --no-build` to validate all module imports and option declarations
- [x] 3.2 Run `format-nix` to format all edited `.nix` files
- [x] 3.3 Verify policy file content against all 6 spec scenarios from RP-001 through RP-006
