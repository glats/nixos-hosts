# Tasks: Centralize Cross-Platform tmux TPM

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 220–320 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR: RED tests → shared/leaf refactor → verification |
| Delivery strategy | single-pr |
| Chain strategy | pending; single PR remains under the review budget |

Decision needed before apply: No — user explicitly approved the single work unit
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Add threat RED tests and static assertions | PR 1 | `go -C pkgs/nixos-scripts test ./...` | N/A; tests are pre-implementation guards | Revert test-only files |
| 2 | Apply clone-only activation and preserve runtime PATH | PR 1 | `go -C pkgs/nixos-scripts test ./internal/tmuxtapm` | Temporary-home activation; no tmux server | Revert `shared/tmux.nix` and its test changes |
| 3 | Prove macm5 interactive installation and host evals | PR 1 | Targeted `nix eval` drvPaths | Physical macm5 switch, reload/start tmux, `prefix + I` | Revert only this change; preserve plugin state |

## Phase 1: RED Tests / Safety Guards

- [x] 1.1 Create `pkgs/nixos-scripts/internal/tmuxtapm/tmuxtapm_test.go`; reject caller paths and preserve non-Git targets.
- [x] 1.2 Add clone/installer failure tests; require nonzero activation and preserved state.
- [x] 1.3 Add static assertions for seven repositories, final loader, activation ordering, and leaf ownership.

## Phase 2: Shared Implementation

- [x] 2.1 Make `shared/tmux.nix` own declarations, path, loader, and fixed-target clone guard.
- [x] 2.2 Preserve Linux `escapeTime = 0` and integration in `linux/home/tmux.nix`.
- [x] 2.3 Preserve Darwin `escapeTime = 10`, shim, and helpers in `darwin/home/tmux.nix`.
- [x] 2.4 Evaluate `hosts/t14/home/omarchy.nix`; retain the shared declaration and narrow any proven conflict fix.

- [x] 2.5 Add guarded tmux-server Nix `PATH` and `TMUX_NIX_RUNTIME_PATH` in `shared/tmux.nix`; preserve inherited PATH and loader order.

## Phase 2A: Revised Apply (Clone-Only Lifecycle)

- [x] 2.6 RED: in `pkgs/nixos-scripts/internal/tmuxtapm/tmuxtapm_test.go`, assert activation never calls `bin/install_plugins`.
- [x] 2.7 Apply `shared/tmux.nix`: retain fixed clone validation/order/failure propagation; remove activation installation and activation-only tmux environment.
- [x] 2.8 Leave plugin installation to configured tmux `prefix + I`; do not change the three platform files.

## Phase 3: Verification / Rollout

- [x] 3.1 Run `nix fmt -- shared/tmux.nix` and focused drvPath evals for `rog`, `thinkcentre`, `t14`, and `macm5`; record any unchanged macm5 blocker.
- 3.1 evidence: `nix fmt -- shared/tmux.nix` passed; Linux drvPath evals passed for `rog`, `thinkcentre`, and `t14`. macm5 drvPath evaluation remains unavailable from this Linux host because the Darwin configuration is not evaluable here; physical macm5 still needs the rollout evidence.
- [x] 3.2 Historical runtime tests proved clone/reuse and failure preservation; revised apply must replace the old installer-success assertion.
- [x] 3.3 Run `nix flake check --no-build`; PASS (`all checks passed!`); rollback only by reverting the four configuration files, never deleting `$HOME/.config/tmux/plugins`.
- [x] 3.4 Run `go -C pkgs/nixos-scripts test ./internal/tmuxtapm -run 'TestCanonicalTPMDeclarations|TestTPMRuntimePathIsGuardedAndInherited|TestRealTPMRuntime'`; prove clone-only, no installer, reuse, and preservation.
- [ ] 3.5 On physical macm5 run `home-manager switch --flake .#macm5`; capture clean activation, then reload/start tmux and press `prefix + I` to capture seven-plugin installation.
