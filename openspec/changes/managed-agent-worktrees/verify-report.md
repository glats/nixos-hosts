```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:94b34a05bb44632216927bdc5d373380ce3a1558e8c5942ac83b0db6fb56ae66
verdict: fail
blockers: 0
critical_findings: 0
requirements: 5/6
scenarios: 9/10
test_command: go -C pkgs/nixos-scripts test -count=1 ./cmd/code-work ./internal/managedworktree
test_exit_code: 0
test_output_hash: sha256:34c0c11ddb8117c739dc7bc2110d9874d1b4572b5d565e258384c5b99cd4a752
build_command: nix build .#nixos-scripts --no-link
build_exit_code: 0
build_output_hash: sha256:10b94f9d3a4f08f3e94cbc5eb1c7d587de6a72b6da5a761aa0cc564f2bc06712
```

## Verification Report

**Change**: managed-agent-worktrees
**Mode**: Standard (`strict_tdd: false`)
**Previous failed evidence**: `sha256:0358998255837ace0b589a1b5d28a78c283c11fb86dfd9574bb97e34b8ce2b29`

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 14 |
| Tasks complete | 14 |
| Tasks incomplete | 0 |

### Build & Tests Execution

**Focused tests**: Passed — `go -C pkgs/nixos-scripts test -count=1 ./cmd/code-work ./internal/managedworktree` exited 0. The command-level temporary-repository tests passed, including dispatch/conflict, lifecycle lock/prune, retained failure, check allowlist/denial, successful integration, and unsafe-integration rejection.

**Full Go tests**: Passed — `go -C pkgs/nixos-scripts test -count=1 ./...` exited 0.

**Build**: Passed — `nix build .#nixos-scripts --no-link` exited 0.

**Format and flake checks**: Passed — `nix fmt -- --ci` reported `0 changed`; `nix flake check --no-build` reported `all checks passed!`; `git diff --check` exited 0.

**Configuration evidence**: Passed for the generated t14 managed-writing-task permission JSON. The macm5 Darwin toplevel evaluation still fails at `darwin/home/packages.nix:77:9` with `undefined variable 'awk'`. `git diff --name-only -- darwin/home/packages.nix` is empty, so the failure is outside this change's diff and is treated as external.

### Spec Compliance Matrix

| Requirement | Scenario | Test / evidence | Result |
|-------------|----------|-----------------|--------|
| Unique Task Workspace | Dispatch independent writing tasks | `TestManagedCommandDispatchAndConflicts` creates `alpha` and `beta` through real command dispatch in a temporary Git repository. | ✅ COMPLIANT |
| Unique Task Workspace | Reject conflicting task identity | `TestManagedCommandDispatchAndConflicts` persists conflicting base metadata and verifies re-dispatch fails. | ✅ COMPLIANT |
| Portable Lifecycle Control | Serialize concurrent lifecycle operations | `TestLegacyPruneUsesManagedLifecycleLock` holds the common-directory lock, proves `ready` and legacy `prune` fail while held, then succeed after release. | ✅ COMPLIANT |
| Portable Lifecycle Control | Preserve interrupted task work | `TestManagedCommandReadyIntegrationAndFailureRetention` fails validation and verifies ready state and worktree remain. | ✅ COMPLIANT |
| Managed Agent Capability Boundary | Run an allowlisted local check | `TestManagedCommandCheckAllowlistAndDenial` runs allowlisted `eval` in an active temporary worktree via command stub. | ✅ COMPLIANT |
| Managed Agent Capability Boundary | Deny a host-mutating request | `TestManagedCommandCheckAllowlistAndDenial` rejects `switch` before the fake Nix executable can create its marker. | ✅ COMPLIANT |
| Human Serialized Integration Gate | Integrate a ready task | `TestManagedCommandReadyIntegrationAndFailureRetention` commits, readies, integrates, validates, and asserts `integrated`. | ✅ COMPLIANT |
| Human Serialized Integration Gate | Reject unsafe integration | `TestManagedCommandRejectsDirtyNonReadyAndBranchMismatch` exercises each rejection path. | ✅ COMPLIANT |
| Portable Baseline Scope | Evaluate the portable policy | Linux flake and t14 generated-agent evaluation pass; macm5 toplevel evaluation remains externally blocked by unchanged `darwin/home/packages.nix:77`. | ⚠️ PARTIAL |
| Managed Writing-Agent Profile | Emit the restricted agent profile | t14 generated JSON contains default-deny Bash, denied external directories, and only intended local grants; profile source is shared with Darwin. | ✅ COMPLIANT |

**Compliance summary**: 9/10 scenarios compliant; the remaining configuration scenario is externally blocked, not regressed by this change.

### Correctness (Static Evidence)

| Requirement | Status | Notes |
|------------|--------|-------|
| Unique Task Workspace | ✅ Implemented | Task IDs map to `managed/<id>` and `.worktrees/managed/<id>`; command tests cover unique and conflicting dispatch. |
| Portable Lifecycle Control | ✅ Implemented | `cmdPrune` resolves the Git common directory and locks its `managed-worktrees` state directory. Both legacy `--done` and `--abort` route to it. |
| Managed Agent Capability Boundary | ✅ Implemented | Default-deny agent policy and command-level allowlist reject denied Nix operations before execution. |
| Human Serialized Integration Gate | ✅ Implemented | Ready-state integration, validation rollback, and dirty/non-ready/branch-mismatch rejection have temporary-repository runtime coverage. |
| Portable Baseline Scope | ⚠️ External evaluation gap | macm5 toplevel cannot evaluate because of unchanged invalid `awk` reference. |
| Managed Writing-Agent Profile | ✅ Implemented | Declarative named profile is emitted from shared Home Manager configuration. |

### Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Common-directory portable lifecycle lock | ✅ Yes | Legacy pruning now calls `managedCommonDir` and acquires the same `managed-worktrees` lock as managed transitions. |
| Locked lifecycle cleanup and pruning | ✅ Yes | Legacy `--done`/`--abort` now use `cmdPrune`; lock contention is covered by a command-level temporary-repository test. |
| Default-deny agent and managed check allowlist | ✅ Yes | Generated permission JSON and command tests match the specified boundary. |
| Human serialized integration | ✅ Yes | Command-level integration and rejection tests exercise the main-checkout gate. |

### Issues Found

**CRITICAL**: None.

**WARNING**: The macm5 Darwin toplevel remains unevaluable on this Linux verifier because `darwin/home/packages.nix:77` references undefined `awk`. It is demonstrably unchanged by this diff, so it is external but leaves the all-host portable-policy scenario unproven.

**SUGGESTION**: Repair the independent Darwin package reference, then re-run the macm5 toplevel evaluation to close the final scenario.

### Verdict

FAIL

The focused remediation closes the prior serialized-pruning and runtime command-test gaps. All remediation tests, full Go tests, package build, format check, and Linux flake checks pass; the canonical verification result remains FAIL only because the unchanged external macm5 evaluation error prevents full all-host runtime confirmation.
