# Tasks: Add OpenCode Harness Initializer

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~460 (282 existing uncommitted + ~180 gap tests) |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Complete `opencode-harness-init` (existing code + missing tests) | PR 1 | `go -C pkgs/nixos-scripts test ./internal/projectinit/` | `opencode-harness-init --dry-run` in a scratch dir under `/tmp` | Delete `cmd/opencode-harness-init`, `internal/projectinit`, remove `ohi`, revert `default.nix` |

## Phase 1: Reconciled Implementation (exists — verify, do not rewrite)

- [x] 1.1 `pkgs/nixos-scripts/internal/projectinit/projectinit.go` — Init policy, `engramState`, `writeEngramConfig`, `hasGit` (verified: spec states created/current/conflict/skipped, temp-file+rename, parent walk)
- [x] 1.2 `pkgs/nixos-scripts/cmd/opencode-harness-init/main.go` — flags, default `.`, dry-run rendering, `openspec init --tools opencode --force` exec adapter
- [x] 1.3 `pkgs/nixos-scripts/default.nix` — subPackage `cmd/opencode-harness-init`, `wrapProgram` PATH `openspec`
- [x] 1.4 `go -C pkgs/nixos-scripts test ./...` passes (verified `ok`)

## Phase 2: Spec Coverage Gap Tests (add to `pkgs/nixos-scripts/internal/projectinit/projectinit_test.go`)

- [x] 2.1 RED: injected failing OpenSpec callback errors; assert no `.engram/config.json` written (design OpenSpec-boundary RED)
- [x] 2.2 RED: `.git` directory ancestor detection and relative target path (threat-matrix Git row)
- [x] 2.3 Name derived from directory basename when `--name` omitted
- [x] 2.4 Nonexistent `DIRECTORY` rejected with error and zero writes
- [x] 2.5 Matching existing name reports `current` and writes nothing
- [x] 2.6 `--force` overwrites differing name; mode 0644 and trailing newline asserted
- [x] 2.7 `--no-openspec` reports `skipped` and creates no OpenSpec files
- [x] 2.8 Existing `openspec/config.yaml` skips OpenSpec callback (reports `current`)
- [x] 2.9 Malformed and unreadable `.engram/config.json` surface parse/read errors

## Phase 3: Validation (spec coverage proof)

- [x] 3.1 `go -C pkgs/nixos-scripts test ./...` — full suite green after gap tests
- [x] 3.2 Harness: `opencode-harness-init --dry-run` in a scratch `/tmp` dir reports plan and writes nothing (Dry Run + non-Git scenarios)
- [x] 3.3 `nix flake check --no-build` passes; checkPhase reruns Go tests
- [x] 3.4 Trace every Requirement/Scenario in `openspec/changes/add-project-init/specs/project-initialization/spec.md` (read-only) to a passing test or harness run

## Phase 5: Command Naming

- [x] 5.1 Rename the packaged command from `project-init` to `opencode-harness-init`; retain no compatibility binary.
- [x] 5.2 Add the cross-platform `ohi` zsh alias in `shared/shell-aliases.nix`.

## Phase 4: Cleanup

- [x] 4.1 `nix fmt -- pkgs/nixos-scripts/default.nix`
- [x] 4.2 Remove scratch harness dirs under `/tmp`
