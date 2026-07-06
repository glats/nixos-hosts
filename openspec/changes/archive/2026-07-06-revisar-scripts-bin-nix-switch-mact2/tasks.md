# SDD Tasks: revisar-scripts-bin-nix-switch-mact2

## Review Workload Forecast

- **Delivery strategy**: `ask-on-risk` (default)
- **400-line budget risk**: LOW (~121 total lines across 4 commits)
- **Decision needed before apply**: No
- **Chained PRs recommended**: No — single PR with 4 atomic commits
- **Pre-existing issues**: `nix flake check --no-build` currently fails with `error: path '...-source' is not valid` (unrelated to this change; likely a flake input fetch issue)

## Commit Order Rationale

| Order | Commit | Dependencies | Lines Δ |
|-------|--------|-------------|---------|
| 1 | Fix HM bug | None | -9 |
| 2 | Shared lib + WireGuard refactor | None | +35, -21 |
| 3 | Package all scripts | Commit 2 (lib must exist before WG scripts are packaged) | +15, -8 |
| 4 | Merge sops-add-t14 into sops-rotate-keys | None (but should come after packaging so script is included in the derivation) | +25, -8 |

Total: ~121 lines changed across 4 files updated, 1 file created, 1 file deleted.

---

## Task 1: Remove redundant HM activation on Darwin

**Scope**: `bin/nixos-build` — Remove 3 blocks (9 lines total) that run `home-manager switch` after `darwin-rebuild switch` on Darwin hosts.

### Rationale

`darwin/default.nix` already imports `inputs.home-manager.darwinModules.home-manager`, making HM a first-class nix-darwin module. `darwin-rebuild switch` activates HM as part of its system closure. The standalone `home-manager switch` after it is redundant and wastes time.

### Files to Modify

| File | Change |
|------|--------|
| `bin/nixos-build` | Remove 3 blocks of 3 lines each in `switch`, `upgrade`, and `safe` cases |

### Exact Changes

#### Change 1: `switch` case — Remove lines 130-132

**Before:**
```bash
      darwin_build switch
      echo ""
      echo "> Switching home-manager..."
      home-manager switch --flake "$FLAKE_PATH#$HOSTNAME"
    else
```

**After:**
```bash
      darwin_build switch
    else
```

#### Change 2: `upgrade` case — Remove lines 181-183

**Before:**
```bash
      darwin_build switch
      echo ""
      echo "> Switching home-manager..."
      home-manager switch --flake "$FLAKE_PATH#$HOSTNAME"
    else
```

**After:**
```bash
      darwin_build switch
    else
```

#### Change 3: `safe` case — Remove lines 300-302

**Before:**
```bash
        exit 1
      fi
      echo ""
      echo "> Switching home-manager..."
      home-manager switch --flake "$FLAKE_PATH#$HOSTNAME"
    else
```

**After:**
```bash
        exit 1
      fi
    else
```

### Verification

```bash
# Syntax check on the changed file
bash -n bin/nixos-build

# Nix flake check (note: pre-existing unrelated failure expected)
nix flake check --no-build

# Review diff
git diff --stat
# Expected: 1 file changed, 9 deletions
```

### Checklist

- [ ] Lines 130-132 removed from `switch` case (the `echo ""`, `echo "> Switching..."`, `home-manager switch` block)
- [ ] Lines 181-183 removed from `upgrade` case
- [ ] Lines 300-302 removed from `safe` case
- [ ] `bash -n bin/nixos-build` passes (no syntax errors)
- [ ] No whitespace or formatting issues (run `nix fmt -- bin/nixos-build` if Nix file; bash file skipped)

---

## Task 2: Create shared shell library and refactor WireGuard scripts

**Scope**: Create `bin/lib/common.sh` with shared utilities. Replace identical preamble in 3 WireGuard scripts.

### Rationale

Three WireGuard scripts (`add-wireguard-peer`, `remove-wireguard-peer`, `generate-thinkpad-wireguard`) share identical 8-line preamble (lines 1-8) with SCRIPT_DIR, REPO_ROOT, HOST, and cd. Extracting this to a shared library eliminates 18 lines of duplication and provides a single source of truth for REPO_ROOT detection.

### Files to Create/Modify

| File | Action |
|------|--------|
| `bin/lib/common.sh` | CREATE (new shared library) |
| `bin/add-wireguard-peer` | MODIFY (replace preamble with source) |
| `bin/remove-wireguard-peer` | MODIFY (replace preamble with source) |
| `bin/generate-thinkpad-wireguard` | MODIFY (replace preamble with source) |

### New File: `bin/lib/common.sh`

Create with the following content:

```bash
#!/usr/bin/env bash
# common.sh - Shared shell utilities for NixOS scripts
# Source from other scripts:
#   source "$(dirname "$0")/lib/common.sh"

# --- Repo root detection ---
# Priority: NIXOS_REPO env var > git rev-parse > SCRIPT_DIR parent > ~/.nixos
_find_repo_root() {
  local script_dir

  if [[ -n "${NIXOS_REPO:-}" ]]; then
    echo "$NIXOS_REPO"
    return
  fi

  script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd 2>/dev/null || true)"

  if git rev-parse --show-toplevel &>/dev/null; then
    git rev-parse --show-toplevel
  elif [[ -d "$script_dir/../.git" || -f "$script_dir/../flake.nix" ]]; then
    echo "$(dirname "$script_dir")"
  else
    echo "${HOME}/.nixos"
  fi
}

REPO_ROOT="$(_find_repo_root)"
HOST="$(hostname)"

# --- Utility functions ---
die() {
  echo "Error: $1" >&2
  exit "${2:-1}"
}

usage() {
  local msg="${1:-}"
  if [[ -n "$msg" ]]; then
    echo "Error: $msg" >&2
    echo "" >&2
  fi
  shift
  cat >&2 <<EOF
Usage: $(basename "$0") $*
EOF
  exit 2
}
```

### Changes to WireGuard Scripts

For EACH of the 3 scripts (`add-wireguard-peer`, `remove-wireguard-peer`, `generate-thinkpad-wireguard`):

**Before (lines 1-8):**
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
HOST=$(hostname)

cd "$REPO_ROOT"
```

**After (replacement):**
```bash
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"
cd "$REPO_ROOT"
```

### Verification

```bash
# Syntax check on all files
bash -n bin/lib/common.sh
bash -n bin/add-wireguard-peer
bash -n bin/remove-wireguard-peer
bash -n bin/generate-thinkpad-wireguard

# Quick functional test (dry run - should fail gracefully without peer)
bin/add-wireguard-peer test-peer 2>&1 || true
# Expected: "Error: Secret file already exists" or new file created

# Verify REPO_ROOT resolution from a temp directory
cd /tmp && bash -c 'source "$HOME/.nixos/bin/lib/common.sh" && echo "REPO_ROOT=$REPO_ROOT"' || true
```

### Checklist

- [ ] `bin/lib/common.sh` created with correct content
- [ ] `bin/add-wireguard-peer` preamble replaced (lines 4-8 → 2 lines)
- [ ] `bin/remove-wireguard-peer` preamble replaced
- [ ] `bin/generate-thinkpad-wireguard` preamble replaced
- [ ] `bash -n` passes on all 4 files
- [ ] Each script still has `set -euo pipefail` (per-script setting, NOT in shared lib)
- [ ] Each script still has `cd "$REPO_ROOT"` after the source
- [ ] `git diff --stat` shows 3 modified + 1 new file

---

## Task 3: Package all remaining bin/ scripts

**Scope**: Rewrite `pkgs/nixos-scripts/default.nix` to install ALL 11 scripts via a loop, plus distribute `lib/common.sh` alongside them.

### Rationale

Only 4 of 12 `bin/` scripts are currently packaged in `nixos-scripts`. The remaining 7 executables (plus `sops-add-t14` which is deleted in Task 4) are only available via `~/.nixos/bin` PATH. This commit adds all remaining scripts to the derivation, ensuring they are available on all hosts via the nix store.

### File to Modify

| File | Action |
|------|--------|
| `pkgs/nixos-scripts/default.nix` | MODIFY (replace installPhase with loop, distribute lib/) |

### Exact Change

Replace the entire `installPhase` and `meta` block:

**Before:**
```nix
  installPhase = ''
    mkdir -p $out/bin

    # Install worktree workflow script
    cp $src/code-work $out/bin/
    chmod +x $out/bin/code-work

    # Install utility scripts
    cp $src/format-nix $out/bin/
    chmod +x $out/bin/format-nix

    cp $src/nixos-build $out/bin/
    chmod +x $out/bin/nixos-build

    cp $src/export-mate-config $out/bin/
    chmod +x $out/bin/export-mate-config
  '';

  meta = with lib; {
    description = "Git worktree management scripts for NixOS development";
    license = licenses.mit;
  };
```

**After:**
```nix
  installPhase = ''
    mkdir -p $out/bin

    # Install all scripts from bin/
    for script in \
      add-wireguard-peer \
      code-work \
      compare-palette \
      export-mate-config \
      format-nix \
      generate-thinkpad-wireguard \
      nixos-build \
      remove-wireguard-peer \
      sops-rotate-keys \
      sync-opencode-remote \
      webcam \
    ; do
      if [[ -f "$src/$script" ]]; then
        cp "$src/$script" "$out/bin/"
        chmod +x "$out/bin/$script"
      fi
    done

    # Distribute shared library alongside scripts
    # Scripts source it via: source "$(dirname "$0")/lib/common.sh"
    mkdir -p "$out/bin/lib"
    cp "$src/lib/common.sh" "$out/bin/lib/"
  '';

  meta = with lib; {
    description = "NixOS development and system management scripts";
    license = licenses.mit;
  };
```

### Notes

- `sops-add-t14` is intentionally excluded (it is deleted in Task 4)
- `lib/common.sh` is copied to `$out/bin/lib/` so the relative source path `$(dirname "$0")/lib/common.sh` works from installed scripts in the nix store
- The `if [[ -f "$src/$script" ]]` guard is defensive — prevents build failure if a script is renamed

### Verification

```bash
# Nix syntax check
nix flake check --no-build
# Note: pre-existing unrelated failures expected (unrelated flake input error)

# Build the derivation (linux)
nix build '.#packages.x86_64-linux.nixos-scripts' 2>&1 || \
nix build '.#nixos-scripts' 2>&1 || true

# List installed scripts
ls -la result/bin/ 2>/dev/null
# Expected: 11 scripts + lib/ subdirectory

# Verify lib/common.sh is present
ls result/bin/lib/common.sh 2>/dev/null
```

If `nix build` fails due to pre-existing flake check errors, verify the derivation syntax manually:

```bash
# Verify the nix expression is syntactically valid
nix-instantiate --eval --strict pkgs/nixos-scripts/default.nix 2>&1 || true
```

### Checklist

- [ ] Script list in loop includes all 11 intended scripts
- [ ] `sops-add-t14` NOT in the list
- [ ] `lib/common.sh` copied to `$out/bin/lib/`
- [ ] Description updated from "Git worktree management..." to "NixOS development..."
- [ ] `nix flake check --no-build` passes (or only pre-existing failures)

---

## Task 4: Merge sops-add-t14 into sops-rotate-keys

**Scope**: Add `add-host <name>` subcommand to `sops-rotate-keys`. Delete `bin/sops-add-t14`.

### Rationale

`sops-add-t14` is an 8-line script that hardcodes host "t14" and updates `secrets/user/opencode.yaml`. Its functionality logically belongs in `sops-rotate-keys` as a general `add-host <name>` subcommand that works for any host.

### Files to Modify

| File | Action |
|------|--------|
| `bin/sops-rotate-keys` | MODIFY (add add_host function, dispatch case, update help) |
| `bin/sops-add-t14` | DELETE |

### Changes to `bin/sops-rotate-keys`

#### 1. Add `add_host()` function

Add BEFORE the `case` dispatch block (before line 128, after `show_recovery()` function):

```bash
add_host() {
  local host_name="${1:-}"
  local target_file="${TARGET_FILE:-secrets/user/opencode.yaml}"

  if [[ -z "$host_name" ]]; then
    echo "Error: Host name required" >&2
    echo "Usage: $0 add-host <hostname>" >&2
    exit 2
  fi

  echo "> Adding host '$host_name' to sops keys..."

  # Pull latest changes
  echo "> Pulling latest changes..."
  git pull

  # Update keys in the target file
  echo "> Running sops updatekeys on $target_file ..."
  sops updatekeys "$target_file"

  # Stage and commit
  git add "$target_file"
  git commit -m "Add host_${host_name} to user secrets"
  git push

  echo "> Host '$host_name' added to $target_file and pushed."
}
```

#### 2. Add `add-host` case to dispatch

Add AFTER `recover)` case (after line 144, before `help|--help|-h)`):

```bash
  add-host)
    shift
    add_host "$@"
    ;;
```

#### 3. Update `show_help()` function

Add after line 23 (`echo "  recover   Show recovery instructions if you lost your keys"`):

```bash
  echo "  add-host  Add a new host to sops secrets"
  echo "            Usage: $0 add-host <hostname>"
```

#### 4. Delete `bin/sops-add-t14`

```bash
git rm bin/sops-add-t14
```

### Verification

```bash
# Syntax check
bash -n bin/sops-rotate-keys

# Help shows new subcommand
bin/sops-rotate-keys help 2>&1 | grep -q "add-host" && echo "PASS: add-host in help"

# Add-host with no args should fail gracefully
bin/sops-rotate-keys add-host 2>&1 | grep -q "Host name required" && echo "PASS: validates args"

# Old script no longer exists
test ! -f bin/sops-add-t14 && echo "PASS: sops-add-t14 deleted"
```

### Checklist

- [ ] `add_host()` function added to `bin/sops-rotate-keys`
- [ ] `add-host) case` added to dispatch
- [ ] `show_help()` lists `add-host` subcommand
- [ ] `bin/sops-add-t14` deleted
- [ ] `bash -n bin/sops-rotate-keys` passes
- [ ] `git diff --stat` shows expected changes (+~25, -~8)
- [ ] `nix flake check --no-build` passes (or only pre-existing failures)
