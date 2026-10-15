```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:add3053d85f07cee06903be122e138dd2362debd4101d27b42c928314b1d06e0
verdict: fail
blockers: 1
critical_findings: 3
requirements: 0/5
scenarios: 0/9
test_command: go -C pkgs/nixos-scripts test ./...; nix flake check --no-build
test_exit_code: 125
test_output_hash: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
build_command: go -C pkgs/nixos-scripts build ./cmd/code-work; nixos-build dry
build_exit_code: 125
build_output_hash: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

## Verification Report

**Change**: simplify-worktree-cli
**Mode**: Standard

### Completeness
| Metric | Value |
|---|---:|
| Tasks total | 19 |
| Tasks complete | 19 |
| Tasks incomplete | 0 |

### Runtime Evidence
Current independent test and build execution was not run. The required `gentle-ai sdd-attempt acquire` preflight stopped before execution because untracked files require a canonical inventory; the mandated `gentle-ai review status` inventory command then failed with `immutable_review_transport_unsupported` for `openai/gpt-5.6-terra`. This is an unavailable verification-tooling prerequisite, recorded as exit 125.

Previously established, non-independent evidence is acknowledged: Go tests and the code-work build passed; formatting and `nix flake check --no-build` passed; rog system and Home Manager drv-path evaluations passed; after commit `807e5ed`, native macm5 aarch64-darwin system and Home Manager drv-path evaluations passed. None can substitute for this verifier's current runtime evidence.

### Spec Compliance Matrix
| Requirement | Scenario | Runtime coverage | Result |
|---|---|---|---|
| Canonical Top-Level Command Surface | Dispatch simplified surface | Prior Go command tests; no current execution | ❌ UNTESTED |
| Canonical Top-Level Command Surface | Reject outside worktree | Prior Go command tests; no current execution | ❌ UNTESTED |
| Cwd Task Resolution | Resolve exact cwd | Prior resolver/command tests; no current execution | ❌ UNTESTED |
| Cwd Task Resolution | Refuse legacy managed names | Prior resolver/command tests; no current execution | ❌ UNTESTED |
| Shell Wrapper Verb Forwarding | Route past legacy create branch | No runtime wrapper-route test found | ❌ UNTESTED |
| Compatibility Forwarding Shim | Forward legacy invocation | Prior Go command test; no current execution | ❌ UNTESTED |
| Compatibility Forwarding Shim | Keep shim out of help | Prior Go command test; no current execution | ❌ UNTESTED |
| Managed Agent Capability Boundary | Run allowlisted local check | Prior Go admission test and declarative eval; no current execution | ❌ UNTESTED |
| Managed Agent Capability Boundary | Deny host-mutating request | Prior Go denial-before-exec test; no current execution | ❌ UNTESTED |

### Correctness and Design Coherence
Static inspection of commit `807e5ed` confirms canonical top-level dispatch and hidden help, `ResolveTaskID` uses cleaned record-path equality rather than a prefix, the shim emits one deprecation hint and preserves guarded handlers, the Linux wrapper forwards all listed canonical verbs, and the agent prompt plus canonical and temporary check permissions are present. Existing check admission, lifecycle lock, worktree lock, state transitions, merge rollback, and explicit activation gate remain in the same handlers. The committed shell wrapper has no direct automated route test; the managed-agent policy has no dynamic permission-admission test.

### Issues Found
**CRITICAL**: Independent runtime test/build verification is blocked by unavailable immutable review transport; all nine required scenarios therefore lack current passing coverage. The shell-wrapper scenario has no dedicated runtime test. Agent permission admission is only statically inspected/evaluated, not dynamically exercised.

**WARNING**: The worktree contains unrelated modifications and untracked files; they were not read, changed, staged, or included in this assessment.

### Verdict
FAIL
Independent verification cannot establish the required runtime coverage; archive is not ready.
