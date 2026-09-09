# Design: AI Backup Manifest Scope

## Overview

Evolve `pkgs/nixos-scripts/cmd/ai-backup/main.go` and its embedded POSIX-sh payloads. `remoteBackupScript` becomes the executable manifest: snapshot real databases, archive approved state from an explicit member list with no exclude patterns and no macOS xattrs, then use the existing Go compression/publication pipeline. Restore protects `.claude.json`, relocates realpath-named snapshots, and preserves symlinks. The proposal's `bin/ai-backup` path predates the Go migration and must not be recreated.

## Decisions

| Decision | Choice | Rationale | Alternatives rejected |
|---|---|---|---|
| Manifest ownership | Embedded payload plus compact include/skip comment table | Keeps one owner and unchanged packaging | Recreate bash; add an unshared `bin/lib` file |
| Member selection | Explicit include list, zero `--exclude` flags | No portable pattern syntax exists: bsdtar suffix-matches unanchored patterns (the confirmed data-loss bug) while GNU tar reads `^` as a literal and would never match — enumerated members are auditable on both | `^`-anchored excludes (bsdtar-only semantics), per-tree invocations |
| Root Claude state | Sibling member via `-C "$HOME_DIR" .claude.json`; pre-restore copy | It is outside `.claude/` and may hold OAuth | Implicit capture; unsafe overwrite |
| Verification artifact | Runbook inspection; no `--manifest` or second decompression | Acceptance already lists the archive | Routine generated file lists |
| Legacy `storage/` check | Runbook session-count spot check | OpenCode owns migration semantics | Reimplement storage parsing |
| Errors | Preserve CLI and `0/1/2/3/4` categories | Avoid caller breakage | New manifest codes |

No Nix option is added or changed. `pkgs/nixos-scripts/default.nix` retains the existing `cmd/ai-backup` registration.

## Component Changes

### `remoteBackupScript`

- Enumerate members explicitly: `.claude/{projects,history.jsonl,plans,todos,keybindings.json,.claude}`, `$HOME/.claude.json`, `.local/share/opencode/{storage,auth.json,opencode-multimodal.json}`, and staged `home-snap`. `.config/opencode` and the live `.engram` tree never enter (engram rides only as its snapshot; project `.engram/` dirs ride via `AI_BACKUP_EXTRA` paths when present).
- No `--exclude` flags remain; the include list mirrors the spec manifest and is the single auditable artifact.
- Run tar under `COPYFILE_DISABLE=1` (suppresses macOS copyfile xattrs; no-op on GNU); keep `/bin/sh` compatibility. Source hosts need no `zstd`.
- `snap()` resolves and opens the `readlink -f` path, emitting `<real-basename>.db.snapshot`. A `snapcount` fails with 3 unless at least one non-empty OpenCode snapshot exists; all staged snapshots are then non-vacuously checked.

### `remoteRestoreScript`

- Strip `.snapshot`, target the realpath-named file, and resolve an existing destination symlink before rollback-copy and move.
- Relocate OpenCode and Engram snapshots; require `PRAGMA integrity_check` output `ok` for each.
- Add a pre-extract POSIX step that copies existing `.claude.json` to `.pre-restore-<ts>` before plain-file overwrite.

### `doBackup` / `doRestore`

Keep flags and targets unchanged. `doBackup` retains rog-side `zstd -T0 -<level>`, `.part` cleanup/rename, then checksum. `doRestore` remains checksum-first/read-only on dry-run, pre-copies `.claude.json`, and maps extraction, relocation, or integrity failure to 4. GNU extraction may add `--warning=no-unknown-keyword`; source suppression is authoritative.

## `docs/ai-backup.md` Outline

1. Security warning for `auth.json`/possible OAuth and private Samba permissions.
2. Backup, list, inspect, checksum, dry-run, and restore commands.
3. Included/skipped table with one citation per family.
4. Claude re-login, SQLite integrity, and legacy-session count checks.
5. Limits: no transcript path remap; nested Claude triage; uninterpreted multimodal provenance; excluded Keychain/credentials.

## Risks

| Risk | Mitigation |
|---|---|
| Tar pattern drift | Fixture tests list required/forbidden members |
| Symlink replacement or partial restore | Realpath target, rollback copies, checksum/integrity gates |
| Sensitive archive exposure | Runbook warning and private Samba guidance |
| Stale baseline | Tasks target Go and correct proposal/spec paths and gate wording |

## Verification Plan (Spec R5)

| Gate | Evidence |
|---|---|
| Payload/unit behavior | `go test ./...`; `/bin/sh -n` both payloads; test exit contracts, zero/empty snapcount, realpath names, excludes/xattrs, symlink-safe restore |
| Repository gates | `format-nix && nix flake check --no-build` |
| Real mact2 archive | Require `.claude.json`/`.db.snapshot`; reject `.config/opencode`, live DBs, `bin/`, `log/`, `snapshot/`, `node_modules` |
| Integrity and publication | Extract a snapshot, require `PRAGMA integrity_check` = `ok`, and run `sha256sum -c` |

R5's `bash -n` is stale after the Go migration; correct it to `/bin/sh -n` over embedded payloads plus `go test ./...` before tasks.

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — tar members are data, never executable classification | None | None |
| Git repository selection | N/A — no Git invocation | None | None |
| Commit state | N/A — no commit automation | None | None |
| Push state | N/A — no push automation | None | None |
| PR commands | N/A — no PR automation | None | None |

## Migration / Scope Boundary

No data migration or flag is required. Roll back the Go source and runbook; rollback copies remain. No timer, retention, path remap, Samba provisioning, or encryption layer is added.

## Open Questions

None.
