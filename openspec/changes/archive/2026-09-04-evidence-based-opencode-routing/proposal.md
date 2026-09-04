# Proposal: Evidence-Based OpenCode Routing

## Intent

Replace the SDD profile catalog with evidence-backed profiles without duplicate names or broken host selections. Replaced definitions disappear; unrelated older profiles remain legacy entries.

## Scope

### In Scope
- Add a canonical, explicit-phase catalog near the start of `shared/opencode/providers-base.nix`.
- Add unique `opencode-free`, `work-copilot-anthropic`, Anthropic, `reliable`, `high-volume`, `quality`, and `cross-provider-review` profiles; retain justified `openai-opencode-balanced`.
- Replace the old `alpha-free` and old `opencode-free` definitions with one new `opencode-free`; replace `anthropic-copilot` with `work-copilot-anthropic`.
- Keep non-replaced profiles at the bottom as marked legacy definitions.
- Atomically migrate `t14` to `opencode-free` and `mact2` to `work-copilot-anthropic`; update other consumers if needed.

### Out of Scope
- Retaining aliases or duplicate definitions for replaced profile names.
- Dynamic routing, quota-aware selection, or provider failover.
- Secret/authentication changes or production activation.

## Capabilities

### New Capabilities
- `opencode-routing-profiles`: Defines manual profiles, legacy entries, and migration.

### Modified Capabilities
- `opencode-runtime-proxy`: Preserve non-proxy OpenCode behavior while profile selections are migrated.

## Approach

Place canonical mappings first and legacy mappings last; each name occurs once and maps every SDD phase. Fold both free predecessors into `opencode-free`, rename the Anthropic/Copilot profile, then update consumers in the same patch. Favor validated transports and tool loops; allocate Anthropic Haiku/Sonnet/Opus tiers appropriately.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `shared/opencode/providers-base.nix` | Modified | Unique catalog; replacements removed; other profiles legacy. |
| `shared/opencode/agents.nix` | Verified | Phase projection remains compatible. |
| `hosts/t14/home/default.nix` | Modified | Migrate `alpha-free` to canonical `opencode-free`. |
| `hosts/mact2/default.nix` | Modified | Migrate `anthropic-copilot` to `work-copilot-anthropic`. |
| `rog`, `thinkcentre`, `darwin/default.nix`, `flake.nix` | Verified/Modified | Update if a replaced name is used. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Provider access varies by account | Medium | Keep manual selection, validate mappings, retain legacy profiles. |
| Free gateway/tool instability | Medium | Use validated mappings; document limits and rollback. |
| Rename breaks an override | Medium | Migrate all replaced references atomically; evaluate the flake. |

## Rollback Plan

Revert the catalog and reference migrations together. Do not roll back to aliases: replacements are intentionally absent. Non-replaced legacy profiles remain selectable.

## Dependencies

- Provider availability and validated model tool/subagent behavior.
- `format-nix` and `nix flake check --no-build` for Nix evaluation.

## Success Criteria

- [ ] New profiles explicitly map every SDD phase and neutral agent.
- [ ] Exactly one canonical `opencode-free` replaces both prior free definitions, and no `alpha-free` remains.
- [ ] `work-copilot-anthropic` replaces `anthropic-copilot`, with no stale references.
- [ ] Only non-replaced profiles remain as legacy entries at the bottom of the catalog.
- [ ] Affected NixOS, Darwin, and standalone HM configurations have no missing profile reference.
- [ ] `format-nix` and `nix flake check --no-build` pass.
