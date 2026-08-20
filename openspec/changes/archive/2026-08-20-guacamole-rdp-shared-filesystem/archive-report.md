# Archive Report: guacamole-rdp-shared-filesystem

**Archived**: 2026-08-20
**Mode**: hybrid (Engram + openspec)
**Project**: nixos-hosts
**Archived to**: `openspec/changes/archive/2026-08-20-guacamole-rdp-shared-filesystem/`

## Final State (per Final-State Authority)

- **Verdict**: PASS WITH WARNINGS (verify-report #2008, supersedes the earlier FAIL report)
- **CRITICAL issues**: 0 (zero)
- **Blockers**: 0
- **Tasks**: 11/11 reconciled with evidence (all checkboxes `[x]`, zero unchecked remain)
- **Capabilities**: New None / Modified None (config-only infra change; no `specs/` delta)
- **Implementation commit**: `e3eca14` on master — `feat(guacamole): enable RDP drive redirection via guacd bind mount`

## Final-State Authority ranking applied

Per the hierarchy, the archive report reflects state AT CLOSE, not at intermediate snapshots:

1. **Native review authority** (`reviewGate`): structurally ABSENT — no receipt-driven review was ever started for this candidate (kill switch off, no review discovered). Archive proceeds under ordinary policy. No review artifacts exist to read or block on.
2. **Persisted tasks artifact**: all 11 tasks marked complete (see stale-checkbox reconciliation below).
3. **Explicit final-state facts from orchestrator launch prompt**: authorizes stale-checkbox reconciliation backed by verify-report/apply-progress proof; confirms commit e3eca14 carries the implementation.
4. **`verify-report` / `apply-progress`** (intermediate snapshots): `verify-report` #2008 is the highest verification account and its warnings are carried forward; `apply-progress` #2005 documented 8/11 applied with Phase 4 left for user.

## Observation IDs read (Engram traceability)

| # | Artifact | Notes |
|---|----------|-------|
| 1999 | explore | Exploration: guacd has no volumes; drive redirection needs host-backed bind mount |
| 2000 | proposal | Proposal; Capabilities None/None; question round RESOLVED (shared /drive, dedicated dir, both directions) |
| 2001 | design | Design; single shared /drive, tmpfiles numeric 1000, manual DB contract |
| 2002 | tasks | Tasks artifact (8/11 checked at apply time; 4.1/4.2/4.3 unchecked) |
| 2005 | apply-progress | Phase 1-3 applied & verified; Phase 4 left for user (manual UI steps) |
| 2008 | verify-report | Final PASS WITH WARNINGS (re-run after remediation); drives archive decisions |

## Stale-checkbox reconciliation (orchestrator-authorized)

The archived audit trail must NOT contain stale unchecked tasks for completed work. Tasks 4.1, 4.2, 4.3 were unchecked in `tasks.md` despite being complete. Per explicit orchestrator authorization, these were ticked `[x]` BEFORE the move, backed by the following proof (recorded in `tasks.md` one-line notes):

- **4.1 (per-connection DB params)**: live postgres DB verified — all three connections (id 4 asusrog, 7 oneplus5, 8 thinkcentre) now carry `enable-drive=true`, `drive-path=/drive`, `drive-name=Guacamole Filesystem`; `create-drive-path` correctly absent (shared `/drive` layout). `enable-drive=true`, `drive-path=/drive`.
- **4.3 (E2E)**: proven end-to-end — user uploaded `mac.conf` from their Mac via Guacamole RDP; artifact at `/srv/glats/guacamole/drive/mac.conf` (384 bytes, owner 1000:1000, mtime 2026-08-20 14:47), written by guacd UID 1000 through the `/drive` bind mount.
- **4.2 (documentation)**: documentation substance exists in design.md "Interfaces / Contracts → Manual DB contract (outside Nix)" (all four parameters with the container-vs-host path warning) plus tasks.md Phase 4 and proposal.md In-Scope.

This reconciliation is an exceptional mechanical repair permitted by the Task Completion Gate when apply-progress/verify-report prove completion; it does not constitute normal task completion (owned by sdd-apply).

## Spec sync (Step 2) — SKIPPED

No `specs/` subdirectory exists in the change folder. Capabilities are New: None / Modified: None — a config-only infra change with no spec-level behavior deltas. There are no delta specs to merge into main specs. Recorded as skipped, not inferred.

## Warnings carried (non-blocking)

1. **t14 (id 2) has no drive params** — by user choice, non-blocking. RDP connection `t14` carries no drive parameters; the three connections the user actively uses (4/7/8) are fully remediated. The shared drive will not appear in the t14 session unless the same params are applied there (if wanted at all).
2. Download direction has no direct host-side artifact yet (rides the same RDPDR channel in reverse); upload direction proven via mac.conf.

## Mechanical archive evidence

Mechanical shell move performed (plain `mv`, since the folder mixes tracked files + untracked `verify-report.md`; `git mv` would not move the untracked file). A recursive pre-move snapshot was taken with `cp -R` and compared with `diff -r` against the archived folder.

**Verbatim `diff -r` readback output** (snapshot `$snapshot_root/source` vs `openspec/changes/archive/2026-08-20-guacamole-rdp-shared-filesystem/`):

```
(empty — no differences)
```

Empty diff = PASS. The `archive-report.md` file is additive-only and was excluded from the comparison (it did not exist in the source snapshot).

## Verify checklist (Step 4)

- [x] Main specs updated correctly — N/A (no delta specs; Capabilities None/None; Step 2 skipped)
- [x] Change folder moved to archive
- [x] Archive contains all artifacts (proposal, design, tasks, verify-report, exploration)
- [x] Archived `tasks.md` has no unchecked implementation tasks (11/11; orchestrator-approved reconciliation with proof)
- [x] Active changes directory no longer has this change
- [x] Verbatim `diff -r` readback output included in result and is empty (no differences)

## Related/untouched changes

- `openspec/changes/wireguard-web-manager/` — NOT touched (unrelated untracked leftover).
- `openspec/changes/remove-romarr-grabarr/` — NOT touched (active change).

## SDD Cycle Complete

The change has been fully planned, implemented, verified, and archived.
