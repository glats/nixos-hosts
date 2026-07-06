# Tasks: bin/sync-opencode-remote

## Review Workload Forecast

- **Estimated changed lines**: ~120 (single new file, ~100 lines script + ~15 lines header)
- **400-line budget risk**: Low
- **Chained PRs recommended**: No
- **Decision needed before apply**: No

---

## Phase 1: Script Creation

### T-001 — Create `bin/sync-opencode-remote` skeleton [x]

**Scope**: Create the file with shebang, config variables, help text, and argument parsing.

**Deliverables**:
- `bin/sync-opencode-remote` with `#!/usr/bin/env bash`
- Config variables: `REMOTE_HOST`, `REMOTE_USER`, `REMOTE_DIR`, `LOCAL_DIR` with defaults
- `--help` / `-h` flag printing usage
- `--dry-run` flag parsing (set `DRY_RUN=1`)
- Unknown argument -> usage + exit 1

**Spec refs**: REQ-SYNC-009, REQ-SYNC-010, REQ-SYNC-001

---

### T-002 — Add pre-flight checks [x]

**Scope**: SSH reachability, rsync present, local source dir exists.

**Deliverables**:
- `ssh -o ConnectTimeout=5 -q "$REMOTE_USER@$REMOTE_HOST" exit` -> exit 2 if fails
- `command -v rsync` -> exit 1 if missing
- `[ -d "$LOCAL_DIR" ]` -> exit 1 if missing

**Spec refs**: REQ-SYNC-006, REQ-SYNC-009

---

### T-003 — Implement `--dry-run` path [x]

**Scope**: When `--dry-run` is set, show what would sync and exit.

**Deliverables**:
- Print step labels: "DRY RUN -- no changes will be made"
- Run rsync with `--dry-run` flag (same include/exclude pattern) to show file list
- Print: "Would run: npm install on remote"
- Print: "Would create backup on remote"
- Exit 0 (no backup, no transfer, no npm)

**Spec refs**: REQ-SYNC-003

---

### T-004 — Implement remote backup step [x]

**Scope**: Create timestamped backup of remote config before overwriting.

**Deliverables**:
- SSH to remote: `test -d "$REMOTE_DIR"` -- skip backup if not exists
- Generate timestamp: `YYYYMMDD-HHMMSS`
- SSH command: `cp -a "$REMOTE_DIR" "${REMOTE_DIR}.bak.$TIMESTAMP"`
- Print: "[1/3] Backing up remote config to opencode.bak.<timestamp>..."
- On failure: exit 2 (do not proceed)

**Spec refs**: REQ-SYNC-002, REQ-SYNC-006

---

### T-005 — Implement rsync transfer with whitelist include/exclude [x]

**Scope**: Core transfer logic with the full whitelist-first pattern.

**Deliverables**:
- rsync command with all `--include` / `--exclude` flags per design section 3
- `--archive --delete --compress --verbose`
- Trailing slash on `"$LOCAL_DIR"/` (contents sync)
- Print: "[2/3] Syncing files to remote..."
- On rsync failure: exit 3

**Spec refs**: REQ-SYNC-001, REQ-SYNC-005, REQ-SYNC-007, REQ-SYNC-013

---

### T-006 — Implement npm install on remote [x]

**Scope**: Post-transfer dependency installation.

**Deliverables**:
- SSH to remote: `cd "$REMOTE_DIR" && npm install`
- Print: "[3/3] Installing dependencies on remote..."
- On npm not found: print warning, exit 0 (files are fine)
- On npm failure: print WARNING, exit 4 (non-fatal, config preserved)

**Spec refs**: REQ-SYNC-004, REQ-SYNC-008

---

### T-007 — Add summary output and API key reminder [x]

**Scope**: Post-success messaging.

**Deliverables**:
- Print: "Sync complete. Files transferred to <host>."
- Print API key reminder (per REQ-SYNC-011)
- Print backup location if created

**Spec refs**: REQ-SYNC-011, REQ-SYNC-012

---

### T-008 — Script header documentation [x]

**Scope**: Comment header at top of script.

**Deliverables**:
- Brief description of what the script does
- Required tools: ssh, rsync, npm (remote)
- Environment variable overrides: OPENAI_API_KEY (etc.) must be set on remote
- Usage example: `./bin/sync-opencode-remote` / `./bin/sync-opencode-remote --dry-run`

**Spec refs**: REQ-SYNC-011

---

## Phase 2: Verification

### T-009 — Make executable and verify syntax [x]

**Deliverables**:
- `chmod +x bin/sync-opencode-remote`
- `bash -n bin/sync-opencode-remote` passes (no syntax errors)

---

### T-0010 — Dry-run test [x]

**Deliverables**:
- Run `./bin/sync-opencode-remote --dry-run`
- Verify: no files transferred, no backup created, file list displayed
- Verify: exit code 0

---

### T-0011 — Full sync test (requires remote at 172.16.0.12)

**Deliverables**:
- Run `./bin/sync-opencode-remote`
- Verify: backup created on remote
- Verify: all included files present on remote
- Verify: node_modules/ NOT present on remote (from rsync)
- Verify: exit code 0

---

### T-0012 — Idempotency test

**Deliverables**:
- Run `./bin/sync-opencode-remote` a second time without source changes
- Verify: rsync transfers zero bytes
- Verify: exit code 0

---

## Phase 3: Integration

### T-0013 — Commit and stage

**Deliverables**:
- `git add bin/sync-opencode-remote`
- Commit: `feat(sync): add opencode config sync script for remote host`
- Verify: `nix flake check --no-build` still passes
