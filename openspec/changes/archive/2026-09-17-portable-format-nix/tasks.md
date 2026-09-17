# Tasks: Portable Format Nix

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 120–180 authored lines |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR: target resolution, tests, and help text |
| Delivery strategy | single-pr (`exception-ok`) |
| Chain strategy | not applicable |

Decision needed before apply: No — accepted single work unit (`exception-ok`)
Chained PRs recommended: No
Chain strategy: not applicable
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Add portable target resolution and CLI compatibility | PR 1 | `go -C pkgs/nixos-scripts test ./cmd/format-nix` | `format-nix [directory] [--check]` in temporary flake trees | Revert `cmd/format-nix/main.go` |
| 2 | Cover resolution, parsing, and preserved traversal/check behavior | PR 1 | `go -C pkgs/nixos-scripts test ./cmd/format-nix` | N/A: unit tests exercise isolated temporary trees | Revert `cmd/format-nix/main_test.go` |

## Phase 1: Boundary Tests

- [x] 1.1 In `pkgs/nixos-scripts/cmd/format-nix/main_test.go`, add RED tests proving invalid explicit targets and missing discovered flakes fail before formatter execution.
- [x] 1.2 Add RED tests for explicit-target precedence, nearest ancestor discovery, malformed arguments, duplicate directories, and help-compatible parsing.

## Phase 2: Core Implementation

- [x] 2.1 In `pkgs/nixos-scripts/cmd/format-nix/main.go`, replace the fixed `/etc/nixos` target with parsing for `format-nix [directory] [--check]`, preserving exit codes and unknown-argument errors.
- [x] 2.2 Add small helpers that validate an explicit flake directory or walk upward from cwd to the nearest `flake.nix`, stopping at filesystem root without environment fallback.
- [x] 2.3 Chdir only after successful resolution, retain `nixFiles` exclusions and per-file `nix fmt --` behavior, and update help/error text for portable targets.

## Phase 3: Verification

- [x] 3.1 Run `go -C pkgs/nixos-scripts test ./cmd/format-nix` and confirm all new tests pass while existing traversal/check-copy tests remain green.
- [x] 3.2 Run `go -C pkgs/nixos-scripts test ./...` and `nix build .#nixos-scripts` to prove package-wide tests and the deployed derivation.

## Focused Remediation: Independent Verification Failure

Failure evidence revision: `ses_f4f5f074cffeASpBjL6HvYPsQi`

- [x] 4.1 Reject an explicitly supplied empty positional directory instead of falling back to cwd discovery.
- [x] 4.2 Add focused coverage for `--check` with explicit and discovered roots, plus formatting of every eligible Nix file.
- [x] 4.3 Re-run focused/package Go tests and `nix build .#nixos-scripts`.
