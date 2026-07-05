# Delta Spec: opencode-config-sync

## Context

Transfer all NixOS-generated opencode configuration from rog (x86_64, NixOS) to a remote host at 172.16.0.12 (aarch64, postmarketOS/OnePlus5) via SSH. A standalone deploy script at `bin/sync-opencode-remote` handles the entire transfer. No NixOS module changes are required.

## Affected Domains

| Domain | Type | Description |
|--------|------|-------------|
| opencode-config-sync | ADDED | Deploy script to sync opencode config from rog to remote |

---

## ADDED Requirements

### REQ-SYNC-001: File Transfer

**Priority**: MUST

The script SHALL transfer all platform-independent files from the source opencode config directory on rog to the remote host's opencode config directory using rsync over SSH.

**Included paths** (recursive unless noted):
- `opencode.json`
- `IDENTITY.md`
- `SYSTEM_RULES.md`
- `AGENTS.md`
- `sdd-orchestrator.md`
- `sdd-review-policy.md`
- `tui.json`
- `package.json`
- `.gitignore`
- `instructions/`
- `skills/` (except `skills.backup/`)
- `commands/`
- `plugins/`
- Any `*.md`, `*.json`, `*.jsonc`, `*.yaml`, `*.yml` files in the config root

**Excluded paths**:
- `node_modules/` — architecture-specific (x86_64), MUST NOT be transferred
- `*.backup` — stale local backups
- `skills.backup/` — stale local backup
- `.opencode/` — runtime state, host-specific
- `themes/` — silently skipped if absent on source

**Scenarios**:

```
Given the script is invoked without --dry-run
  And the remote config directory exists (even if empty)
 When the script runs
 Then all included files are present on the remote under ~/.config/opencode/
  And excluded paths are NOT present on the remote
  And the transfer uses rsync over SSH (not scp or cp)
```

```
Given the script runs a second time with no changes on the source
 When the script completes
 Then no files are transferred (config already up to date)
  And the script exits with status 0
```

---

### REQ-SYNC-002: Remote Backup

**Priority**: MUST

Before overwriting the remote config directory, the script SHALL create a timestamped backup of the remote's current `~/.config/opencode/` directory.

**Backup naming**: `~/.config/opencode.bak.YYYYMMDD-HHMMSS`

**Scenarios**:

```
Given the remote config directory exists with existing files
 When the script runs
 Then a backup is created at ~/.config/opencode.bak.<timestamp>
  And the backup SHALL contain a complete copy of the pre-existing config
  And the backup timestamp SHALL be in the format YYYYMMDD-HHMMSS
```

```
Given the remote config directory does NOT exist
 When the script runs
 Then the backup step is skipped (nothing to back up)
  And the script continues without error
```

```
Given the script is invoked with --dry-run
 When the script runs
 Then NO backup is created on the remote
```

---

### REQ-SYNC-003: Dry-Run Mode

**Priority**: MUST

The script SHALL accept a `--dry-run` flag. When set, the script SHALL display all actions it would perform without modifying the remote host.

**Output**: Display the rsync file list (what would be transferred/deleted) and the post-transfer steps that would run, then exit without making changes.

**Scenarios**:

```
Given the script is invoked with --dry-run
 When the script runs
 Then NO backup is created on the remote
  And NO files are transferred to the remote
  And npm install is NOT executed on the remote
  And the output lists all files that rsync would transfer
```

```
Given the script is invoked with --dry-run
  And the remote has had changes since the last sync
 When the script runs
 Then the output shows the files that would be added/modified/deleted
  And the script exits with status 0
```

---

### REQ-SYNC-004: Native Dependency Installation

**Priority**: MUST

After transferring platform-independent files, the script SHALL connect to the remote via SSH and run `npm install` in the remote config directory to install native aarch64 node_modules.

**Scenarios**:

```
Given the file transfer completed successfully
 When the script continues to the post-transfer step
 Then SSH to the remote and run: cd ~/.config/opencode && npm install
  And node_modules/ on the remote contains aarch64-native binaries
```

```
Given the file transfer fails (rsync error)
 When the script handles the error
 Then npm install SHALL NOT be executed
  And the script exits with a non-zero status
```

```
Given the script is invoked with --dry-run
 When the script runs
 Then npm install is NOT executed
  And the output notes that npm install would run
```

---

### REQ-SYNC-005: Architecture Exclusion

**Priority**: MUST

The script SHALL exclude `node_modules/` from the rsync transfer because the architecture differs (source: x86_64, destination: aarch64). Transferring x86_64 node_modules would corrupt the remote installation.

**Scenarios**:

```
Given the source has node_modules/ (130M of x86_64 binaries)
 When rsync runs
 Then node_modules/ is NOT included in the transfer
  And no error is produced for the exclusion
```

```
Given the remote has its own node_modules/ from npm install
 When the script runs subsequently
 Then the remote's aarch64 node_modules/ is NOT removed by rsync --delete
```

---

### REQ-SYNC-006: Error Handling — SSH Unreachable

**Priority**: MUST

If the remote host is unreachable via SSH, the script SHALL abort immediately without making any changes.

**Scenarios**:

```
Given the remote host 172.16.0.12 is unreachable
 When the script runs
 Then an error message is printed: "ERROR: Remote host 172.16.0.12 is unreachable"
  And the script exits with a non-zero status
  AND no backup is attempted
  AND no files are transferred
```

---

### REQ-SYNC-007: Error Handling — rsync Failure

**Priority**: MUST

If the rsync transfer fails partway through, the script SHALL report the failure and exit with a non-zero status. The pre-existing backup on the remote preserves the original state.

**Scenarios**:

```
Given the rsync transfer fails mid-transfer (e.g., connection drops)
 When the script detects the failure
 Then an error message is printed with the rsync exit code
  And the script exits with a non-zero status
  And the remote backup is NOT deleted (preserving original config)
```

---

### REQ-SYNC-008: Error Handling — npm Install Failure

**Priority**: SHOULD

If `npm install` fails on the remote, the script SHALL report the failure but NOT revert the transferred config. The platform-independent files are already correct; only native dependencies failed.

**Scenarios**:

```
Given the file transfer succeeded
  And npm install fails on the remote (e.g., network issue, missing deps)
 When the script detects the failure
 Then an error message is printed: "WARNING: npm install failed on remote"
  And the script exits with a non-zero status
  And the transferred config remains in place (not reverted)
```

---

### REQ-SYNC-009: Script Placement and Execution

**Priority**: MUST

The script SHALL be located at `bin/sync-opencode-remote` relative to the repo root. It SHALL be a standalone POSIX shell script (not a Nix derivation) with no external dependencies beyond `ssh`, `rsync`, and standard POSIX utilities.

**Scenarios**:

```
Given the repository is cloned at ~/.nixos
 When checking for the script
 Then ~/.nixos/bin/sync-opencode-remote exists
  And the file is executable (chmod +x)
  And the shebang is #!/usr/bin/env sh or #!/bin/sh
```

---

### REQ-SYNC-010: Configurability

**Priority**: SHOULD

The script SHOULD define its source and destination as variables at the top of the script, making it easy to re-target for other hosts.

**Scenarios**:

```
Given a developer opens the script
 When reading the top section
 Then they see editable variables:
   - REMOTE_HOST (default: "172.16.0.12")
   - REMOTE_USER (default: "glats")
   - REMOTE_DIR  (default: "~/.config/opencode")
   - LOCAL_DIR   (default: "$HOME/.config/opencode")
```

---

### REQ-SYNC-011: Documentation — API Key Setup

**Priority**: SHOULD

The script output and/or a comment header SHALL document that API keys are NOT transferred by this script and must be configured separately on the remote via environment variables (e.g., in `.zshrc` or `.profile`).

**Scenarios**:

```
Given a user runs the script
 When the script completes
 Then the output includes a reminder:
   "REMINDER: API keys are NOT transferred by this script.
    Configure them on the remote via environment variables.
    See: sops secrets/secrets.yaml for the key file."
```

```
Given a developer reads the script header
 When inspecting the comments
 Then they find documentation about required env vars:
   - OPENAI_API_KEY
   - Any other provider keys used by the config
```

---

### REQ-SYNC-012: Verbose Output

**Priority**: MAY

The script SHOULD print clear, human-readable progress messages for each major step: "Backing up remote config...", "Syncing files...", "Installing dependencies...".

**Scenarios**:

```
Given the script runs normally
 When executing each step
 Then the output includes progress messages
  And each message is prefixed with a step label like [1/3], [2/3], [3/3]
```

---

### REQ-SYNC-013: Idempotency

**Priority**: MUST

Running the script multiple times with no changes on the source SHALL be safe. The second run SHALL transfer zero files and produce no errors.

**Scenarios**:

```
Given the script has been run once successfully
  And no files changed on the source since that run
 When the script runs again
 Then rsync transfers zero files
  And npm install produces no new changes (node_modules up to date)
  And the script exits with status 0
```

```
Given the script has been run once successfully
  And one file changed on the source since that run
 When the script runs again
 Then only the changed file is transferred
  And a fresh backup is created before the transfer
```

---

## Specification Coverage

| Requirement | Priority | Scenarios |
|-------------|----------|-----------|
| REQ-SYNC-001 | MUST | 2 |
| REQ-SYNC-002 | MUST | 3 |
| REQ-SYNC-003 | MUST | 2 |
| REQ-SYNC-004 | MUST | 3 |
| REQ-SYNC-005 | MUST | 2 |
| REQ-SYNC-006 | MUST | 1 |
| REQ-SYNC-007 | MUST | 1 |
| REQ-SYNC-008 | SHOULD | 1 |
| REQ-SYNC-009 | MUST | 1 |
| REQ-SYNC-010 | SHOULD | 1 |
| REQ-SYNC-011 | SHOULD | 2 |
| REQ-SYNC-012 | MAY | 1 |
| REQ-SYNC-013 | MUST | 2 |
| **Total** | | **22 scenarios** |
