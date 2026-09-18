```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:ce42367910ef57df82c5084d9cea9b07f10556e8720665e96e918ba909bf328f
verdict: pass
blockers: 0
critical_findings: 0
requirements: 6/6
scenarios: 10/10
test_command: go -C pkgs/nixos-scripts test -count=1 ./...
test_exit_code: 0
test_output_hash: sha256:213bb5f9f01d92cb41ea6825f809978f9eadff82b2929def2adff793e4690e93
build_command: nix build .#nixos-scripts --no-link
build_exit_code: 0
build_output_hash: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

## Verification Report

**Change**: managed-agent-worktrees
**Mode**: Standard (`strict_tdd: false`)
**Evidence scope**: Current `master` HEAD `0df2de389d51a484d0ec97fa8d36cf7be7910d9c`; implementation commit `fbd2644` is an ancestor of `origin/master`.

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 14 |
| Tasks complete | 14 |
| Tasks incomplete | 0 |

### Build & Tests Execution

**Tests**: Passed — `go -C pkgs/nixos-scripts test -count=1 ./...` exited 0. This includes command-level temporary-Git-repository coverage for unique/conflicting dispatch, lifecycle-lock contention and legacy prune, retained failed integration, allowlisted checks, denied mutation before execution, ready integration, and unsafe integration rejection.

**Build**: Passed — `nix build .#nixos-scripts --no-link` exited 0. Its command emitted no output; the recorded SHA-256 is the empty-output digest.

**Configuration checks**: `nix fmt -- --ci` completed with 0 changed files and `nix flake check --no-build` passed. The t14 generated managed-writing-task permission JSON is default-deny for Bash and external directories, with only the intended grants. A Linux-host attempt to evaluate the Darwin toplevel reached a foreign-platform `aarch64-darwin` derivation mismatch, not the prior undefined-`awk` failure.

**Native Darwin operator evidence**: The operator reports successful deployment on macm5. Per instruction, this is accepted as evidence that native `aarch64-darwin` Darwin configuration evaluation/build and Home Manager activation succeeded. It closes the prior cross-platform-only blocker.

### Spec Compliance Matrix

| Requirement | Scenario | Test / evidence | Result |
|-------------|----------|-----------------|--------|
| Unique Task Workspace | Dispatch independent writing tasks | `TestManagedCommandDispatchAndConflicts` creates independent task branches and worktrees. | ✅ COMPLIANT |
| Unique Task Workspace | Reject conflicting task identity | `TestManagedCommandDispatchAndConflicts` rejects mismatched recorded metadata. | ✅ COMPLIANT |
| Portable Lifecycle Control | Serialize concurrent lifecycle operations | `TestLegacyPruneUsesManagedLifecycleLock` proves managed transitions and legacy pruning contend on one common-directory lock. | ✅ COMPLIANT |
| Portable Lifecycle Control | Preserve interrupted task work | `TestManagedCommandReadyIntegrationAndFailureRetention` preserves ready state and the worktree after validation failure. | ✅ COMPLIANT |
| Managed Agent Capability Boundary | Run an allowlisted local check | `TestManagedCommandCheckAllowlistAndDenial` executes an allowlisted scoped eval. | ✅ COMPLIANT |
| Managed Agent Capability Boundary | Deny a host-mutating request | `TestManagedCommandCheckAllowlistAndDenial` rejects `switch` before the fake Nix executable runs. | ✅ COMPLIANT |
| Human Serialized Integration Gate | Integrate a ready task | `TestManagedCommandReadyIntegrationAndFailureRetention` integrates a ready branch with validation. | ✅ COMPLIANT |
| Human Serialized Integration Gate | Reject unsafe integration | `TestManagedCommandRejectsDirtyNonReadyAndBranchMismatch` covers dirty, non-ready, and branch-mismatch rejection. | ✅ COMPLIANT |
| Portable Baseline Scope | Evaluate the portable policy | Shared declarative source and generated policy evaluation pass; successful native macm5 deployment/activation is accepted operator evidence for Darwin. | ✅ COMPLIANT |
| Managed Writing-Agent Profile | Emit the restricted agent profile | Current generated t14 JSON has default-deny Bash/external-directory policy and required local grants; macm5 activation confirms declarative Home Manager delivery. | ✅ COMPLIANT |

**Compliance summary**: 10/10 scenarios compliant.

### Correctness and Design Coherence

| Area | Status | Evidence |
|------|--------|----------|
| Lifecycle and common-directory lock | ✅ Implemented | State records and portable mkdir lock are under the Git common directory; legacy prune shares the lock. |
| Default-deny managed agent | ✅ Implemented | Shared declarative profile and generated JSON match the specified boundary. |
| Human serialized integration | ✅ Implemented | The command validates main checkout, ready state, and branch before non-activating validation; tests cover rejection and retention. |
| Cross-platform baseline | ✅ Implemented | Linux verification plus accepted native macm5 deployment evidence; no sandboxing or daemon concurrency change was introduced. |

### Delivery and Current-State Evidence

`fbd2644` is an ancestor of `origin/master`; local `HEAD` and `origin/master` both resolve to `0df2de389d51a484d0ec97fa8d36cf7be7910d9c`, and `git ls-remote origin refs/heads/master` returns that same SHA. Therefore the implementation is recorded as pushed. `git diff --check` passed. Existing untracked files are outside this change and were excluded; no implementation or unrelated file was modified during verification.

### Issues Found

**CRITICAL**: None.

**WARNING**: The Linux verifier cannot directly produce an `aarch64-darwin` derivation because of platform mismatch. This is not the former `awk` evaluation blocker and is closed for this change by accepted operator evidence of successful native macm5 deployment and Home Manager activation.

**SUGGESTION**: None.

### Verdict

PASS

All 14 tasks are complete, runtime tests and package build passed on the current pushed commit, and the accepted native macm5 deployment evidence closes the last Darwin/Home Manager scenario.
