# Tasks: homologate-host-patterns

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~50 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Absorb darwin config into mact2 | PR 1 | `nix flake check --no-build` | N/A — pure path refactor | `hosts/mact2/default.nix` revert |
| 2 | Remove old entry point | PR 1 | `nix flake check --no-build` | N/A | `lib/mkDarwinHost.nix` revert |
| 3 | Delete darwin/default.nix | PR 1 | `nix flake check --no-build` | N/A | `git revert` restore file |

## Phase 1: Absorb

- [ ] 1.1 Copy `darwin/default.nix` body into `hosts/mact2/default.nix`
- [ ] 1.2 Rewrite 7 import paths: `./` → `../../darwin/`

## Phase 2: Remove

- [ ] 2.1 Delete `../darwin` import from `lib/mkDarwinHost.nix` line 32

## Phase 3: Delete + Verify

- [ ] 3.1 Delete `darwin/default.nix`
- [ ] 3.2 Run `nix flake check --no-build` — must exit 0
