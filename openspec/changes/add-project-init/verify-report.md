```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:bb9f19c97a357cc32c3be33aed35e2b89f4bff75d6db5810e1c1cb755de8e8b7
verdict: fail
blockers: 1
critical_findings: 1
requirements: 0/8
scenarios: 0/14
test_command: "go -C pkgs/nixos-scripts test ./... (not run: SDD runtime acquire blocked)"
test_exit_code: 125
test_output_hash: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
build_command: "nix flake check --no-build (not run: SDD runtime acquire blocked)"
build_exit_code: 125
build_output_hash: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

## Verification Report

**Change**: add-project-init
**Version**: N/A
**Mode**: Standard (Strict TDD disabled)

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 19 |
| Tasks complete | 19 |
| Tasks incomplete | 0 |

### Build & Tests Execution

**Build**: ➖ Not run — runtime verification attempt blocked before execution.

```text
gentle-ai sdd-attempt acquire ... --work-unit independent-final-verification
state: blocked
reason: maintainer_decision
detail: runtime objective changed without an explicit reset; the candidate has not drifted.
```

**Tests**: ➖ Not run — same blocked runtime-attempt prerequisite.

```text
No independent test process was started.
```

**Coverage**: ➖ Not available; independent runtime execution did not start.

### Spec Compliance Matrix

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Project Identification and Engram Marker | Name from --name | `TestInitCreatesEngramAndOpenSpec` (not independently run) | ❌ UNTESTED |
| Project Identification and Engram Marker | Name from directory basename | `TestInitDerivesNameFromDirectoryBasename` (not independently run) | ❌ UNTESTED |
| Target Directory Selection | Defaults to current directory | CLI dry-run harness (not independently run) | ❌ UNTESTED |
| Target Directory Selection | Missing directory rejected | `TestInitRejectsMissingDirectoryWithoutWrites` (not independently run) | ❌ UNTESTED |
| Git Context Detection | Git repository detected | `TestInitDetectsGitDirectoryFromRelativeTarget` (not independently run) | ❌ UNTESTED |
| Git Context Detection | Worktree detected via .git file | `TestHasGitRecognizesWorktreeMarker` (not independently run) | ❌ UNTESTED |
| Git Context Detection | Non-Git directory detected | CLI dry-run harness (not independently run) | ❌ UNTESTED |
| Safe Idempotence | Matching existing name is a no-op | `TestInitReportsCurrentMatchingProjectWithoutWrites` (not independently run) | ❌ UNTESTED |
| Conflicting Marker Rejection | Differing name rejected without --force | `TestInitPreservesDifferentProjectWithoutForce` (not independently run) | ❌ UNTESTED |
| Conflicting Marker Rejection | --force overwrites conflicting name | `TestInitForceOverwritesConflictingProjectWithExpectedModeAndNewline` (not independently run) | ❌ UNTESTED |
| Dry Run | Dry run writes nothing | `TestInitDryRunDoesNotWrite` (not independently run) | ❌ UNTESTED |
| OpenSpec Initialization Control | OpenSpec init skipped when config exists | `TestInitSkipsOpenSpecWhenConfigurationExists` (not independently run) | ❌ UNTESTED |
| OpenSpec Initialization Control | --no-openspec skips initialization | `TestInitNoOpenSpecSkipsInitializer` (not independently run) | ❌ UNTESTED |
| Package Wrapper Supplies Openspec | openspec resolvable at runtime | Nix derivation wrapper evaluation (not independently run) | ❌ UNTESTED |

**Compliance summary**: 0/14 scenarios compliant; source mappings are not runtime evidence.

### Correctness (Static Evidence)

| Requirement | Status | Notes |
|------------|--------|-------|
| Project Identification and Engram Marker | ✅ Implemented | `Init` derives/validates names and `writeEngramConfig` uses same-directory temporary file, chmod, close, and rename. |
| Target Directory Selection | ✅ Implemented | `main` defaults to `.` and `Init` resolves, stats, and requires a directory. |
| Git Context Detection | ⚠️ Partial | Ancestor `.git` directory/file is recognized as a boolean Git result; the public result does not distinguish repository from worktree. |
| Safe Idempotence and Conflicting Marker Rejection | ✅ Implemented | `engramState` classifies current/conflict before mutation and force gates replacement. |
| Dry Run and OpenSpec Initialization Control | ✅ Implemented | `DryRun`, `NoOpenSpec`, and existing config paths suppress process/filesystem work as designed. |
| Package Wrapper Supplies Openspec | ✅ Implemented | `default.nix` registers `cmd/project-init` and wraps it with Nixpkgs `openspec` on PATH. |

### Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Thin command adapter | ✅ Yes | `main.go` parses flags, renders output, and owns `exec.Command`; policy resides in `internal/projectinit`. |
| Atomic Engram marker write | ✅ Yes | Same-directory temp file plus rename; temporary cleanup is deferred. |
| Fixed OpenSpec argv and callback | ✅ Yes | Callback injection; production uses fixed `openspec init --tools opencode --force` with `Cmd.Dir`. |
| OpenSpec before Engram mutation | ✅ Yes | Callback failure returns before `writeEngramConfig`. |

### Issues Found

**CRITICAL**: Independent runtime verification is blocked. `gentle-ai sdd-attempt acquire` returned `state: blocked`, `reason: maintainer_decision`, because an existing unchanged candidate cannot be reset electively. No current Go test, Nix check, or runtime harness evidence exists.

**WARNING**: The specification requires classification as Git repository, Git worktree, or non-Git, but `Result.Git bool` and CLI output collapse repository and worktree into one Git classification. Source review cannot prove the specified distinct classification behavior.

**SUGGESTION**: None.

### Verdict

FAIL
All tasks are checked and source/design mappings exist, but the required independent runtime evidence was blocked before any test or build started.
