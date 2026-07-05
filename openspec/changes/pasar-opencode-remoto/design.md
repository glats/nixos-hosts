# Design: Transfer Nix-generated opencode config from rog to remote

## 1. Architecture Overview

```
rog (x86_64, NixOS)                    remote (aarch64, postmarketOS)
+------------------+                   +---------------------------+
| ~/.config/opencode/                  | ~/.config/opencode/       |
|  - opencode.json  |                  |  - opencode.json          |
|  - IDENTITY.md    |  rsync over SSH  |  - IDENTITY.md            |
|  - skills/        | ===============> |  - skills/                |
|  - instructions/  |  (include-filter) |  - instructions/          |
|  - ...            |                  |  - ...                    |
|  (node_modules/   |  EXCLUDED        |  node_modules/ ← npm install
|   x86_64)         |                  |   (aarch64)               |
+------------------+                   +---------------------------+
        |                                          |
        | [1] Pre-flight (SSH check)               |
        | [2] If not --dry-run:                     |
        |      ssh remote: backup existing dir      |
        | [3] rsync --delete (include/exclude)      |
        | [4] If not --dry-run:                     |
        |      ssh remote: npm install              |
        | [5] Post-sync summary                     |
```

The script executes entirely on rog, controlling the remote via SSH. No agent software runs on the remote — it can be a bare bones postmarketOS host with only ssh, rsync, and npm.

## 2. Script Structure

### 2.1 Full Function/Module Breakdown

```
sync-opencode-remote
│
├── Configuration / Argument Parsing
│   ├── Default config (REMOTE_HOST, REMOTE_USER, REMOTE_DIR, LOCAL_DIR)
│   ├── Env var overrides
│   ├── --dry-run flag parsing
│   └── --help flag
│
├── Pre-flight Checks
│   ├── SSH reachability (ssh -o ConnectTimeout=5 -q)
│   ├── rsync on local host (command -v rsync)
│   ├── Local source dir exists and is readable
│   └── Bail with error + exit code if any check fails
│
├── Dry-Run Mode
│   ├── Display rsync command with --dry-run
│   ├── Run rsync with --dry-run to show file list
│   ├── Display "would run: npm install on remote"
│   └── Exit with status 0 (no changes made)
│
├── Remote Backup
│   ├── SSH: test if remote dir exists
│   ├── If exists: ssh cp -a for timestamped backup
│   ├── If not exists: skip backup, continue
│   └── Backup path: ~/.config/opencode.bak.YYYYMMDD-HHMMSS
│
├── rsync Transfer
│   ├── Build rsync command with exact include/exclude filter list
│   ├── --archive --delete --compress --verbose
│   ├── Execute rsync
│   └── Check exit code; abort + error if non-zero
│
├── npm Install on Remote
│   ├── SSH: check if npm is available
│   ├── SSH: cd DIR && npm install
│   ├── On failure: print WARNING only, do NOT revert
│   └── On success: print confirmation
│
├── Post-Sync Summary
│   ├── Print success message
│   ├── Print API key reminder (REQ-SYNC-011)
│   └── Print backup location
└── Exit with appropriate code
```

### 2.2 Script Flow (Pseudocode)

```sh
#!/bin/sh
set -euo pipefail

# === CONFIGURATION ===
REMOTE_HOST="${REMOTE_HOST:-172.16.0.12}"
REMOTE_USER="${REMOTE_USER:-glats}"
REMOTE_DIR="${REMOTE_DIR:-~/.config/opencode}"
LOCAL_DIR="${LOCAL_DIR:-$HOME/.config/opencode}"
DRY_RUN=false

# === ARGUMENT PARSING ===
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --help) usage; exit 0 ;;
        *) echo "ERROR: Unknown option: $arg"; usage; exit 1 ;;
    esac
done

# === PRE-FLIGHT ===
check_ssh "$REMOTE_HOST"         # exit 2 on failure
check_rsync                      # exit 1 on failure
check_local_dir "$LOCAL_DIR"     # exit 1 on failure

# === BACKUP (skip if --dry-run) ===
if [ "$DRY_RUN" = false ]; then
    remote_backup "$REMOTE_USER@$REMOTE_HOST" "$REMOTE_DIR"
fi

# === TRANSFER ===
run_rsync "$LOCAL_DIR" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR" "$DRY_RUN"
# exit 3 on failure

# === POST-TRANSFER (skip if --dry-run) ===
if [ "$DRY_RUN" = false ]; then
    remote_npm_install "$REMOTE_USER@$REMOTE_HOST" "$REMOTE_DIR"
    # WARNING only on failure, not fatal
fi

# === SUMMARY ===
print_summary "$DRY_RUN"
```

## 3. Data Flow

### Input -> Transformation -> Output

```
Input (rog local filesystem)
│
│  opencode.json           (structured config)
│  IDENTITY.md             (identity/behavior rules)
│  SYSTEM_RULES.md         (system prompt rules)
│  AGENTS.md               (skill index)
│  sdd-orchestrator.md     (orchestrator instructions)
│  sdd-review-policy.md    (review policy)
│  tui.json                (TUI config)
│  package.json            (npm dependencies metadata)
│  .gitignore              (ignore rules)
│  instructions/*.md       (user-facing instructions)
│  skills/*/SKILL.md       (AI skill files)
│  commands/*.md           (slash commands)
│  plugins/*.ts            (opencode plugins)
│  themes/*                (theme files, if exist)
│
Transformation (rsync filter)
│
│  rsync --archive --delete --verbose \
│    --include='/' \
│    --include='/opencode.json' \
│    --include='/IDENTITY.md' \
│    --include='/SYSTEM_RULES.md' \
│    --include='/AGENTS.md' \
│    --include='/sdd-orchestrator.md' \
│    --include='/sdd-review-policy.md' \
│    --include='/tui.json' \
│    --include='/package.json' \
│    --include='/.gitignore' \
│    --include='/*.md' \
│    --include='/*.json' \
│    --include='/*.jsonc' \
│    --include='/*.yaml' \
│    --include='/*.yml' \
│    --include='/instructions/' \
│    --include='/instructions/**' \
│    --include='/skills/' \
│    --include='/skills/**' \
│    --include='/commands/' \
│    --include='/commands/**' \
│    --include='/plugins/' \
│    --include='/plugins/**' \
│    --include='/themes/' \
│    --include='/themes/**' \
│    --exclude='/.opencode/' \
│    --exclude='/.opencode/**' \
│    --exclude='/node_modules/' \
│    --exclude='/node_modules/**' \
│    --exclude='*.backup' \
│    --exclude='/skills.backup/' \
│    --exclude='/skills.backup/**' \
│    --exclude='/*' \
│
Output (remote filesystem)
│
│  Exact mirror of source, minus excluded paths
│  node_modules/ → generated fresh on remote via npm install
```

### rsync Include/Exclude Pattern — Detailed Rationale

The pattern uses **whitelist-first** semantics:

1. **`--include='/'`** — include the root directory itself (required for rsync to traverse)
2. **Specific file includes** — one `--include` per file/directory in the allowlist
3. **Directories with `--include='/**'`** — for directories, include all contents recursively
4. **Root-level wildcards** — `--include='/*.md'`, `--include='/*.json'` etc. for any new files added to root
5. **Explicit exclusions** — `node_modules/`, `*.backup`, `skills.backup/`, `.opencode/` and all contents
6. **`--exclude='/*'`** — deny everything else at the top level (directory contents within allowlisted dirs are covered by `/**` patterns)

Without the trailing `--exclude='/*'`, any new top-level file/directory added to LOCAL_DIR would be transferred. The whitelist ensures only intentionally configured items are synced.

### Why --delete is Safe

`--delete` on the rsync destination removes files that exist on the remote but not on the source. This is safe because:
- **Backup runs first**: the remote's complete original state is saved to a timestamped backup
- **npm is post-rsync**: `node_modules/` is excluded from rsync, so `--delete` does not touch it
- **Exact mirror**: ensures no stale files accumulate on the remote (e.g., old plugins removed from config)

## 4. Error Handling Strategy

| Failure Mode | Detection | Action | Exit Code |
|---|---|---|---|
| SSH host unreachable | `ssh -o ConnectTimeout=5 -q $host exit` returns non-zero | Print error, abort immediately | 2 |
| rsync not found locally | `command -v rsync` | Print error, abort | 1 |
| Local source dir missing | `[ -d "$LOCAL_DIR" ]` | Print error, abort | 1 |
| Unknown CLI arg | Case default | Print usage, abort | 1 |
| rsync fails mid-transfer | rsync non-zero exit | Print error with exit code, mention backup, abort | 3 |
| npm not found on remote | `ssh ... command -v npm` | Print warning, continue (files are already there) | 0 (files ok) |
| npm install fails | remote npm non-zero exit | Print warning, DO NOT revert config, exit 4 | 4 |
| Backup creation fails | `ssh ... cp -a` fails | Print error, abort before rsync (no changes made) | 2 |

### Exit Code Convention

| Code | Meaning |
|---|---|
| 0 | Success (all steps completed, or dry-run completed) |
| 1 | Configuration or argument error |
| 2 | SSH/connectivity error |
| 3 | rsync transfer error |
| 4 | npm install failure (config was transferred) |

## 5. Idempotency

Three mechanisms ensure safe re-runs:

### 5.1 rsync --delete produces exact mirror
When no files changed on the source, `rsync --delete` transfers zero bytes. The second run is a no-op for file transfer.

### 5.2 Backup is always timestamped
Each run creates `~/.config/opencode.bak.YYYYMMDD-HHMMSS` — never overwrites previous backups. Running the script ten times creates ten independent backups.

### 5.3 npm install is idempotent
`npm install` checks `node_modules/` against `package.json` and `package-lock.json`. If dependencies are current, it does nothing and exits 0.

### 5.4 Proof: two-run scenario
```
Run 1: backup → rsync (all files) → npm install (installs deps)
Run 2: backup → rsync (0 files transferred) → npm install (0 changes, already satisfied)
```

## 6. Configuration Interface

```sh
# === CONFIGURATION — edit these or set env vars ===
REMOTE_HOST="${REMOTE_HOST:-172.16.0.12}"
REMOTE_USER="${REMOTE_USER:-glats}"
REMOTE_DIR="${REMOTE_DIR:-~/.config/opencode}"
LOCAL_DIR="${LOCAL_DIR:-$HOME/.config/opencode}"
```

Usage examples:

```sh
# Default (sync to 172.16.0.12 as glats)
./bin/sync-opencode-remote

# Dry-run (show what would change)
./bin/sync-opencode-remote --dry-run

# Target a different host
REMOTE_HOST=10.0.0.5 ./bin/sync-opencode-remote

# Custom user/dir
REMOTE_USER=admin REMOTE_DIR=/opt/opencode ./bin/sync-opencode-remote
```

## 7. Security Considerations

### 7.1 No secrets in script
The script does not contain, generate, or manage API keys. It transfers only configuration files (rules, prompts, skill definitions). A header comment + runtime output documents the requirement to configure secrets separately.

### 7.2 SSH key-based auth
The script assumes passwordless SSH keys are pre-configured. The `ssh` command uses no password flag. If the key is not set up, SSH fails with exit code 2 and the script aborts.

### 7.3 Backup preserves remote data
Before overwriting, a full copy of the remote config directory is saved. This means:
- Rollback is a single `mv` command on the remote
- If rsync accidentally deletes something (via `--delete`), the backup has the original

### 7.4 Dry-run prevents accidental changes
With `--dry-run`, no SSH commands that modify state are executed. Only read-only rsync (with `--dry-run`) runs, ensuring zero side effects.

### 7.5 No sudo escalation
All operations (rsync, npm install) run as the remote user. No `sudo` is used anywhere, avoiding privilege escalation concerns.

## 8. Testing Approach

### 8.1 Test Matrix

| Test | Command | Expected Result | What it Verifies |
|---|---|---|---|
| Dry-run | `./sync-opencode-remote --dry-run` | Lists files to transfer, no backups created, exits 0 | REQ-SYNC-003 |
| First run | `./sync-opencode-remote` | Config appears on remote, npm installs | REQ-SYNC-001, REQ-SYNC-004 |
| Idempotency | `./sync-opencode-remote` (2nd time) | 0 files transferred, npm no-op, exits 0 | REQ-SYNC-013 |
| Exclusions | Check remote after sync | No node_modules/ on remote (npm install creates them) | REQ-SYNC-005 |
| SSH failure | Unplug network or invalid host | "ERROR: Remote host unreachable", exits 2, no changes | REQ-SYNC-006 |
| rsync failure | Simulate with invalid path | Error message mentioning backup, exits 3 | REQ-SYNC-007 |
| npm failure | Temporarily break npm on remote | "WARNING: npm install failed", exits 4, config remains | REQ-SYNC-008 |
| Backup check | Run and inspect remote | `~/.config/opencode.bak.*` exists with original files | REQ-SYNC-002 |
| Modified file | Touch a file on source, re-run | Only that file is transferred | REQ-SYNC-013 |

### 8.2 Simulating Failures

```sh
# SSH failure
REMOTE_HOST=192.0.2.1 ./sync-opencode-remote
# Expected: exits 2, "ERROR: Remote host 192.0.2.1 is unreachable"

# rsync failure (by injecting bad path, not easily faked)
# Alternative: temporarily break local source
REMOTE_DIR=/nonexistent/path ./sync-opencode-remote
# Expected: rsync fails partway, exits 3

# npm failure
ssh glats@172.16.0.12 "mv /usr/bin/npm /usr/bin/npm.disabled"
./sync-opencode-remote
# Expected: transfer succeeds, exits 4, "WARNING: npm install failed on remote"
ssh glats@172.16.0.12 "mv /usr/bin/npm.disabled /usr/bin/npm"
```

## 9. Script File Specification

- **Path**: `bin/sync-opencode-remote` (relative to repo root)
- **Permissions**: `+x` (executable)
- **Shebang**: `#!/bin/sh` (POSIX shell, not bash-specific)
- **Dependencies**: `ssh`, `rsync`, `cp`, `date`, `basename`, `command` (all available on NixOS base and postmarketOS)
- **Style**: Bash-style `set -euo pipefail` for strict error handling, but script is compatible with POSIX `sh` for basic path.

The script will use `#!/usr/bin/env bash` to match the existing convention in `bin/` (nixos-build, git-flow use this), but will avoid bashisms beyond what's needed for `set -euo pipefail`.

## 10. Detailed rsync Command

```sh
rsync --archive --delete --compress --verbose \
  --rsh="ssh" \
  --include='/' \
  --include='/opencode.json' \
  --include='/IDENTITY.md' \
  --include='/SYSTEM_RULES.md' \
  --include='/AGENTS.md' \
  --include='/sdd-orchestrator.md' \
  --include='/sdd-review-policy.md' \
  --include='/tui.json' \
  --include='/package.json' \
  --include='/.gitignore' \
  --include='/*.md' \
  --include='/*.json' \
  --include='/*.jsonc' \
  --include='/*.yaml' \
  --include='/*.yml' \
  --include='/instructions/' \
  --include='/instructions/**' \
  --include='/skills/' \
  --include='/skills/**' \
  --include='/commands/' \
  --include='/commands/**' \
  --include='/plugins/' \
  --include='/plugins/**' \
  --include='/themes/' \
  --include='/themes/**' \
  --exclude='/.opencode/' \
  --exclude='/.opencode/**' \
  --exclude='/node_modules/' \
  --exclude='/node_modules/**' \
  --exclude='*.backup' \
  --exclude='/skills.backup/' \
  --exclude='/skills.backup/**' \
  --exclude='/*' \
  "$LOCAL_DIR"/ \
  "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR"
```

Key rsync flags:

| Flag | Purpose |
|---|---|
| `--archive` | Preserve permissions, timestamps, symlinks, recursive |
| `--delete` | Remove files on remote that don't exist on source |
| `--compress` | Compress during transfer (reduces bandwidth for text files) |
| `--verbose` | Show files being transferred (REQ-SYNC-012) |
| `--rsh="ssh"` | Use SSH as transport (explicit for clarity) |
| `--dry-run` | Added when `$DRY_RUN=true` — show what would happen |

The trailing slash on `"$LOCAL_DIR"/` is critical — it means "copy the contents of the directory", not "copy the directory itself". This ensures the remote's `~/.config/opencode/` gets the files, not `~/.config/opencode/opencode/`.

## 11. Open Questions

None. All design decisions are resolved:

- **Why not rsync filter rules from a file?** Inline includes are self-documenting. The entire file list is visible in the script.
- **Why --delete instead of mirroring manually?** `--delete` handles removed files automatically. Without it, removing a plugin from the source leaves it on the remote forever.
- **Why not use `systemd.timers` on rog to auto-sync?** The config only changes during Nix builds. Manual invocation is appropriate.
- **Why POSIX sh over bash?** postmarketOS might have bash as a symlink but we don't need bash extensions. The script stays compatible.
- **Why include themes/ if it might not exist?** rsync handles missing source dirs gracefully (silently skips). The include pattern for themes/ is harmless if the directory doesn't exist.

## 12. Files Affected

| File | Action |
|---|---|
| `bin/sync-opencode-remote` | CREATE — the deploy script |
| Remote `~/.config/opencode/` | MODIFIED (sync target, not in repo) |
