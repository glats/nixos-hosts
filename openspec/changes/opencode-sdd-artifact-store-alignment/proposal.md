# Proposal: Align SDD Artifact Store Dispatching

## Intent

Native `sdd-status` only scans `openspec/changes/*` and returns "Active OpenSpec change not found" for Engram-backed changes. Local runtime orchestration assets invoke the native dispatcher unconditionally, so Engram/hybrid changes are falsely blocked. We need artifact-store-aware routing.

## Scope

### In Scope
- Gate native dispatcher invocation on selected artifact store in local runtime assets.
- Normalize `both` -> `hybrid` terminology in preflight/skills contracts.
- Document correct operating model per store mode.

### Out of Scope
- Modifying `gentle-ai` binary status engine.
- Migrating existing OpenSpec changes.
- Adding new product features.

## Capabilities

### New Capabilities
- `artifact-store-aware-dispatcher-selection`: Runtime checks artifact store before routing to native dispatcher; engram/hybrid changes bypass OpenSpec-only status validation.

### Modified Capabilities
- None

## Approach

1. Inspect active `~/.config/opencode/` orchestrator/runtime assets for dispatcher guidance.
2. Add store-mode gate: if `engram` or `hybrid`, skip native dispatcher for status/resolution.
3. Normalize terminology references (`both` -> `hybrid`).
4. Verify with a test Engram-backed change.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `~/.config/opencode/` runtime assets | Modified | Add artifact-store gate before native dispatcher |
| Local declarative wiring | Modified | Ensure deployed assets match intended version |
| Documentation | Modified | Correct operating model per store mode |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Deployment drift: runtime assets older than upstream fix | High | Verify asset version trace; diff against packaged assets |
| Existing OpenSpec changes mask wrong-store routing | Med | Test with isolated engram-only change |
| Terminology spread beyond inspected files | Low | Global repo search for `both` vs `hybrid` |

## Rollback Plan

Revert modified runtime assets in `~/.config/opencode/` to previous state and restart the runtime.

## Dependencies

- None

## Success Criteria

- [ ] Engram-backed changes are no longer blocked by "Active OpenSpec change not found".
- [ ] Hybrid-mode changes resolve status through Engram, not native dispatcher.
- [ ] No `both`/`hybrid` terminology inconsistency remains in SDD contracts.
