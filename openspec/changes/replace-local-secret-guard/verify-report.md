```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:58e135879175f8c6eb3fc095fa05432752f9d89ee333d2544389517a176a82e4
verdict: fail
blockers: 2
critical_findings: 2
requirements: 0/5
scenarios: 0/9
test_command: "not run: full verification is blocked by unchecked tasks 3.3 and 4.2"
test_exit_code: 125
test_output_hash: sha256:2b86bf5dd336fb5d39ef3b6cadada24f42c69e433d444a63bf6c29dc967ab228
build_command: "not run: Darwin runtime and build validation are unavailable from this Linux executor"
build_exit_code: 125
build_output_hash: sha256:9b00a7a07dcdd43f729f3a2e239545c8e9a0f02483939eee9094b1c23ca56ae2
```

## Verification Report

**Change**: replace-local-secret-guard
**Mode**: Standard

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 11 |
| Tasks complete | 9 |
| Tasks incomplete | 2 (3.3, 4.2) |

### Recorded and Static Evidence

Linux implementation inspection matches the design: the exact Warden pin and integrity hash are declared, the shared Linux and Darwin module lists import the same profile, the local asset and exports are removed, legacy runtime cleanup is explicit, and permission denies remain intact. Apply recorded successful Linux package, activation, runtime-smoke, formatting, and flake-evaluation checks; these are historical context, not current independent runtime evidence.

### Spec Compliance Matrix

| Requirement | Scenarios | Result |
|-------------|-----------|--------|
| Reproducible Warden Availability | Linux; Darwin | ❌ UNTESTED in this verification run |
| Shared Host Coverage | Configuration coverage | ❌ UNTESTED in this verification run |
| Local Secret Guard Retirement | Startup; artifact audit | ❌ UNTESTED in this verification run |
| Defense-in-Depth Secret Protections | Redaction; SOPS environment; sensitive paths | ❌ UNTESTED in this verification run |
| Measurable Cross-Platform Validation | Validation evidence | ❌ UNTESTED: mact2 was not evaluated |

### Issues Found

**CRITICAL**: Task 3.3 remains unchecked because mact2 SSH is unavailable from this Linux executor; its required Darwin startup, redaction, environment, and protected-path smoke did not run.

**CRITICAL**: Task 4.2 remains unchecked because the required Darwin toplevel build/evaluation cannot run on Linux: the pinned x86_64-darwin derivation reports a platform mismatch. The recorded direct Linux toplevel build does not satisfy the Darwin requirement.

### Verdict

FAIL — Full verification is blocked until mact2 executes tasks 3.3 and 4.2.
