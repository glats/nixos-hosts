```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:ae9edc79ddf888c0d89f8e48c42c06b070bde21ccb53d842525a2dc3c371b16d
verdict: fail
blockers: 3
critical_findings: 3
requirements: 4/7
scenarios: 8/11
test_command: go -C pkgs/nixos-scripts test ./...
test_exit_code: 0
test_output_hash: sha256:ae9edc79ddf888c0d89f8e48c42c06b070bde21ccb53d842525a2dc3c371b16d
build_command: nix flake check --no-build
build_exit_code: 0
build_output_hash: sha256:6318cb5cb2f094e9ccc2ac12d348a9c077122288b2321b74db58874584840fad
```

## Verification Report

**Change**: preserve-rog-snapshot-postmarketos-compat
**Mode**: Standard

### Completeness

| Metric | Value |
|---|---:|
| Tasks total | 9 |
| Tasks complete | 9 |
| Tasks incomplete | 0 |

### Build & Tests Execution

**Build**: Passed — `nix flake check --no-build` exited 0. Output hash: `sha256:6318cb5cb2f094e9ccc2ac12d348a9c077122288b2321b74db58874584840fad`.

**Tests**: Passed — `go -C pkgs/nixos-scripts test ./...` exited 0. Output hash: `sha256:ae9edc79ddf888c0d89f8e48c42c06b070bde21ccb53d842525a2dc3c371b16d`. `format-nix` exited 0.

**Live smoke**: Passed — `go -C pkgs/nixos-scripts run ./cmd/sync-opencode-remote` created `/home/glats/.config/opencode.bak.20260913-232533`, completed rsync, disabled BrowserMCP, removed only the two managed plugin files, and completed the existing remote steps with exit 0.

### Live Non-Secret Diagnostics

- Source and remote each contain 21 explicit `openai/*` agent model references with identical ordered-map SHA-256 `f9a4ff99261debf9ffb101c8e31fe498b04fb950dced02728d954280c130071c`, including `openai/gpt-5.6-terra` and `openai/gpt-5.6-luna`.
- Rog source BrowserMCP is enabled; remote `mcp.browsermcp.enabled` is false; `pgrep -x browsermcp` found no process.
- Remote `plugins/rtk.ts` and `plugins/skill-registry.ts` are absent.
- Remote auth metadata only: `~/.local/share/opencode/auth.json` exists with mode 600 and size 2063; its contents were not read.
- Remote `opencode auth list` reports one OpenAI oauth credential. `opencode models openai` reports 13 OpenAI catalog IDs, including `openai/gpt-5.6-terra` and `openai/gpt-5.6-luna`.

### Spec Compliance Matrix

| Requirement | Scenario | Runtime evidence | Result |
|---|---|---|---|
| Snapshot-First Transfer | Successful transfer precedes compatibility adaptation | Current live sync output ordered successful rsync before BrowserMCP disablement and fixed plugin removals | COMPLIANT |
| Snapshot-First Transfer | Failed transfer prevents compatibility adaptation | `TestSnapshotTransferFailureSuppressesCompatibility` passed | COMPLIANT |
| Snapshot-First Transfer | Rog source snapshot is retained | No runtime test captures source bytes before and after a sync | UNTESTED |
| OpenAI Model Graph Preservation | OpenAI model references remain unchanged | `TestAdaptOpencodeJSONPreservesAgentsAndDisablesBrowserMCP` passed; live source/remote map hash matches | COMPLIANT |
| Local OAuth Authentication Boundary | Compatibility does not access credentials | Metadata-only postcondition proves auth remains, but no runtime test proves no authentication-path access | UNTESTED |
| Bounded OnePlus Integration Exclusion | Exact OnePlus exclusions are applied | Live config/process/filesystem diagnostics plus focused compatibility tests passed | COMPLIANT |
| Bounded OnePlus Integration Exclusion | BrowserMCP is preserved outside the OnePlus target | Source BrowserMCP is enabled and remote BrowserMCP is disabled after the OnePlus sync | COMPLIANT |
| Bounded OnePlus Integration Exclusion | Unrelated assets are preserved | `TestCompatibilityPluginsOnlyNamedPaths` passed | COMPLIANT |
| Idempotent Compatibility State | Repeated application has no additional effect | `TestAdaptOpencodeJSONPreservesAgentsAndDisablesBrowserMCP` passed | COMPLIANT |
| Non-Mutating Dry Run | Dry run reports without changing the target | `TestApplyCompatibilityDryRunDoesNotUseSSH` passed | COMPLIANT |
| Failure and Configuration Preservation | Invalid copied configuration fails before BrowserMCP exclusion | Parser validation test passes, but no test proves backup retention and suppression of all exclusions | UNTESTED |

**Compliance summary**: 8/11 scenarios compliant.

### Correctness and Design Coherence

| Decision | Followed? | Notes |
|---|---|---|
| Preserve opaque agent models | Yes | The helper only mutates `mcp.browsermcp.enabled`; live source and remote OpenAI map hashes match. |
| Disable BrowserMCP only on OnePlus | Yes | Source is enabled, remote is disabled, and no BrowserMCP process is running. |
| Bounded runtime assets | Yes | Only `plugins/rtk.ts` and `plugins/skill-registry.ts` are removed remotely. |
| Never handle credentials | Partial | No credential content was accessed in this verification, but source lacks a runtime no-access coverage test. |

### Issues Found

**CRITICAL**:

1. The source-retention scenario has no passing runtime test comparing source bytes before and after a sync.
2. The local OAuth boundary has no passing runtime test that detects credential-path access.
3. The invalid-config scenario has no passing runtime test proving backup retention and suppression of every exclusion.

**WARNING**: None.

**SUGGESTION**: Replace the stale prior verify report only after adding the three missing runtime tests and re-running independent verification.

### Verdict

FAIL

The requested live smoke test and every requested non-secret remote diagnostic passed, but the change does not meet the SDD requirement that every spec scenario have a passing covering runtime test.
