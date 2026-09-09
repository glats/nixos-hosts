# AI Backup Runbook (`ai-backup`)

One-shot compressed backup/restore of AI-assistant state (Claude Code,
OpenCode, Engram) as a single `.tar.zst` archive, with consistent SQLite
snapshots taken on the source host.

Binary: `pkgs/nixos-scripts/cmd/ai-backup` (Go; the backup logics are
POSIX-sh payloads embedded in that source, executed via `/bin/sh -s` on
the source host — including macOS).

> ## ⚠️ Security warning — read before sharing
>
> The archive contains **`~/.local/share/opencode/auth.json`** (OpenCode
> API credentials) and **`~/.claude.json`**, which **may contain OAuth
> tokens** for Claude. Anyone who can read the archive can use your AI
> subscriptions. The default destination is a private Samba share that
> is LAN-reachable with guest-ok semantics; treat the destination host
> and LAN as part of the threat model. Keep share permissions private
> (per-user share, no world access) and do not copy archives out of it.
> To rotate after a suspected leak: log out/in and re-auth OpenCode
> (`opencode auth login`).

## Commands

```
ai-backup backup [TARGET]     # default target mact2
ai-backup list
ai-backup restore ARCHIVE [--to TARGET] [--dry-run] [--force]
```

Examples:

```bash
# Backup the default source (mact2) to the default destination.
ai-backup backup

# Local snapshot of this host, dry-run inspection only.
ai-backup restore /run/media/stuff/samba/backup/ai/mact2/ai-backup-mact2-YYYYMMDD-HHMMSS.tar.zst --dry-run

# Inspect an archive without decompressing to disk:
zstd -dc ARCHIVE | tar -tf - | less

# Verify a published checksum sidecar:
cd /run/media/stuff/samba/backup/ai/mact2 && sha256sum -c ai-backup-mact2-*.sha256

# Restore locally, keeping pre-restore copies of everything replaced:
ai-backup restore ARCHIVE --to local

# Restore onto another host over ssh.
ai-backup restore ARCHIVE --to t14
```

A backup publishes `<dest>/<label>/ai-backup-<label>-<ts>.tar.zst`
atomically (`.part` removed on failure, renamed only when complete) plus
a `.sha256` sidecar. Dry-run and `list` never modify data.

## What is included / skipped

| Family | Archived | Skipped (regenerable or live) | Why |
|---|---|---|---|
| Claude state | `~/.claude/{projects/,history.jsonl,plans/,todos/,keybindings.json}` and the nested `~/.claude/.claude/` tree, sibling `~/.claude.json`[^claude] | settings, `CLAUDE.md`, skills, commands, agents, caches, shell-snapshots, telemetry, plugin caches, Keychain/`.credentials.json` | Sessions and history are irreplaceable state; settings, caches and credentials are regenerable (config ownership belongs to the dotfile system) |
| OpenCode state | `~/.local/share/opencode/{storage/,auth.json,opencode-multimodal.json}` + snapshot of every channel-dependent `opencode-<channel>.db`[^opencode] | `bin/`, `log/`, `snapshot/`, `tool-output/`, `node_modules`, live `*.db`, `-wal`/`-shm` sidecars, `.config/opencode/` | live DBs snapshot via `sqlite3 .backup` (safe under WAL); the rest is runtime/provisioned state[^opencode2] |
| Engram | global `~/.engram/engram.db` as `…/engram.db.snapshot` only; project dirs opt-in via `AI_BACKUP_EXTRA`[^engram] | live `~/.engram/` tree, `engram.db.before-*`/`pre-cleanup.*` backups, `-wal`/`-shm` | snapshot copy is the consistent moment-in-time copy recommended by SQLite's own backup guide[^sqlite] |
| Extra project dirs | `AI_BACKUP_EXTRA`, verbatim (see env reference) | — | opt-in only |

[^claude]: `~/.claude.json` may contain OAuth credentials — plain file,
    sibling member, copied to `.claude.json.pre-restore-<ts>` before a
    restore overwrites it. Source: <https://code.claude.com/docs/en/claude-directory>.
[^opencode]: DB names are channel-dependent (`opencode-main.db` etc.);
    symlinks are resolved before snapshotting and the staged name is
    `<real-basename>.db.snapshot`. Source:
    <https://github.com/sst/opencode/issues/13654>.
[^opencode2]: Verified against OpenCode's data-layout troubleshooting
    guide: <https://opencode.ai/docs/troubleshooting>.
[^engram]: Snapshot semantics follow the store's own backup path in
    <https://github.com/Gentleman-Programming/engram> (`store.go`).
[^sqlite]: <https://www.sqlite.org/backup.html>.

## Restore ordering and collision policy

Run restore **with opencode and claude closed** — before their first
launch on a fresh target, or after quitting them on a machine that
already has state. A restore replaces state; it never silently merges.

The restore runs a smart pre-flight BEFORE anything is touched:

- if `opencode` or `claude` is running on the target → **refused**
  (exit 4): replacing a WAL database under a live handle loses every
  write the process makes after the swap;
- if the target already has irreplaceable state (`.claude.json`,
  `.claude/projects`, `.claude/history.jsonl`, nested `.claude/.claude`,
  `auth.json`, legacy `storage/`, any live opencode DB, engram DB) →
  **refused** with the full list of colliding paths;
- `--force` overrides both refusals and is the only way to restore over
  existing state — and even then every replaced item is kept first:
  DBs get `.pre-restore-<ts>` copies at relocation, plain-file trees
  (`projects/`, `storage/`, …) are moved aside whole as
  `<path>.pre-restore-<ts>` and the archive's copy lands fresh, so
  repeat restores never merge two machines' state.

Ordering rule of thumb: restore happens **before** launching
opencode/claude. On a fresh host that means: restore → first launch
(opencode picks up the restored DB and any pending `storage/` → DB
migration sees the legacy sessions) → `claude` re-login. On a machine
with newer local state, decide deliberately: either restore the older
backup over it with `--force` (older conversations win, newer ones live
in the `.pre-restore-<ts>` dirs), or do not restore.

## After restore

1. **Claude re-login** — Keychain and `.credentials.json` are excluded,
   so Claude Code asks you to authenticate again on the target host; the
   `.claude.json` from the archive is preserved as
   `.claude.json.pre-restore-<ts>` first (`keep old .claude.json` in
   the output). Same for OpenCode if `auth.json` was absent from the
   archive (`opencode auth login`).
2. **Snapshot integrity** — the restore payload runs `PRAGMA
   integrity_check` on every restored DB and the command exits nonzero
   if any output is not exactly `ok`. Verify manually:
   ```bash
   sqlite3 ~/.local/share/opencode/opencode-main-stable.db 'PRAGMA integrity_check;'
   ```
3. **Legacy session count** — OpenCode migrated its store out of the
   legacy `storage/` directory; the count from the archived machine
   must match the count after restore:
   ```bash
   find ~/.local/share/opencode/storage -type f | wc -l
   ```
   Zero or a lower count than expected means the storage member did not
   survive the round-trip — re-inspect the archive before deleting
   anything.

## Restoring snapshots (payload behaviour)

Snapshot members live under `home-snap/…` in the archive. The restore
payload, per db:

- strips the `.db.snapshot` suffix and moves the staged snapshot back to
  its live path (realpath basename),
- **resolves an existing destination symlink first** — it never moves
  onto a symlink (Home-Manager re-created ones, like rog's
  `opencode.db → opencode-stable.db`) and moves onto the resolved file,
- keeps a timestamped `*.pre-restore-<ts>` copy of every file it
  replaces,
- integrity-checks every restoration target (including pre-existing
  DBs).

## Environment reference

| Env | Default | Meaning |
|---|---|---|
| `AI_BACKUP_DEST` | `/run/media/stuff/samba/backup/ai` | destination root for backup/list |
| `AI_BACKUP_ZSTD_LEVEL` | `6` | `zstd -T0 -<level>` compression level (1–19) |
| `AI_BACKUP_SSH_OPTS` | `-o BatchMode=yes -o ConnectTimeout=8` | extra ssh options for the source host |
| `AI_BACKUP_EXTRA` | *(unset)* | Space-separated list of absolute paths on the source host; only paths that exist are archived, skipped silently when absent. Typically project `.engram/` dirs: their `chunks/`, `manifest.json` and `config.json` members are archived verbatim as `extras/<project>/.engram/...`, and after restore they land in `~/extras/<project>/.engram/` (never over the global `~/.engram`). The live project `engram.db` never enters. Usage example: `AI_BACKUP_EXTRA="/home/glats/dev/gentle-ai/.engram /home/glats/work/notesta/.engram" ai-backup backup mact2` |

## Limitations

- **No transcript path remapping**: Claude stores project transcripts in
  cwd-encoded directory names (`projects/-home-glats-nixos/…`). A
  restore onto a different host/username means those paths refer to a
  machine-local layout and sessions are not re-encoded into the new
  host's session list automatically.
- **`.claude/.claude` is included whole** (triage-later): its final
  content split is intentionally deferred — it exists in every archive
  for the cost of its bytes.
- **Multimodal provenance is not interpreted**: `opencode-multimodal.json`
  is archived raw; attachments referenced by storage paths may decay if
  a project's unstaged files changed between backup and restore.
- **The live Engram tree never rides**: if project `.engram` state must
  ride, name it in `AI_BACKUP_EXTRA` — it is never implicit.
- sqlite3 must exist on the source host; the payload falls back to
  `/usr/bin/sqlite3` after a PATH probe.
