# Proposal: Cheap Orchestrator and OmO Pilot

## Intent

Reduce rog's orchestration cost on mandatory OpenCode Go, align the binary and 1.18.22 SDK/plugin surface, and evaluate oh-my-openagent declaratively.

## Scope

### In Scope
- Bump the custom binary exactly to 1.18.22 with four platform hashes, then verify all five managed plugins load.
- Change `gentle-orchestrator` from `opencode-go/glm-5.3-flash` to `opencode-go/kimi-k3` in exactly three tiers (`opencode-go-openai`, `high-volume`, `openai-opencode-balanced`) — user amendment 2026-09-10: best-capability model on the Go catalog, superseding the MiMo-V2.5 cheap pilot; accept only after delegation, retry, gate, and no-early-exit checks.
- Add `home.opencode.omo.enable` (default false), enable it only on rog, and configure OmO without its installer.
- Disable telemetry, Team Mode, duplicate MCPs, and AGENTS/rules injection; retain LSP and map categories to existing tiers.

### Out of Scope
- Claude Code, non-rog routing/OmO, parallel stacks, forks, Gentle AI sync/install, SOPS, and hardware configuration.

## Capabilities

### New Capabilities
- `opencode-omo-pilot`: Host-scoped OmO registration, configuration, telemetry controls, and category routing.

### Modified Capabilities
- `opencode-routing-profiles`: Permit the guarded rog-selected legacy profile's orchestrator mapping to move from GLM-5.3-Flash to MiMo-V2.5 while preserving every other mapping.

## Approach

Execute through apply: binary alignment, orchestrator swap, then OmO enablement. Roll back failures. Never run `bunx oh-my-openagent install`.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `pkgs/opencode/default.nix` | Modified | Pin 1.18.22 and four hashes. |
| `shared/opencode/providers-base.nix` | Modified | Swap only rog's selected tier mapping. |
| `pkgs/opencode-npm-packages/{versions,node-modules}.json` | Modified | Pin OmO dependency and closure. |
| `shared/opencode.nix` | Modified | Declare host opt-in and environment. |
| `shared/opencode/plugins.nix` | Modified | Conditionally register `oh-my-openagent`. |
| `shared/opencode/runtime-config.nix` | Modified | Conditionally deploy `~/.omo/omo.jsonc`. |
| `hosts/rog/home/default.nix` | Modified | Enable the pilot. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| MiMo exits early or misses gates | Medium | Compare representative flows; restore Flash. |
| OmO conflicts or leaks telemetry | Medium | Disable duplicates, Team Mode, and telemetry twice; inspect generated config. |
| 1.18.22 breaks managed plugins | Low | Verify the five plugins before later gates. |

## Rollback Plan

- Binary: restore 1.18.18 and its four hashes.
- Routing: restore `opencode-go/glm-5.3-flash`.
- OmO: disable rog's flag, remove its option/config/plugin wiring and npm dependency; preserve unmanaged runtime state.

## Dependencies

- OpenCode 1.18.22 artifacts, pinned OmO package, and OpenCode Go access.

## Success Criteria

- [ ] OpenCode 1.18.22 loads `engram.ts`, `rtk.ts`, `secret-guard.ts`, `skill-registry.ts`, and `sdd-task-result-artifacts.ts`.
- [ ] MiMo passes delegation, retry, gate, and no-early-exit checks on rog.
- [ ] Rog gets the `oh-my-openagent` plugin entry and `~/.omo/omo.jsonc` with required disablement, telemetry, Team Mode, and category settings.
- [ ] Non-rog hosts get no OmO artifacts in their generated configs.
- [ ] `format-nix && nix flake check --no-build` passes.
