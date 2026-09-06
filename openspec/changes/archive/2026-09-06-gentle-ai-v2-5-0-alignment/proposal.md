# Proposal: Gentle AI v2.5.0 Alignment

## Intent

Align the declarative runtime with Gentle AI v2.5.0. The `main@26d7c` pin leaves plugins unwired, emits deprecated agent `tools`, and documents v1. Home Manager remains the sole deployment authority on all four hosts.

## Scope

### In Scope
- Pin `gentle-ai-src` to tag `v2.5.0`, update `flake.lock`, and recompute the Go `vendorHash`.
- Add off-by-default options/assets for `model-variants`, `opencode-review-transport`, `sdd-task-result-artifacts`, and `skill-registry`; default the last two on.
- Remove `backgroundAgents`, its stale warning, and the ghost plugin entry; explicitly delete `background-agents.ts` during activation.
- Migrate agent merging from `tools` to permission grants, gated by inspection of built `opencode.json`.
- Rewrite `docs/gentle-ai-update.md` for tagged v2.x updates and t14-first canary rollout.

### Out of Scope
- Theme, GGA (`providers-base.nix` substitutes), other agents’ assets, `sdd-overlay-multi.json`, and doctor false positives.
- The pre-existing missing `sdd-research` phase model; track separately.
- Running `gentle-ai install/sync` on hosts or changing the unrelated nixpkgs 26.05 pin.

## Capabilities

### New Capabilities
- `gentle-ai-declarative-runtime`: Pinned assets, plugin lifecycle, command retirement, and permission-preserving agents.

### Modified Capabilities
- None; canonical specs cover unrelated behavior.

## Approach

Update the shared input used by `pkgs/gentle-ai/default.nix` (`buildGoModule`, `cmd/gentle-ai`) and `pkgs/gentle-ai-assets/default.nix` (copied tool/skill assets); only the former needs a new hash. Claude cleanup retires 11 unprefixed `sdd-*.md` commands. Use `disabledManagedPluginNames` for plugins. Prove permissions from t14’s generated configuration, then run `format-nix && nix flake check --no-build`. The 200–300 line forecast is below budget; `sdd-tasks` owns delivery strategy.

## Affected Areas

| Area | Impact |
|---|---|
| `flake.nix`, `flake.lock`, `pkgs/gentle-ai/default.nix` | Pin and hash updated |
| `shared/opencode/`, `shared/opencode-profile.nix` | Plugins and permissions aligned |
| `shared/claude-code.nix` | Unchanged cleanup exercised |
| `docs/gentle-ai-update.md` | Workflow rewritten |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Vendor hash mismatch | High initially | Recompute from Nix’s expected failure. |
| Subagents lose write/edit grants | Medium, highest impact | Build/evaluate t14 and inspect every generated agent permission. |
| Two plugin assets drift from old pin | Medium | Land source bump and plugin wiring atomically. |

## Rollback Plan

Disable the four plugins and activate so `disabledManagedPluginNames` removes their files. Restore `gentle-ai-src` to `main@26d7c…`, run `nix flake lock --update-input gentle-ai-src`, restore the prior hash/overlays/plugin definitions, and rebuild. No imperative state requires recovery.

## Dependencies

- Gentle AI tag `v2.5.0` (`f5dd1a6c`) and Nix builds.

## Success Criteria

- [ ] All hosts evaluate; t14’s built `opencode.json` preserves grants without agent `tools`.
- [ ] Four upstream plugins are manageable, two SDD plugins default on, and `background-agents.ts` is absent.
- [ ] Claude’s 11 obsolete command files are retired on activation.
- [ ] Formatting/checks pass and docs describe the v2.x workflow.
