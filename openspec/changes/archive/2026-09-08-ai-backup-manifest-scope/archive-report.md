# Archive Report: ai-backup-manifest-scope

**Change:** ai-backup-manifest-scope
**Archived:** 2026-09-08
**Archive path:** `openspec/changes/archive/2026-09-08-ai-backup-manifest-scope/`
**Status:** Completed — verification verdict `pass_with_warnings`, READY-TO-ARCHIVE
**Mode:** openspec (filesystem archive; no Engram persistence for this repo)

## Review Verdict

**PASS WITH WARNINGS** — 6/6 requirements, 10/10 scenarios compliant, 0 blockers, 0 CRITICAL findings
(per `verify-report.md`, 2026-09-08):

| Gate | Result |
|------|--------|
| Tests (`go test`, `go vet`, `/bin/sh -n` payloads) | PASS (exit 0; 13 ai-backup tests incl. 3 payload-syntax subtests) |
| Build/eval (`format-nix --check && nix flake check --no-build`) | PASS (exit 0; x86_64-darwin omission expected on Linux evaluator) |
| Real mact2 run (supplied, not re-run at verify time) | PASS — `ai-backup-mact2-20260908-221928.tar.zst`, 237M, 433s, 14,037 members; `sha256sum -c` OK; zero tar stderr; extracted OpenCode snapshot `PRAGMA integrity_check` = `ok` |

The sole verify-time WARNING (stale unchecked task 6.3 at `tasks.md:66`) was reconciled at
archive time: task 6.3 is now checked with the orchestrator's real-run DONE annotation
(2026-09-08). All 20/20 tasks are complete with no unchecked implementation tasks.

## Task Completion

- Phases 1–5 (backup payload rewrite, restore payload rewrite, Go wiring + usage text, tests,
  `docs/ai-backup.md` runbook): complete at apply time.
- Phase 6 (verification): tasks 6.1 (`go test ./...` + `go vet` + `/bin/sh -n`), 6.2
  (`format-nix && nix flake check --no-build`), and 6.3 (REAL mact2 run) all checked. Task 6.3's
  checkbox was stale at verify time and was reconciled with the supplied real-run evidence,
  annotated `DONE 2026-09-08 by orchestrator`.

## Summary

The one-shot `mact2` → `rog` AI-state backup is now complete and auditable:

- `pkgs/nixos-scripts/cmd/ai-backup/main.go`: `remoteBackupScript` enumerates an explicit tar
  member list with zero `--exclude` flags (bsdtar suffix-match data-loss bug avoided), backs up
  `$HOME/.claude.json` and legacy `storage/`, stages SQLite snapshots as
  `<real-basename>.db.snapshot` under `home-snap`, exits 3 unless ≥1 non-empty OpenCode snapshot
  exists, runs under `COPYFILE_DISABLE=1`; `remoteRestoreScript` strips `.snapshot`, resolves
  destination symlinks before rollback-copy/move, pre-copies `.claude.json` to
  `.pre-restore-<ts>`, and requires `PRAGMA integrity_check` = `ok` per restored DB (failure → 4).
- `pkgs/nixos-scripts/cmd/ai-backup/main_test.go`: member-list, exit-3, snapshot-strip,
  symlink-resolution, and payload-syntax tests.
- `docs/ai-backup.md` (new): security warning (Samba archives contain `auth.json` and possible
  `.claude.json` OAuth), commands, included/skipped table with one citation per family, Claude
  re-login notes (Keychain and `.credentials.json` excluded), post-restore legacy-session count,
  env reference (`AI_BACKUP_DEST`, `AI_BACKUP_ZSTD_LEVEL`, `AI_BACKUP_SSH_OPTS`,
  `AI_BACKUP_EXTRA`), and limitations.
- Default source remains `jcuzmar@mact2.local`; local, `t14`, `thinkcentre`, and `user@host`
  targets supported.

Justified deviations (from verify-report): no `--warning=no-unknown-keyword` during extract
(macOS bsdtar portability; source-side `COPYFILE_DISABLE=1` authoritative, real run had zero tar
stderr); `AI_BACKUP_EXTRA` restores under `~/extras/<project>/.engram/` (safe prefix prevents
global `~/.engram` clobbering, documented in the runbook).

## Spec Sync

| Domain | Action | Details |
|--------|--------|---------|
| ai-assistant-state-backup | Created (NEW) | Delta spec copied byte-identically from `specs/ai-assistant-state-backup/spec.md` to `openspec/specs/ai-assistant-state-backup/spec.md`. Framing normalized to registry convention (mirrors bec8ff2): title → `# ai-assistant-state-backup Specification`. Scenario tags were already canonical `[hosts: ...]`; the delta carries no change-specific `## Source Context` section to drop. 6 requirements, 10 scenarios preserved verbatim. |

## Mechanical Copy Verification

- Spec sync: byte-identity `cp` of the delta verified with an **empty `diff -r` (PASS)** before the
  single deliberate framing edit (title normalization); final file diffed against the delta
  re-transformed with the same edit — **empty diff (PASS)**.
- Change folder moved with `git mv` to `openspec/changes/archive/2026-09-08-ai-backup-manifest-scope/`;
  MANDATORY `diff -r` readback of the pre-move recursive snapshot vs. the archived destination
  returned an **empty diff (PASS)** — byte identity preserved. `archive-report.md` is additive-only
  and was not in the source snapshot.

## Validation

- No `openspec` CLI exists in the repo; the openspec archive convention is validated by the
  mechanical `diff -r` readbacks above (both empty) plus the archive structure checks:
  active `openspec/changes/ai-backup-manifest-scope/` is gone; archived folder contains
  `proposal.md`, `specs/ai-assistant-state-backup/spec.md`, `design.md`, `tasks.md` (20/20
  checked), and `verify-report.md`.
- Repository gates for the shipped code passed at verify time (`format-nix --check`,
  `nix flake check --no-build`, `go test ./...`, `go vet`, `/bin/sh -n`).

## Outstanding

- None mandatory. Optional follow-ups documented in the runbook: transcript path
  remapping/cwd-encoded names, nested `.claude/.claude` triage, multimodal provenance —
  all known limitations, not blockers.