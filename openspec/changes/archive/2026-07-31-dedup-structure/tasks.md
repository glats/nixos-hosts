# Tasks: dedup-structure

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~250 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

## Suggested Work Units

| Unit | Goal | Focused test | Rollback boundary |
|------|------|--------------|-------------------|
| 1 | Shared Nix resilience | `nix flake check --no-build` | `shared/nix-resilience.nix` + both `nix.nix` |
| 2 | Shared cachix | `nix flake check --no-build` | `shared/cachix.nix` + both `cachix.nix` |
| 3 | `baseHomeConfig` for all standalone HM | `nix flake check --no-build` | `flake.nix` |
| 4 | Shared GitHub tokens | `nix flake check --no-build` | `shared/github-tokens.nix` + both sops files |
| 5 | Common package set | `nix flake check --no-build` | `lib/packages.nix` |
| 6 | Remote-desktop audit | `nix flake check --no-build` | Comments in both `remote-desktop.nix` |

## Phase 1: Shared Extracts

- [x] 1.1 Create `shared/nix-resilience.nix`; import from `linux/system/base/nix.nix` and `darwin/system/nix.nix`.
- [x] 1.2 Create `shared/cachix.nix`; import from both `cachix.nix` files.
- [x] 1.3 Create `shared/github-tokens.nix`; import from `shared/sops.nix` and `linux/system/base/sops.nix`.

## Phase 2: Core Refactors

- [x] 2.1 Refactor `flake.nix` so rog/thinkcentre/t14 use `baseHomeConfig`.
- [x] 2.2 Refactor `lib/packages.nix` to expose a `commonPackages` set used by both platforms.
- [x] 2.3 Add audit comments to both `remote-desktop.nix` files.

## Phase 3: Verification

- [x] 3.1 Run `nix flake check --no-build` after every commit.
