# Apply Progress: opencode-review-policy-enforcement

## Slice: Review-Checkpoint Gate Enforcement

### Files updated

- `~/.config/opencode/sdd-orchestrator.md`
- `shared/opencode/assets/opencode/sdd-orchestrator.md`
- `openspec/specs/review-gates/spec.md`

### Applied changes

1. Inserted `Review-Checkpoint Gate (MANDATORY)` immediately after `Apply-Progress Continuity (MANDATORY)` and before `Engram Topic Key Format` in the active runtime orchestrator file.
2. Mirrored the identical gate section into the source orchestrator asset so the change survives future `nixos-build` redeploys.
3. Corrected `RP-005` in `openspec/specs/review-gates/spec.md` so it no longer claims that instruction text alone is sufficient for enforcement.

### Verification completed during apply

- `nix flake check --no-build` — passed
- Runtime/source parity check for `sdd-orchestrator.md` — passed (`diff` produced no output)
- Insertion point check — passed (`Review-Checkpoint Gate (MANDATORY)` appears between `Apply-Progress Continuity` and `Engram Topic Key Format`)

### Notes

- No `.nix` files changed, so `format-nix` was not required for this slice.
- This slice is still in local workspace state; no commit or push was performed in this apply step.
