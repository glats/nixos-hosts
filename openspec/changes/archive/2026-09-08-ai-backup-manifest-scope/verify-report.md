```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:e1474b00ca9fe26a236177db0339b1b4437c3845a817e452c9641a94b927d9b1
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 6/6
scenarios: 10/10
test_command: "go -C pkgs/nixos-scripts test -count=1 ./... && go -C pkgs/nixos-scripts vet ./... && go -C pkgs/nixos-scripts test -count=1 -run TestPayloadSyntaxShN ./cmd/ai-backup"
test_exit_code: 0
test_output_hash: sha256:9b561684977d122ab13fc0372feff5a53b5d68d05c84254a8eb80e140144377b
build_command: "format-nix --check && nix flake check --no-build"
build_exit_code: 0
build_output_hash: sha256:0b71ac4e7261731fa4e84824a379367adbe719521c1c8cec176a873c7cfe9e97
```

## Verification Report

**Change**: ai-backup-manifest-scope

**Mode**: Standard

### Completeness

| Metric | Value |
|---|---:|
| Tasks total | 18 |
| Tasks checked in `tasks.md` | 17 |
| Tasks complete with supplied real-run evidence | 18 |
| Tasks incomplete | 0 |

`tasks.md:66` remains literally unchecked from the apply handoff. The supplied real-run evidence satisfies task 6.3, so it is complete for this verification; its checkbox is an administrative stale state, not an implementation gap.

### Build and Test Execution

**Tests**: PASS. The command in the envelope exited 0. The focused `ai-backup` package ran 13 top-level tests, including the three `/bin/sh -n` payload subtests; all passed. `go vet` was clean.

**Build/evaluation**: PASS. `format-nix --check` and `nix flake check --no-build` exited 0. The flake reports its expected x86_64-darwin omission on this Linux evaluator.

**Real-run evidence supplied by the orchestrator (not re-run)**: `ai-backup-mact2-20260908-221928.tar.zst` was 237M and completed in 433s using the freshly built binary. `sha256sum -c` passed; tar emitted zero stderr lines; the 14,037-member archive contained `.claude.json`, 169 Claude transcript JSONL files, 997 nested `.claude/.claude` members, 12,856 `storage/` members, `auth.json`, and exactly one snapshot each for OpenCode and Engram. Extracted OpenCode snapshot integrity was `ok`.

### Spec Compliance Matrix

| Requirement | Scenario | Evidence | Result |
|---|---|---|---|
| R1 Backup Command and Destination | Default backup | `main.go:750-769` defaults to `mact2`; `TestResolveTarget` passed; supplied mact2 archive run completed. | PASS |
| R1 Backup Command and Destination | Supported target and inspection | `main.go:132-145,600-682`; `TestResolveTarget` passed for local/mact2/t14/thinkcentre/passthrough; dry-run lists only. | PASS |
| R2 Manifest Inclusion and Exclusion | Required state is archived | `main.go:310-365`; `TestBackupPayloadMemberList` and supplied member list passed. | PASS |
| R2 Manifest Inclusion and Exclusion | Regenerable or live state is absent | Explicit list has no excludes (`main.go:301-365`); fixture and supplied archive absence assertions passed. | PASS |
| R3 Portable Atomic Archive | Snapshot validation fails closed | `main.go:282-299,521-525`; zero and empty snapshot exit-3 tests passed. | PASS |
| R3 Portable Atomic Archive | Portable publication succeeds | `main.go:352-365,505-548`; supplied archive, zero tar stderr, and SHA-256 sidecar passed. | PASS |
| R4 Safe Restore | Restore preserves database indirection | `main.go:394-416,699-729`; symlink/realpath/rollback test and `.snapshot` stripping test passed. | PASS |
| R4 Safe Restore | Corrupt archive or database fails | `main.go:638-647,686-729,426-436`; integrity-failure test passed and the Go wrapper maps restore errors to 4. | PASS |
| R5 Operator Runbook | Operator follows recovery guidance | `docs/ai-backup.md:11-21,23-55,79-143` was inspected: security, commands, checksum, re-login, integrity, session check, env, and limits are present. | PASS |
| R6 Verification Gates | Release evidence passes | Current local gates passed; supplied real mact2 archive evidence satisfies all required presence/absence, integrity, checksum, and xattr-noise checks. | PASS |

**Compliance summary**: 6/6 requirements and 10/10 scenarios compliant. The change has six requirements (the request referred to R1-R5, but the retrieved spec also has R6, Verification Gates).

### Correctness and Design Coherence

| Check | Status | Evidence |
|---|---|---|
| Exact manifest scope | PASS | `main.go:310-365` names only the required Claude/OpenCode files plus `home-snap`; real member listing confirms required inclusions and required absences. Guarded absent `opencode-multimodal.json` and Claude keybindings match cheap-include semantics. |
| Snapshot names and exit contract | PASS | `main.go:260-299` resolves realpaths and emits `<real-basename>.db.snapshot`; `main.go:521-525` removes `.part` and returns backup failure. |
| Restore safety | PASS | `main.go:371-377` protects `.claude.json`; `main.go:394-436` preserves a destination symlink, makes rollback copies, strips `.snapshot`, and requires `ok`; `main.go:686-729` maps failure to exit 4. |
| Usage accuracy | PASS | `main.go:72-121`, protected by `TestUsageTextDescribesManifest`, documents the explicit scope, env knobs, and 0/1/2/3/4 categories. |
| Runbook | PASS | `docs/ai-backup.md:11-143` supplies security, operations, family citations, recovery, and documented `AI_BACKUP_EXTRA` layout. |

### Justified Deviations

| Deviation | Judgment | Rationale |
|---|---|---|
| No `--warning=no-unknown-keyword` during extract | ACCEPT | `main.go:703-709` correctly retains macOS bsdtar portability; source-side `COPYFILE_DISABLE=1` at `main.go:352-365` is authoritative, and the real run had zero tar stderr. This follows design.md:37's portability condition. |
| `AI_BACKUP_EXTRA` restores under `~/extras/<project>/.engram/` | ACCEPT | `main.go:327-365` stages a safe prefix and `docs/ai-backup.md:125` documents it. A direct `<project>/.engram` archive path would need path-prefix rewriting; the chosen layout preserves the project name and prevents global `~/.engram` clobbering, satisfying the spec's state-preservation intent. |

### Issues Found

**CRITICAL**: None.

**WARNING**: `openspec/changes/ai-backup-manifest-scope/tasks.md:66` still displays task 6.3 unchecked although the supplied evidence completes it. This is documentation state only.

**SUGGESTION**: Archive using the repository convention, `verify-report.md` (not `verification.md`); archived changes demonstrate that canonical name.

### Verdict

PASS WITH WARNINGS — READY-TO-ARCHIVE. All six requirements and ten scenarios have current local runtime checks, implementation evidence, and the supplied non-network real-run evidence. The sole warning is the stale task checkbox.
