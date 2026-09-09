# Proposal: AI Backup Manifest Scope

## Intent

Make the one-shot `mact2` → `rog` AI-state backup complete and auditable. The draft omits `~/.claude.json`, risks silent exclusion under macOS `bsdtar`, and does not distinguish irreplaceable state from declarative or regenerable data.

## Scope

### In Scope
- Back up the documented Claude transcripts/state, OpenCode SQLite/auth/legacy storage, Engram snapshots, project `.engram/`, and nested `~/.claude/.claude/`.
- Preserve `.backup`, atomic publication, checksums, listing, dry-run, rollback copies, and integrity checks; restore `~/.claude.json` and realpath-named databases without replacing symlinks.
- Use `^`-anchored excludes, `.db.snapshot` staging with non-vacuous counts, and macOS xattr suppression.
- Document exclusions with citations, Samba security, Claude re-login, legacy-session checks, restore, and known limitations.
- Keep `mact2` as default source while supporting local, `t14`, `thinkcentre`, and `user@host` targets.

### Out of Scope
- Home Manager assets, caches, logs, binaries, environment snapshots, Claude credentials, and macOS Keychain data.
- Path remapping, nested-home deduplication, retention, scheduling, encryption, and Samba provisioning.

## Capabilities

### New Capabilities
- `ai-assistant-state-backup`: Manifest-driven backup, inspection, and safe restore of Claude Code, OpenCode, and Engram state.

### Modified Capabilities
- None; existing canonical specs do not govern AI-state backup.

## Approach

Stage SQLite snapshots as `.db.snapshot`, archive approved state with anchored exclusions and xattrs disabled, then stream through `zstd` to `/run/media/stuff/samba/backup/ai/<label>/`. Extend the current relocation restore. Warn that included OpenCode auth and possible Claude tokens make archives sensitive.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `pkgs/nixos-scripts/cmd/ai-backup/` | Modified | Manifest member list, portability defenses, and restore coverage |
| `docs/ai-backup.md` | New | Operator and security runbook |
| `pkgs/nixos-scripts/default.nix` | Retained | Package registration |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Silent omission or inconsistent DB | Medium | Anchors, snapshot naming/counts, `.backup`, archive inspection |
| Credential exposure on Samba | Medium | Restricted destination guidance and explicit security warning |
| Restore overwrites symlink/config | Low | Realpath names, pre-restore copies, dry-run |

## Rollback Plan

Restore the prior Go command and runbook; registration remains valid. Failed restores recover from timestamped pre-restore copies.

## Dependencies

- SSH, writable `rog` storage, `sqlite3`, `tar`/`bsdtar`, `zstd`, and SHA-256 tooling.

## Verification Plan

- Run `bash -n`, then `format-nix && nix flake check --no-build`.
- Run a real `mact2` backup; inspect required and excluded members, extract a snapshot, and obtain `ok` from `PRAGMA integrity_check`.

## Success Criteria

- [ ] Required portable state, including `~/.claude.json` and legacy storage, is present without live WAL databases or managed/ephemeral paths.
- [ ] Restore preserves symlinks, creates rollback copies, and verifies every restored database.
- [ ] The runbook enables a documented backup, inspection, re-login, and restore procedure.
