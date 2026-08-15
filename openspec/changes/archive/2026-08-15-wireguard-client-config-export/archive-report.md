# Archive Report: wireguard-client-config-export

## Change Summary
New capability `wireguard-config-export`: on-demand export of root-only `/etc/wireguard/clients/*.conf` into `/home/glats/Documents/wireguard/` via new `bin/export-wireguard-configs` script, registered in `pkgs/nixos-scripts/default.nix`. Idempotent overwrite, stale-file pruning, missing/empty source safety, sudo failure handling. Pure addition — zero destructive deltas. Host scope: rog only.

## Archive Mode
Hybrid (filesystem + Engram)

## Artifact Observation IDs

| Artifact | Engram ID | Type |
|----------|-----------|------|
| explore | #1959 | architecture |
| proposal | #1960 | architecture |
| spec | #1961 | architecture |
| design | #1962 | architecture |
| tasks | #1963 (updated) | architecture |
| apply | #1964 | architecture |
| verify | #1965 | architecture |

## Specs Synced

| Domain | Action | Details |
|--------|--------|---------|
| wireguard-config-export | Created (full spec promotion) | 6 added requirements, 8 scenarios, 0 modified, 0 removed |

Main spec `openspec/specs/wireguard-config-export/spec.md` did not exist — the delta spec WAS the full spec. Promoted to main spec format matching repo convention (`# wireguard-config-export Specification`, Purpose, Requirements). All 6 requirement bodies and all 8 scenarios verified byte-identical to the delta (diff-checked).

## Archive Contents

| File | Status |
|------|--------|
| proposal.md | ✅ |
| exploration.md | ✅ |
| specs/wireguard-config-export/spec.md | ✅ (delta spec preserved verbatim) |
| design.md | ✅ |
| tasks.md | ✅ (11/11 tasks complete) |
| verify.md | ✅ |
| archive-report.md | ✅ (this file) |

## Archive Path
`openspec/changes/archive/2026-08-15-wireguard-client-config-export/`

## Task Completion Verification
All 11 tasks complete (8 code/registration tasks marked by apply, 3 manual runtime tasks reconciled here). Verify-report: **PASS WITH WARNINGS** — all 6 requirements / 8 scenarios verified, runtime checks executed on `rog` (5 real peers; failure-safety via faithful sudo stubs; destination sha256 unchanged). No CRITICAL issues.

## Stale Checkbox Reconciliation
Tasks 3.3–3.5 (`- [ ]` manual runtime checks) were reconciled to `[x]` at archive time. Proof: verify-report compliance matrix documents scenarios 1–7 executed for real on rog (happy path, auto-create, idempotent re-run, prune, missing/empty source, sudo failure) plus orchestrator-confirmed PASSED verification with runtime checks on rog. This is the exceptional mechanical reconciliation path per sdd-archive skill (stale checkboxes + verify-report proof), not a substitute for apply marking.

## Review Gate
No structured review receipt exists — no review phase ran for this change (verify report is the terminal gate). No `sdd/{change-name}/review/*` observations present in Engram. Verify verdict PASS WITH WARNINGS, no CRITICAL issues, so no archive block applies.

## Destructive Delta Check
No destructive deltas: the delta contains only ADDED requirements (6) for a new capability domain. No MODIFIED/REMOVED/RENAMED requirements, no existing main spec was overwritten or trimmed. Per `rules.archive`, warn-before-destructive-merge is not triggered.

## Source of Truth Updated
- `openspec/specs/wireguard-config-export/spec.md` — created (6 requirements / 8 scenarios, all `[rog]` tagged)

## Registry / Index
No registry or index of changes exists under `openspec/` (only `config.yaml`, `changes/`, `specs/`) — no index update required.

## Notes
- Git state: archive move + main spec staged via `git add`/`git mv` but NOT committed (orchestrator decides). Unrelated working-tree modification `linux/system/base/profiles/core.nix` (ocrmypdf/okular) left untouched and unstaged — out of scope (verify W-2).
- `verify.md` filename retained (repo's prior archives use `verify-report.md`; this change's verify phase produced `verify.md` — kept as-is, archive is an audit trail).

## SDD Cycle Complete
The change has been fully explored, proposed, specced, designed, implemented, verified, and archived. Ready for the next change.
