# Tasks: AI Backup Manifest Scope

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 280-400 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | `remoteBackupScript` + `snap()` rewrite, usage text | PR 1 | `go -C pkgs/nixos-scripts test ./...` | `ai-backup backup --dry-run`-equivalent payload extract to a fake `$HOME` | `pkgs/nixos-scripts/cmd/ai-backup/main.go` |
| 2 | `remoteRestoreScript` rewrite | PR 1 | `go -C pkgs/nixos-scripts test ./...` | restore one archive over a fake `$HOME` with a live symlink | `pkgs/nixos-scripts/cmd/ai-backup/main.go` |
| 3 | `main_test.go` payload/member/exit tests | PR 1 | `go -C pkgs/nixos-scripts test ./...` | N/A — fake `$HOME` tree + tar argv assertion | `pkgs/nixos-scripts/cmd/ai-backup/main_test.go` |
| 4 | `docs/ai-backup.md` runbook | PR 1 | `nix fmt --check` on touched file | manual doc read-through | `docs/ai-backup.md` (new file) |

Note: proposal.md's stale `bin/ai-backup` references were corrected by the orchestrator to `pkgs/nixos-scripts/cmd/ai-backup/`; tasks need not fix the proposal again. There is no `pkgs/nixos-scripts/default.nix` registration work — the Go module is co-located with its derivation (commit 240771c). `docs/ai-backup.md` does not exist yet.

## Phase 1: backup payload rewrite (`pkgs/nixos-scripts/cmd/ai-backup/main.go`)

- [x] 1.1 Rewrite `remoteBackupScript` to enumerate an explicit tar member list with **no `--exclude` flags**: `.claude/{projects,history.jsonl,plans,todos,keybindings.json,.claude}` (whole `.claude/.claude` tree for triage-later), `$HOME/.claude.json` as a sibling member via `-C "$HOME_DIR"`, `.local/share/opencode/{storage,auth.json,opencode-multimodal.json}`, and staged `home-snap`; drop `.config/opencode` and the live `.engram` tree entirely (engram rides only as its snapshot).
- [x] 1.2 Add `AI_BACKUP_EXTRA` handling in `remoteBackupScript`: space-separated project `.engram/` paths tar'd verbatim `-C "$STAGING"`/from their own parent when they exist, skipped silently when absent.
- [x] 1.3 Run the tar under `COPYFILE_DISABLE=1` env, keep `/bin/sh` compatibility, and retain the `trap 'rm -rf "$STAGING"' EXIT INT TERM` staging cleanup.
- [x] 1.4 Rewrite `snap()` + the validation loop in `remoteBackupScript`: resolve with `readlink -f`, emit `<real-basename>.db.snapshot` under `home-snap`, count OpenCode snapshots (`snapcount`), exit 3 unless ≥1 non-empty OpenCode snapshot exists and every staged snapshot is non-empty; document channel-dependent DB names (`opencode-<channel>.db`) and why `.snapshot` naming exists (distinct from live `*.db` so tar member list never picks up live DBs).

## Phase 2: restore payload rewrite (`pkgs/nixos-scripts/cmd/ai-backup/main.go`)

- [x] 2.1 Rewrite `remoteRestoreScript` to strip the `.snapshot` suffix on relocation and target the realpath-named file; resolve an existing destination symlink before the rollback-copy/move (never `mv` onto a live symlink that Home Manager re-creates).
- [x] 2.2 Add a pre-extract POSIX step that copies existing `$HOME/.claude.json` to `.pre-restore-<ts>` before the plain-file overwrite, and restore the `.claude.json` member.
- [x] 2.3 Add per-restored-DB `PRAGMA integrity_check` requiring `ok` output, exiting nonzero on any failure.

## Phase 3: Go-side wiring + usage text (`pkgs/nixos-scripts/cmd/ai-backup/main.go`)

- [x] 3.1 Confirm `doBackup`/`doRestore` shapes are unchanged by the payload rewrites (stream shape identical; `doRestore` still maps extraction/relocation/integrity failure to exit 4).
- [x] 3.2 Update `usageText` member-list summary in the header: replace the now-wrong `~/.config/opencode (config, skills, plugins...)` line and the live-`.engram` line with the new manifest (`.claude`, `$HOME/.claude.json`, `.local/share/opencode`, Engram snapshot, staged `home-snap`), keeping exit-code/env blocks intact.
- [x] 3.3 Apply GNU extract `--warning=no-unknown-keyword` consideration in `doRestore` extraction per design (source-side suppression is authoritative; only if it does not disturb portability).

## Phase 4: tests (`pkgs/nixos-scripts/cmd/ai-backup/main_test.go`)

- [x] 4.1 Add `/bin/sh -n` syntax tests over both embedded payloads (`remoteBackupScript`, `remoteRestoreScript`).
- [x] 4.2 Add member-list construction tests: build a fake `$HOME` tree and assert required members present (`.claude/projects`, `.claude.json`, `.local/share/opencode/auth.json`, `storage/`, `opencode-multimodal.json`, staged `home-snap` snapshots) and forbidden members absent (`.config/opencode`, live `*.db`, `node_modules`, `bin/`, `log/`, `snapshot/`) — either run the tar argv logic dry or assert on the constructed tar argv.
- [x] 4.3 Add a snapcount=0 → exit 3 contract test (zero or empty OpenCode snapshot before publication).
- [x] 4.4 Add `.snapshot` strip + symlink-resolution restore logic tests against the Go-side helpers; document in comments which restore behaviors are covered only by real-run verification (POSIX payload assertions are limited) rather than over-mocking.

## Phase 5: documentation (`docs/ai-backup.md`, new)

- [x] 5.1 Create `docs/ai-backup.md` with a security warning (archive contains `auth.json` and possible OAuth in `.claude.json`; samba share is LAN/guest-ok — note) and backup/list/inspect/`sha256sum -c`/dry-run/`restore --to`/`--dry-run` commands.
- [x] 5.2 Add an included/skipped table with one citation per family, plus Claude re-login (Keychain) and `.credentials.json` regeneration notes.
- [x] 5.3 Add post-restore legacy-session count check, `AI_BACKUP_DEST`/`AI_BACKUP_ZSTD_LEVEL`/`AI_BACKUP_SSH_OPTS`/`AI_BACKUP_EXTRA` env reference, and limitations (cwd-encoded transcript names, `.claude/.claude` triage, multimodal provenance, `AI_BACKUP_EXTRA` usage).

## Phase 6: verification

- [x] 6.1 Run `go -C pkgs/nixos-scripts test ./...`, `go vet`, and `/bin/sh -n` over both payloads.
- [x] 6.2 Run `format-nix && nix flake check --no-build`.
- [x] 6.3 REAL mact2 run: archive contains `.db.snapshot` and `.claude.json`, absent `.config/opencode`, `bin/`, `log/`, `snapshot/`, `node_modules`, live `*.db`; extract one snapshot → `PRAGMA integrity_check` = `ok`; `sha256sum -c` passes. Real run is the final gate (network to `mact2.local` required).
      DONE 2026-09-08 by orchestrator: archive `ai-backup-mact2-20260908-221928.tar.zst` (237M, 433s) built from fresh `nix build .#packages.x86_64-linux.nixos-scripts`; sha256 OK; 14037 members — exactly 1 opencode + 1 engram `.db.snapshot`, `.claude.json`, 169 transcripts, nested tree, storage/, auth.json; zero tar stderr; extracted snapshot `integrity_check` = `ok`; opencode-multimodal.json/keybindings.json skipped because absent on mact2 (guarded). See verify-report.md.