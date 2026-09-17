# Tasks: Centralize Cross-Platform tmux TPM

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 220–320 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR: RED tests → shared/leaf refactor → verification |
| Delivery strategy | single-pr |
| Chain strategy | not applicable; user-approved single work unit |

Decision needed before apply: No — user explicitly approved the single work unit
Chained PRs recommended: No
Chain strategy: not applicable; user-approved single work unit
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Add threat RED tests and static assertions | PR 1 | `go -C pkgs/nixos-scripts test ./...` | N/A; tests are pre-implementation guards | Revert test-only files |
| 2 | Centralize declarations/bootstrap and preserve leaf integration | PR 1 | Targeted `nix eval` for t14 and macm5 | `TestRealTPMRuntime` against temporary `$HOME` | Revert `shared/tmux.nix`, Linux/Darwin tmux files, and conditional t14 edit |
| 3 | Prove all hosts and runtime behavior | PR 1 | `nix flake check --no-build` | Run harness twice, then clone/install failure cases | Revert verification-only harness changes |

## Phase 1: RED Tests / Safety Guards

- [x] 1.1 Create `pkgs/nixos-scripts/internal/tmuxtapm/tmuxtapm_test.go` and assert only the fixed TPM target is accepted: reject relative paths, arbitrary absolute paths, and existing non-Git targets without deletion.
- [x] 1.2 Add failing process/network tests in `pkgs/nixos-scripts/internal/tmuxtapm/tmuxtapm_test.go` for clone and installer failure; require nonzero activation, preserved existing state, and no masked success or destructive cleanup.
- [x] 1.3 Add static/eval RED assertions in `pkgs/nixos-scripts/internal/tmuxtapm/tmuxtapm_test.go` covering seven repositories exactly once, final loader ordering, `home.activation.installTpm` after `linkGeneration`, and no leaf `programs.tmux.plugins` TPM values.

## Phase 2: Shared Implementation

- [x] 2.1 Modify `shared/tmux.nix` to own ordered declarations, `TMUX_PLUGIN_MANAGER_PATH`, final loader, and idempotent activation using quoted fixed paths plus store `git`/`tmux`; reject non-Git targets without deletion.
- [x] 2.2 Modify `linux/home/tmux.nix` to remove invalid activation, typed plugin strings, and forced config while retaining `escapeTime = 0` and Linux integration.
- [x] 2.3 Modify `darwin/home/tmux.nix` to remove TPM ownership while retaining `escapeTime = 10`, `.tmux.conf` shim, and Darwin helpers.
- [x] 2.4 Evaluate `hosts/t14/home/omarchy.nix`; update only its stale tmux-force comment or add a narrow override if evaluation proves a conflict.

## Phase 3: Verification / Rollout

- [ ] 3.1 Run `nix fmt -- shared/tmux.nix linux/home/tmux.nix darwin/home/tmux.nix hosts/t14/home/omarchy.nix` and focused drvPath evals for `rog`, `thinkcentre`, `t14`, and `macm5`.
- [x] 3.2 Run `go -C pkgs/nixos-scripts test ./internal/tmuxtapm -run TestRealTPMRuntime`; with temporary home, verify first activation clones/installs, second reuses checkout/plugins, and injected clone/installer failures retain state and fail.
- [x] 3.3 Run `nix flake check --no-build`; rollback only by reverting the four configuration files, never deleting `$HOME/.config/tmux/plugins`.
