# Apply Progress: dedup-structure

## Mode
Standard (no strict TDD).

## Completed Tasks
- [x] 1.1 Shared Nix resilience
- [x] 1.2 Shared cachix
- [x] 1.3 Shared GitHub tokens
- [x] 2.1 `baseHomeConfig` for all standalone HM
- [x] 2.2 Common package set
- [x] 2.3 Remote-desktop audit comments
- [x] 3.1 `nix flake check --no-build` after each commit

## Files Changed
| File | Action |
|------|--------|
| `shared/nix-resilience.nix` | Created |
| `shared/cachix.nix` | Created |
| `shared/github-tokens.nix` | Created |
| `linux/system/base/nix.nix` | Import shared resilience |
| `darwin/system/nix.nix` | Import shared resilience |
| `linux/system/base/cachix.nix` | Import shared cachix, drop enable option |
| `darwin/system/cachix.nix` | Import shared cachix |
| `shared/sops.nix` | Import shared github-tokens |
| `linux/system/base/sops.nix` | Import shared github-tokens |
| `flake.nix` | Use `baseHomeConfig` for rog/thinkcentre/t14 |
| `lib/packages.nix` | Use `commonPackages` |
| `linux/home/remote-desktop.nix` | Audit comment |
| `darwin/home/remote-desktop.nix` | Audit comment |

## Work Unit Evidence
| Unit | Focused test | Runtime harness | Rollback boundary |
|------|--------------|-----------------|-------------------|
| 1 | `nix flake check --no-build` | N/A | Files in unit 1 |
| 2 | `nix flake check --no-build` | N/A | Files in unit 2 |
| 3 | `nix flake check --no-build` | N/A | `flake.nix` |
| 4 | `nix flake check --no-build` | N/A | Files in unit 4 |
| 5 | `nix flake check --no-build` | N/A | `lib/packages.nix` |
| 6 | `nix flake check --no-build` | N/A | Both `remote-desktop.nix` |

## Deviations from Design
None.

## Issues Found
- Pre-existing untracked files (`linux/system/hardware/adb.nix`, `docs/adb-setup.md`) had to be staged so `nix flake check` could evaluate the current tree. They were not committed as part of this change.

## Status
6/6 tasks complete. Ready for verify.
