# Proposal: Complete OpenCode V1-to-V2 Migration

## Intent

Close remaining defects and evidence gaps without treating authored code as proven or replacing the V1 default prematurely. Consolidate the three active migration changes using Engram exploration #3350.

## Scope

### In Scope

- **Implemented:** reconcile completed code and evidence from the three existing changes without reimplementation.
- **Unproven:** execute every unchecked gate, including four-host evaluation, isolation/supervision, five adapters, SDD/review round-trips, BrowserMCP concurrency/restart, provider deny, V1 identity, and Darwin evaluation.
- **Defective:** port six confirmed V1 Engram lifecycle behaviors to V2, prove them, and run scoped dual re-judgment against the uncommitted ledger.
- **Blocked:** record unavailable provider funds, BrowserMCP pairing, host access, or platform as blocked—not passed.
- Make an evidence-backed cutover decision; keep V2 opt-in unless it explicitly authorizes the default flip.
- Accept the intentional V2 omissions: claude-auth, Warden, TUI pair, model-variants, multimodal adapter, and unsupported V1 fields.

### Out of Scope

- JEV harness, model-level allowlisting, credential-collision repair, and code-work argument harmonization.
- Reintroducing intentionally dropped capabilities or deleting V1 before proven cutover.

## Capabilities

### New Capabilities

- `opencode-v2-migration-completion`: Engram lifecycle parity, reconciled verification ledger, four-host operational proof, accepted omissions, and gated cutover decision.

### Modified Capabilities

None.

## Approach

Classify every inherited gate as implemented, proven, failed, or blocked. Correct JD-1/JD-2 at the V2 adapter boundary, then verify `rog`, `thinkcentre`, `t14`, and `macm5`. This request independently authorizes correction round one and scoped re-judgment, not a default flip.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `pkgs/engram-assets/engram-v2.ts` | Modified | Restore memory lifecycle behavior |
| `shared/opencode/`, `pkgs/nixos-scripts/` | Verified/Modified | Runtime, BrowserMCP, provider policy |
| Three existing change directories | Reconciled | Preserve truthful task status |
| `docs/opencode-v2-final-cutover.md` | Modified | Record go/no-go procedure |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| False completion from stale checkboxes | High | Require command/runtime evidence per gate |
| Host/provider/browser dependency unavailable | High | Mark blocked with reproducible evidence |
| Cutover loses sessions or fallback | High | Separate decision gate; preserve V1 and backups |

## Rollback Plan

Keep `opencode` on V1 and V2 roots isolated. Revert V2-only changes, disable BrowserMCP, and restore prior Home Manager generations. After any approved cutover, restore backed-up roots and the prior generation.

## Dependencies

- Four-host access, provider entitlement, and paired BrowserMCP extension.
- Existing JD round-one ledger remains immutable evidence until re-judgment.

## Success Criteria

- [ ] JD-1/JD-2 are corrected, tested, and independently re-judged.
- [ ] Every inherited unchecked gate is proven or explicitly blocked; none is falsely checked.
- [ ] Four-host SDD/review, BrowserMCP, provider-deny, isolation, and rollback evidence exists.
- [ ] A go/no-go cutover decision is recorded; V2 remains opt-in unless every prerequisite passes.
