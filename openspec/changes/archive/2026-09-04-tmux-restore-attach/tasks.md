# Tasks: Reliable tmux Session Recovery

## Review Workload Forecast

| Field | Value |
|---|---|
| Estimated changed lines | ~120-220 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|---|---|---|---|---|---|
| 1 | Add shared `tmux-resume` shell logic and messages in `shared/shell-aliases.nix`. | PR 1 | `nix flake check --no-build` | Stubbed zsh + fake `tmux` cold-start script | Remove the function block only |
| 2 | Keep HM exposure homogeneous on Linux and `mact2` via `linux/home/shell.nix` and `darwin/home/shell.nix`. | PR 1 | `nix build .#homeConfigurations.rog.activationPackage` and `nix build .#homeConfigurations.mact2.activationPackage` | Login shell on rog and mact2 | Revert the minimal wiring/import change |
| 3 | Add regression coverage for retry, success, timeout, missing snapshot, and genuine tmux error paths. | PR 1 | `nix flake check --no-build` | Fake `tmux` shim + temp snapshot files | Delete the test harness/fixtures |

## Phase 1: HM Wiring and Contract Check

- [x] 1.1 Verify `shared/shell-aliases.nix` is reached by both `linux/home/shell.nix` and `darwin/home/shell.nix` so `tmux-resume` is exported identically on Linux and `mact2`.
- [x] 1.2 Apply only the minimal wiring fix needed to keep the shared command available on every configured host.

## Phase 2: Shared zsh Function Implementation

- [x] 2.1 Add `tmux-resume()` in `shared/shell-aliases.nix` as a shared zsh function with bounded retries around `tmux has-session` and `tmux attach`.
- [x] 2.2 Emit explicit stderr messages for missing `tmux`, timeout while restore is in progress, no snapshot found, and real tmux failures.
- [x] 2.3 Keep native `tmux a` untouched and do not call `tmux new-session -A` or Resurrect restore directly.

## Phase 3: Tests and Validation

- [x] 3.1 Add a shell regression harness that stubs `tmux` and proves cold-start retry, attach-after-restore, timeout, and fail-fast branches.
- [x] 3.2 Validate both host paths with the relevant Home Manager build checks for `rog` and `mact2`.
- [x] 3.3 Run `format-nix && nix flake check --no-build` for any touched `.nix` files.

## Phase 4: Cleanup

- [x] 4.1 Remove any temporary debug output or scratch files after verification.
- [x] 4.2 Keep final user-facing command and failure text documented in the touched shell module comments if needed.
