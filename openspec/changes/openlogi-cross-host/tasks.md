# Tasks: OpenLogi on t14 and macm5

## Review Workload Forecast

| Field | Value |
|---|---|
| Estimated changed lines | 70–150 authored lines (including the new module) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single focused change |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|---|---|---|---|---|---|
| 1 | Pin and wire platform ownership | Single PR | nix flake check --no-build plus scoped evals | N/A: deployment forbidden | Revert the five scoped files only |
| 2 | Prove package and preserve deferred native gates | Single PR | Exact t14 package build | N/A: no native deployment/session authorized | Remove OpenLogi input/module/import/cask |

## Phase 1: RED assertions and baseline

- [x] 1.1 Preserve unrelated dirty work; capture prechange file/lock snapshots and assert only `flake.nix`, `flake.lock`, `linux/system/hardware/openlogi.nix`, `hosts/t14/default.nix`, and `darwin/system/homebrew.nix` may change.
- [x] 1.2 Add/run failing inline assertions for t14/macm5 ownership, rog/thinkcentre exclusion, mutable settings, unchanged Homebrew rolling policy, and no competing Darwin LaunchAgent/broad permissions; record the N/A process threat rows (documentation, repository selection, commit, push, PR) as no RED tests.
- [x] 1.3 Assert the lock baseline is unchanged except OpenLogi and necessary dependency nodes/edges, and assert Linux uses upstream v0.8.11 commit `7a9d092a7dda0cb3b7ec18ada4424d681fca65ca`.

## Phase 2: Minimal implementation

- [x] 2.1 Modify `flake.nix` and `flake.lock` with a narrow OpenLogi pin/follows update; do not update unrelated inputs.
- [x] 2.2 Create `linux/system/hardware/openlogi.nix` importing the upstream module and enabling defaults; retain mutable GUI ownership, seat-scoped upstream access, and no custom mappings or forced device defaults.
- [x] 2.3 Add exactly one explicit import in `hosts/t14/default.nix`; leave rog, thinkcentre, builders, shared Home Manager lists, and generated hardware untouched.
- [x] 2.4 Add only the native `openlogi` cask to `darwin/system/homebrew.nix`; preserve existing autoUpdate/upgrade/cleanup and embedded Login Item ownership.

## Phase 3: Verification and gates

- [x] 3.1 Make RED assertions pass; format touched Nix files, run `nix flake check --no-build`, and evaluate t14/macm5 plus exclusion checks for rog/thinkcentre.
- [x] 3.2 Verify package/udev membership, exact agent ExecStart and graphical-session dependencies, cask membership, and unchanged rolling policy through scoped evaluations.
- [x] 3.3 Build exactly `.#nixosConfigurations.t14.config.programs.openlogi.package`; record result separately from evaluation. Use only an existing safe read-only native Darwin build proof if available; otherwise explicitly defer it.
- [x] 3.4 Keep deployment, commit, push, and native runtime/device checks deferred: later authorized gates must cover one agent, seat/socket isolation, Hyprland foreground backend, macOS privacy grants, persistence/backups, and K780/G305/G502 evidence without permission widening or operations now.

## Phase 4: Recovery

- [x] 4.1 Document predeployment retained generations, signed macOS artifact/config backups, owner shutdown before manager restoration, and separate mutable-state/Login Item/TCC recovery; do not execute recovery.
