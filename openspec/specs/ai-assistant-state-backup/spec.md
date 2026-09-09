# ai-assistant-state-backup Specification

## Purpose

Define auditable backup, inspection, and restore of AI-assistant state.

## Requirements

### Requirement: Backup Command and Destination

`ai-backup` MUST support `backup [TARGET]`, `list`, and `restore [--to TARGET] [--dry-run]`. Backup MUST default to `jcuzmar@mact2.local`, accept local, `t14`, `thinkcentre`, or `user@host`, use `${AI_BACKUP_DEST:-/run/media/stuff/samba/backup/ai/<label>/}`, and compress with zstd `-T0 ${AI_BACKUP_ZSTD_LEVEL:--6}`.

#### Scenario: Default backup [hosts: mact2, rog]

- GIVEN no target or environment overrides
- WHEN `ai-backup backup` runs
- THEN it MUST back up `jcuzmar@mact2.local` to the default labeled destination

#### Scenario: Supported target and inspection [hosts: rog, thinkcentre, t14, mact2]

- GIVEN a supported target or archive
- WHEN backup, list, or restore dry-run runs
- THEN the operation MUST run and inspection MUST NOT modify data

### Requirement: Manifest Inclusion and Exclusion

Backup MUST include Claude `projects/**`, `history.jsonl`, `plans/`, `todos/`, `keybindings.json`, `$HOME/.claude.json`, and `.claude/.claude/**`; OpenCode realpath snapshots for all channel-dependent `opencode*.db`, `auth.json`, `storage/`, and `opencode-multimodal.json`; Engram's snapshot and project `.engram/{chunks/,manifest.json,config.json}`. It MUST exclude `.config/opencode/**`, `node_modules`, Claude `{settings*.json,CLAUDE.md,agents/,commands/,skills/,output-styles/,cache/,shell-snapshots/,session-env/,file-history/,paste-cache/,debug/,statsig/,telemetry/,backups/,tasks/,ide/,stats-cache.json,plugins/cache,plugins/marketplaces,.credentials.json}`, OpenCode `{bin/,log/,logs/,snapshot/,tool-output/,delegations/,*.db,*.db-wal,*.db-shm,*.backup,*.backup-*}`, and Engram `{engram.db.before-*,engram.db.pre-cleanup.*,engram.db-wal,engram.db-shm}`.

#### Scenario: Required state is archived [hosts: mact2, rog]

- GIVEN required source members exist
- WHEN backup completes
- THEN `.claude.json`, legacy `storage/`, nested Claude state, and every required family MUST appear

#### Scenario: Regenerable or live state is absent [hosts: mact2, rog]

- GIVEN excluded paths exist
- WHEN archive members are listed
- THEN no excluded member or live database artifact MUST appear

### Requirement: Portable Atomic Archive

SQLite databases MUST use `.backup` into non-empty `*.db.snapshot` files after resolving OpenCode symlinks and channel-dependent names. Backup MUST exit 3 unless ≥1 OpenCode snapshot exists and each is non-empty. The tar MUST be built from an explicit member list with no `--exclude` patterns, so no skipped path can re-enter through tar-flavor pattern semantics (bsdtar suffix-matches unanchored patterns; GNU tar reads `^` as a literal); macOS xattrs MUST be suppressed (`COPYFILE_DISABLE=1`). Publication MUST stream to `<archive>.part`, remove failures, rename atomically, then write its SHA-256 sidecar.

#### Scenario: Snapshot validation fails closed [hosts: mact2, rog]

- GIVEN no OpenCode snapshot or an empty snapshot
- WHEN count validation runs
- THEN backup MUST exit 3 before publication without leaving `.part`

#### Scenario: Portable publication succeeds [hosts: mact2, rog]

- GIVEN all snapshots are valid
- WHEN archive creation succeeds
- THEN the archive and subsequent checksum MUST publish without xattr-header noise

### Requirement: Safe Restore

Restore MUST verify an available checksum; dry-run MUST only list members. It MUST extract to `$HOME` locally or over SSH, restore `.claude.json` and legacy storage, relocate snapshots with timestamped pre-restore copies, preserve live symlinks, and run `PRAGMA integrity_check` on every restored database, returning nonzero on failure.

#### Scenario: Restore preserves database indirection [hosts: rog, thinkcentre, t14, mact2]

- GIVEN a live database path is a symlink
- WHEN restore relocates its snapshot
- THEN the symlink MUST remain and the resolved database MUST have a rollback copy

#### Scenario: Corrupt archive or database fails [hosts: rog, thinkcentre, t14, mact2]

- GIVEN checksum or integrity verification fails
- WHEN restore runs
- THEN restore MUST return nonzero and report the failed check

### Requirement: Operator Runbook

`docs/ai-backup.md` MUST give one citation per backed-up/skipped family; warn that Samba archives contain `auth.json` and possible `.claude.json` OAuth; document commands, Claude re-login because Keychain and `.credentials.json` are excluded, post-restore legacy-session counts, and limitations for cwd-encoded transcript paths/remapping, nested Claude triage, and multimodal provenance.

#### Scenario: Operator follows recovery guidance [hosts: rog, thinkcentre, t14, mact2]

- GIVEN an operator opens the runbook
- WHEN preparing backup or restore
- THEN security, re-login, verification, usage, and limitations MUST be discoverable

### Requirement: Verification Gates

Acceptance MUST require clean `/bin/sh -n` over both embedded payloads plus `go test ./...`, `format-nix`, and `nix flake check --no-build`; a real mact2 archive containing `.db.snapshot` and `.claude.json` but no OpenCode `bin/`, `log/`, `snapshot/`, `node_modules`, `.config/opencode`, or live `*.db`; and passing snapshot integrity and `sha256 -c` checks.

#### Scenario: Release evidence passes [hosts: mact2, rog]

- GIVEN the change is ready for acceptance
- WHEN all prescribed gates and archive inspections run
- THEN every command MUST pass and every required presence/absence assertion MUST hold
