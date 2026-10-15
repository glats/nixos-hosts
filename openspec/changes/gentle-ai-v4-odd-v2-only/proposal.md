Superseded by adopt-gentle-ai-v4-odd-opencode2 (2026-10-15); content preserved as history.

# Proposal: One Gentle AI v4 / ODD Stack on V2

## Intent

Replace locally adapted Gentle AI v2.5 SDD with canonical v4.0.0 ODD on rog, thinkcentre, t14 and macm5, preserving working V2 identity and review authority.

## Scope

### In Scope
- One binary/assets source: v4.0.0, commit `ff77164d4f56f1665b22fb6fac51c2ccbb769400`; initially keep CLI/SDK 2.0.14.
- Coherent ODD routes, commands, plugins and shared consumers; remove missing-overlay assumptions, ownership-proven stale skills and incorrect registry roots.
- Preserve `opencode2`, Darwin-only `opencode2-home`, namespaces, service identity, auth/sessions, MCP/Engram, providers and user overrides.
- Substantial work: `odd/tasks/<feature>.md` plus full Engram `odd/<feature>/tasks` mirror, readback and conflict/pending-mirror recovery.

### Out of Scope
- V3 staging, V1 revival, permanent dual production, global aliases, fake versions or capability bypass.
- Bulk OpenSpec conversion/deletion; unrelated SSH-relay work.
- Preparation authorizes only proposal→spec→design→tasks, then STOP: no code/pins/builds/live models/activation/commits/push. Later ODD commit policy requires explicit reconciliation.

## Capabilities

### New Capabilities
- `odd-managed-workflow`: authorization, tracking, test-first exceptions, bounded delegation, recovery and history-safe cutover.
- `gentle-ai-v2-review-transport`: truthful private native-V2 discovery, supported managed `gentle-ai.opencode-relay/v2-staged` relay and native receipt admission.

### Modified Capabilities
- `gentle-ai-declarative-runtime`: tagged source, ODD graph/grants, plugin/command lifecycle, routing and fleet gates.
- `opencode-v1-retirement`: reconcile its unarchived delta baseline; supersede only the v2.5/no-v4 continuity restriction, preserving V2-only safety.

## Approach

Use current SDD until disposable candidate proof; replace executable workflow coherently afterward. Retain local V2 adapters only after v4 contract reconciliation. Keep discovery PATH private to Gentle/relay children. Reconcile `retire-opencode-v1` deltas with main specs, preserving proxy/auth/tunnel invariants; explicitly select unfinished work and link history. Roll out rog first after separate authorization.

## Affected Areas

| Paths | Impact |
|---|---|
| `flake.nix`, `flake.lock`, `pkgs/gentle-ai*/` | Source/build/discovery |
| `shared/opencode/`, `shared/shell-aliases.nix` | Graph/plugins/routes |
| `shared/ai-assets.nix`, `shared/claude-code.nix`, `shared/assets/skills/` | Consumer convergence/ownership |
| `docs/gentle-ai-update.md` | Gates/recovery |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| SDK/relay mismatch | High | Empirical contract proof; approved coupling only |
| Stale graph/skills | High | Rendered configuration and ownership tests |
| History/dirty-work loss | Medium | Scoped reconciliation; no branch/index mutation |

## Rollback Plan

Restore known-good Gentle pin/assets/adapters and system/HM generations without V1, namespace changes or authority-format rewrites; retain credentials, sessions, receipts, OpenSpec history and ODD documents.

## Dependencies

Revision-1 hybrid preproposal matched; exploration #3769. Installer SDK 2.0.4 equality is not Nix runtime incompatibility; contract 1.2 is not SDK compatibility proof.

## Success Criteria

- [ ] Native Linux/Darwin builds; focused graph/registry/permissions/ODD recovery tests.
- [ ] Flake check; all-host system, integrated and standalone HM evaluations.
- [ ] Authorized native delegation/reviewer/refuter/validator receipts and fail-closed negatives; unavailable host evidence remains UNVERIFIED.
- [ ] Pin, namespace, history and rollback preservation demonstrated.
