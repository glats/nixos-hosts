# Tasks: Cheap Orchestrator and OmO Pilot

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 150–220 authored lines (including JSONC and npm pin) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single commit directly on master |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main (single commit; no chain) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: stacked-to-main
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Complete all four stages | Single commit | `format-nix && nix flake check --no-build` | rog OpenCode debug/OmO doctor checks | Revert touched files; restore 1.18.18, Flash, or rog flag |

## Phase 1: Binary Pin and Plugin Gate

- [x] 1.1 Write the RED npm supply-chain check: a deliberately wrong SRI for `pkgs/opencode-npm-packages/node-modules.json` must make the Nix build fail.
- [x] 1.2 Write the RED plugin acceptance check for `engram.ts`, `rtk.ts`, `secret-guard.ts`, `skill-registry.ts`, and `sdd-task-result-artifacts.ts`; load/schema failure must fail the gate.
- [x] 1.3 Update `pkgs/opencode/default.nix` to 1.18.22 and resolve all four platform SRIs with the design-specified prefetch/hash conversion; run the plugin gate and `opencode --version` on rog.

## Phase 2: Orchestrator Swap

- [x] 2.1 Change `gentle-orchestrator` from `opencode-go/glm-5.3-flash` to `opencode-go/kimi-k3` in the three tiers that used Flash as orchestrator (`opencode-go-openai`, `high-volume`, `openai-opencode-balanced`) in `shared/opencode/providers-base.nix`, preserving all other mappings and documenting the guarded rationale (amended 2026-09-10 per user: best model on the Go catalog, extended to all glm-5.3-flash orchestrator tiers; rollback unchanged).
- [x] 2.2 Evaluate rog routing and run delegation, retry, gate, no-early-exit, and measured-cost checks ($0.28/M versus $0.50/M); restore Flash if any check fails.

## Phase 3: OmO Declarative Integration

- [x] 3.1 Pin `oh-my-opencode` 4.19.4 and its SRI in `pkgs/opencode-npm-packages/versions.json` and `node-modules.json`; rerun the wrong-hash RED check with the real pin.
- [x] 3.2 Add default-off `home.opencode.omo.enable` in `shared/opencode.nix`, mirror the active-provider option pattern, and conditionally set `OMO_DISABLE_POSTHOG=1`.
- [x] 3.3 Update `shared/opencode/plugins.nix` and `runtime-config.nix` to conditionally register `oh-my-openagent` and generate `~/.omo/omo.jsonc` with the exact telemetry, MCP, hook, Team Mode, and active-tier category policy; do not invoke an installer.

## Phase 4: Host Enablement

- [x] 4.1 Set `home.opencode.omo.enable = true` only in `hosts/rog/home/default.nix`; leave thinkcentre, t14, mact2, and `shared/claude-code.nix` (read-only) untouched.

## Phase 5: Verification and Rollout Gate

- [x] 5.1 Evaluate rog and default-off host outputs: rog has the plugin/config/env and correct models; thinkcentre, t14, and mact2 have none of the three artifacts.
- [x] 5.2 Run the pinned OmO `doctor --verbose` runtime check on rog, then `format-nix && nix flake check --no-build`; stop on failure and apply the documented stage rollback.
