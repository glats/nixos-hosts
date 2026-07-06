# SDD Design: revisar-scripts-bin-nix-switch-mact2

## Technical Approach

Four independent capabilities, delivered as atomic commits. Each commit produces a working, verifiable state. No capability depends on another for correctness, though adopting the shared preamble library is a "nice to have" that other scripts can adopt gradually.

---

## Capability 1: HM-SINGLE-ACTIVATION

### Problem Statement

`bin/nixos-build` executed on mact2 (Darwin) runs `home-manager switch` AFTER `darwin-rebuild switch`, despite nix-darwin already deploying Home Manager as an integrated module. This causes:

1. **Redundant activation**: The same HM generation is activated twice
2. **Wasted time**: `home-manager switch` re-evaluates and re-activates user config unnecessarily
3. **Theoretical conflict**: The standalone `home-manager` command might reference a different flake or evaluation context

### Root Cause

`darwin/default.nix` line 11 imports `inputs.home-manager.darwinModules.home-manager`, making HM a first-class nix-darwin module. The `home-manager.users.${primaryUser}` block (lines 43-66) imports `../home-darwin`, deploying all HM modules. When `sudo darwin-rebuild switch` runs, it evaluates the full system closure INCLUDING the HM module. The activation script handles both system-level and user-level activation in a single pass.

### Architecture Decision

**Remove the 3 redundant `home-manager switch` calls from `nixos-build` when running on Darwin.** The `darwin_build switch` (which runs `sudo darwin-rebuild switch --flake "$FLAKE_PATH#$HOSTNAME"`) already handles HM activation.

### Before / After

#### `switch` command (lines 125-141)

**Before:**
```bash
  switch)
    echo ""
    if $IS_DARWIN; then
      echo "> Building Darwin configuration (switch)..."
      darwin_build switch
      echo ""
      echo "> Switching home-manager..."
      home-manager switch --flake "$FLAKE_PATH#$HOSTNAME"
    else
      echo "> Building NixOS configuration (switch)..."
      if [[ "$USE_NH" == "true" ]]; then
        nh os switch
      else
        run_with_nom sudo nixos-rebuild switch --flake "$FLAKE_PATH#$HOSTNAME"
      fi
    fi
    ;;
```

**After:**
```bash
  switch)
    echo ""
    if $IS_DARWIN; then
      echo "> Building Darwin configuration (switch)..."
      darwin_build switch
    else
      echo "> Building NixOS configuration (switch)..."
      if [[ "$USE_NH" == "true" ]]; then
        nh os switch
      else
        run_with_nom sudo nixos-rebuild switch --flake "$FLAKE_PATH#$HOSTNAME"
      fi
    fi
    ;;
```

#### `upgrade` command (lines 171-196)

**Before:**
```bash
  upgrade)
    echo ""
    update_npm_packages
    echo ""
    if $IS_DARWIN; then
      echo "> Updating flake inputs..."
      nix flake update --flake "$FLAKE_PATH"
      echo ""
      echo "> Building Darwin configuration (upgrade)..."
      darwin_build switch
      echo ""
      echo "> Switching home-manager..."
      home-manager switch --flake "$FLAKE_PATH#$HOSTNAME"
    else
      ...
    fi
    ;;
```

**After:**
```bash
  upgrade)
    echo ""
    update_npm_packages
    echo ""
    if $IS_DARWIN; then
      echo "> Updating flake inputs..."
      nix flake update --flake "$FLAKE_PATH"
      echo ""
      echo "> Building Darwin configuration (upgrade)..."
      darwin_build switch
    else
      ...
    fi
    ;;
```

#### `safe` command (lines 293-303)

**Before:**
```bash
    echo "> [4/4] Switching..."
    if $IS_DARWIN; then
      if ! darwin_build switch; then
        echo ""
        echo "> ERROR: Switch failed. Stopping."
        exit 1
      fi
      echo ""
      echo "> Switching home-manager..."
      home-manager switch --flake "$FLAKE_PATH#$HOSTNAME"
    else
      ...
    fi
```

**After:**
```bash
    echo "> [4/4] Switching..."
    if $IS_DARWIN; then
      if ! darwin_build switch; then
        echo ""
        echo "> ERROR: Switch failed. Stopping."
        exit 1
      fi
    else
      ...
    fi
```

### Files Changed

| File | Change |
|------|--------|
| `bin/nixos-build` | Remove lines 130-132 (`switch`), 181-183 (`upgrade`), 300-302 (`safe`) -- 9 lines removed |

### Verification

1. `nix flake check --no-build` passes
2. On mact2, `nixos-build switch` output shows only `> Building Darwin configuration (switch)...` -- no `> Switching home-manager...`
3. On Linux hosts (rog, thinkcentre, t14), behavior is unchanged
4. On mact2, after `nixos-build switch`, verify HM is active: `home-manager generations` shows the same generation that `darwin-rebuild` activated

### Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| HM config diverges because darwin-rebuild and standalone home-manager reference different flakes | LOW | Both use `$FLAKE_PATH#$HOSTNAME`. Verified in explore phase: the flake path is identical. |
| mact2 HM activation silently fails after removal | LOW | nix-darwin with `inputs.home-manager.darwinModules.home-manager` has been the standard integration since HM introduced darwinModules. If HM fails, darwin-rebuild itself would report errors. |

---

## Capability 2: ALL-SCRIPTS-PACKAGED

### Problem Statement

Only 4 of 12 `bin/` scripts are packaged in `pkgs/nixos-scripts/default.nix`. The remaining scripts are accessible only via `PATH="$HOME/.nixos/bin:$PATH"` (set in `home-linux/shell.nix:61`). On mact2, the unpackaged scripts may not be available at all if the repo isn't cloned.

### Architecture Decision

**Add all remaining scripts to the `pkgs/nixos-scripts` derivation.** After Capability 4 (SINGLE-KEY-TOOL) removes `sops-add-t14`, the remaining unpackaged scripts are 7. `bin/lib/common.sh` (created in Capability 3) is NOT installed as a standalone binary -- it is sourced by other scripts and does not need executable permissions.

### Nix Expression Changes

**Before (`pkgs/nixos-scripts/default.nix`):**
```nix
{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "nixos-scripts";
  version = "0.1.0";

  src = ../../bin;

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
}
```

**After (`pkgs/nixos-scripts/default.nix`):**
```nix
{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "nixos-scripts";
  version = "0.1.0";

  src = ../../bin;

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
  '';

  meta = with lib; {
    description = "NixOS development and system management scripts";
    license = licenses.mit;
  };
}
```

### Design Decisions

1. **Loop-based install** instead of individual `cp` lines: Reduces boilerplate and makes the list of scripts self-documenting. Adding a new script in the future only requires adding its name to the for-loop list.

2. **`sops-add-t14` NOT included**: This script is removed in Capability 4 (SINGLE-KEY-TOOL), its functionality merged into `sops-rotate-keys`. If Capability 4 is not delivered, add `sops-add-t14` to the list.

3. **`lib/common.sh` NOT installed**: This is a sourced library, not an executable. It does not belong in `$out/bin/`. Scripts that source it resolve its path relative to themselves (`$(dirname "$0")/lib/common.sh`), which works correctly because `nixos-scripts` flattens all scripts into `$out/bin/`. The library file must be distributed alongside the scripts so they can source it.

4. **Guard with `-f` check**: The conditional `if [[ -f "$src/$script" ]]` prevents build failure if a script is renamed or removed but the derivation isn't updated. This is defensive but not mandatory since the source is the local `bin/` directory.

### Files Changed

| File | Change |
|------|--------|
| `pkgs/nixos-scripts/default.nix` | Replace `installPhase` with loop-based install, add 7 scripts, update description |

### Verification

1. `nix flake check --no-build` passes
2. `nix build .#packages.x86_64-linux.nixos-scripts` succeeds
3. `ls result/bin/` shows 11 scripts (4 existing + 7 new, but see note about `lib/` below)
4. The warning about `sops-rotate-keys` references to `REPO_DIR` still working (the script uses relative paths, which resolve correctly after derivation copys them to `$out/bin/`)

### Distribution of `lib/common.sh`

Since `src = ../../bin`, the `lib/` subdirectory IS included in the source. However, the derivation flattens scripts into `$out/bin/`, losing the directory structure. Scripts that `source "$(dirname "$0")/lib/common.sh"` need the library at `$out/bin/lib/common.sh`.

**Option A**: Copy the library into `$out/bin/lib/` during `installPhase`:
```bash
mkdir -p $out/bin/lib
cp $src/lib/common.sh $out/bin/lib/
```

**Option B**: Inline the library content into each script during the build (using `substituteInPlace` or similar). This removes the runtime dependency on a relative path.

**Recommended: Option A** -- simpler, preserves a single source of truth, and costs a few extra bytes in the closure.

---

## Capability 3: SHARED-PREAMBLE

### Problem Statement

Three WireGuard scripts (`add-wireguard-peer`, `remove-wireguard-peer`, `generate-thinkpad-wireguard`) share identical 8-line preambles (lines 1-8). This is duplicated code with zero divergence -- a maintenance hazard. If the REPO_ROOT detection pattern changes, all three must be updated.

### Architecture Decision

**Create `bin/lib/common.sh` with shared shell utilities.** Source it from WireGuard scripts. Optionally adopt it in other scripts gradually (not part of this change's scope).

### Shared Library Design

**`bin/lib/common.sh` (new file):**
```bash
#!/usr/bin/env bash
# common.sh - Shared shell utilities for NixOS scripts
# Source from other scripts: source "$(dirname "$0")/lib/common.sh"

# --- Repo root detection ---
# Priority: $NIXOS_REPO env var > git rev-parse > SCRIPT_DIR parent > ~/.nixos
_find_repo_root() {
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"

  if [[ -n "${NIXOS_REPO:-}" ]]; then
    echo "$NIXOS_REPO"
  elif git rev-parse --show-toplevel &>/dev/null; then
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

### WireGuard Script Changes

All three WireGuard scripts replace lines 1-8 with a single `source` line.

**`add-wireguard-peer` (before, lines 1-8):**
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

The `cd "$REPO_ROOT"` is kept because the scripts use it to run subsequent commands from the repo root. The `$REPO_ROOT` and `$HOST` variables are now defined by `common.sh`.

### Design Decisions

1. **`set -euo pipefail` stays in each script**: This is a per-script setting. Sourcing `common.sh` with `set -euo pipefail` could conflict with scripts that need different error handling. Each script keeps its own.

2. **REPO_ROOT uses `BASH_SOURCE[1]`**: This resolves to the sourcing script's path, not `common.sh`'s path. This ensures `REPO_ROOT` is always relative to the caller, not the library location.

3. **`die()` and `usage()` included**: These are used by multiple scripts. Including them in the shared library avoids redefining them.

4. **`common.sh` has a shebang**: Convention, not necessity for a sourced file. Helps editors detect shell syntax.

### Files Changed

| File | Change |
|------|--------|
| `bin/lib/common.sh` | NEW: shared shell library |
| `bin/add-wireguard-peer` | Replace preamble (lines 1-8) with `source` + `cd` |
| `bin/remove-wireguard-peer` | Replace preamble (lines 1-8) with `source` + `cd` |
| `bin/generate-thinkpad-wireguard` | Replace preamble (lines 1-8) with `source` + `cd` |

### Verification

1. `nix flake check --no-build` passes (no Nix changes in this commit if done before packaging)
2. Run `add-wireguard-peer test-peer` and verify it produces the expected output
3. Run `remove-wireguard-peer test-peer` and verify it reports the peer not found (correctly)
4. Verify `$REPO_ROOT` resolves to the correct repo path from any directory when running the scripts

---

## Capability 4: SINGLE-KEY-TOOL

### Problem Statement

`sops-add-t14` is an 8-line script that is specific to the `t14` host. It hardcodes the host name and the secret file path. It duplicates the "add a host to sops" workflow that logically belongs in `sops-rotate-keys`.

### Architecture Decision

**Add `add-host <name>` subcommand to `sops-rotate-keys`.** Generalize the host name and secret file path. Delete `sops-add-t14`. The new subcommand accepts a `--file` flag to specify which secret file to update (default: `secrets/user/opencode.yaml`).

### New Subcommand Design

The `add-host` subcommand in `sops-rotate-keys`:

```bash
add_host() {
  local host_name="${1:-}"
  local target_file="${TARGET_FILE:-secrets/user/opencode.yaml}"

  if [[ -z "$host_name" ]]; then
    echo "Error: Host name required" >&2
    echo "Usage: $0 add-host <hostname> [--file <path>]" >&2
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

### Dispatch Integration

In the `case` block at the end of `sops-rotate-keys` (around line 128), add:

```bash
  add-host)
    shift
    # Parse optional --file flag
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --file)
          TARGET_FILE="$2"
          shift 2
          ;;
        *)
          HOST_NAME="$1"
          shift
          ;;
      esac
    done
    add_host "$HOST_NAME"
    ;;
```

### Help Text Update

Add to `show_help()`:

```bash
  echo "  add-host  Add a new host to sops secrets"
  echo "            Usage: $0 add-host <hostname> [--file <path>]"
```

### Deletion Target

`bin/sops-add-t14` -- DELETED. Full contents for reference:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
git pull
sops updatekeys secrets/user/opencode.yaml
git add secrets/user/opencode.yaml
git commit -m "Add host_t14 to user secrets"
git push
```

### Migration

If any script, alias, or documentation references `sops-add-t14`, update to `sops-rotate-keys add-host t14`. Check:

- `shared/shell-aliases.nix`
- `AGENTS.md`
- Any host-specific config files

### Design Decisions

1. **`--file` flag** instead of positional argument: Future-proof. Different hosts might need to update different secret files (e.g., `secrets/secrets.yaml` vs `secrets/user/opencode.yaml`). Default preserves backward compatibility.

2. **Keep `add_host` as an internal function**: Matches the existing pattern of `regenerate_admin_key()`, `update_host_key()`, `show_recovery()`.

3. **Commit message uses `host_${host_name}`**: Generalizes the original `"Add host_t14 to user secrets"`.

### Files Changed

| File | Change |
|------|--------|
| `bin/sops-rotate-keys` | Add `add_host()` function, `add-host` case, update `show_help()` |
| `bin/sops-add-t14` | DELETE |

### Verification

1. `nix flake check --no-build` passes
2. `sops-rotate-keys add-host --help` shows usage
3. `sops-rotate-keys help` lists the new `add-host` subcommand

---

## Data Flow: nix-switch() Call Chain

To confirm the fix does not break any existing invocation path:

```
User types: nix-switch
  -> shared/shell-aliases.nix:53-55
     -> nixos-build "switch"
        -> bin/nixos-build: command "switch"
           -> [Darwin]: darwin_build switch (sudo darwin-rebuild switch --flake ...)
              -> nix-darwin evaluates system closure INCLUDING home-manager module
              -> activation script handles system + user activation in one pass
           -> [Linux]: nh os switch or nixos-rebuild switch --flake ...
              -> NixOS evaluates + activates system closure
                 -> HM activation is separate in NixOS (nixos-rebuild does NOT handle HM directly,
                    but the NixOS module for HM triggers activation during switch)

User types: nix-upgrade
  -> shared/shell-aliases.nix:57-59
     -> nixos-build upgrade
        -> bin/nixos-build: command "upgrade"
           -> Same dispatch as switch, but also runs update_npm_packages + nix flake update
```

Note: On **NixOS**, `home-manager switch` is NOT run by `nixos-build` either -- it relies on the HM NixOS module's activation hook. This is the existing behavior and is correct. The fix only removes the redundant Darwin HM activation.

---

## Testing Strategy

### Per-Capability Verification

| Capability | Validation Command | Expected Result |
|-----------|-------------------|-----------------|
| HM-SINGLE-ACTIVATION | `nix flake check --no-build` | Pass (syntax valid) |
| HM-SINGLE-ACTIVATION | On mact2: `nixos-build switch` | Only `darwin-rebuild switch` runs, no `home-manager switch` |
| ALL-SCRIPTS-PACKAGED | `nix flake check --no-build` | Pass |
| ALL-SCRIPTS-PACKAGED | `nix build .#packages.x86_64-linux.nixos-scripts && ls result/bin/` | 11 scripts listed |
| SHARED-PREAMBLE | `bash -n bin/lib/common.sh && bash -n bin/add-wireguard-peer` | No syntax errors |
| SHARED-PREAMBLE | Run `add-wireguard-peer test-peer` (dry) | Expected error about existing key (proves it runs) |
| SHARED-PREAMBLE | Run `generate-thinkpad-wireguard 127.0.0.1` (dry) | Expected sops decrypt error (proves library sourced correctly) |
| SINGLE-KEY-TOOL | `bash -n bin/sops-rotate-keys` | No syntax errors |
| SINGLE-KEY-TOOL | `sops-rotate-keys help` | Lists `add-host` subcommand |
| SINGLE-KEY-TOOL | `sops-rotate-keys add-host test-host` | Reports git error if not in clean repo (proves dispatch works) |

### Integration Test

After all changes:
```bash
nix flake check --no-build  # Must pass
```

---

## Commit Plan

| # | Commit | Files | Lines Changed |
|---|--------|-------|---------------|
| 1 | `fix(nixos-build): remove redundant HM activation on Darwin` | `bin/nixos-build` | -9 |
| 2 | `refactor(bin): extract shared shell library for WireGuard scripts` | `bin/lib/common.sh` (new), `bin/add-wireguard-peer`, `bin/remove-wireguard-peer`, `bin/generate-thinkpad-wireguard` | +35, -21 |
| 3 | `feat(pkgs): package all remaining bin/ scripts` | `pkgs/nixos-scripts/default.nix` | +15, -8 |
| 4 | `feat(sops): merge sops-add-t14 into sops-rotate-keys add-host` | `bin/sops-rotate-keys`, `bin/sops-add-t14` (delete) | +25, -8 |

### Commit Order Rationale

1. **Fix first**: The HM bug is the highest priority. It's a simple deletion with no dependencies and immediate user benefit.
2. **Library second**: The shared library is a prerequisite for packaging since scripts that source `lib/common.sh` must have it available. The library itself is self-contained.
3. **Package third**: After the library exists and WireGuard scripts are updated, packaging ensures all scripts are properly distributed.
4. **Merge last**: The sops scripts are independent. This goes last because it's the lowest priority.

---

## Hosts Affected

| Host | Impact |
|------|--------|
| **mact2** | HM-SINGLE-ACTIVATION: Behavior change -- no longer runs standalone `home-manager switch`. ALL-SCRIPTS-PACKAGED: Gains access to previously unpackaged scripts via `nixos-scripts` package (if they were only available via `~/.nixos/bin` PATH before). |
| **rog, thinkcentre, t14** | No behavioral change. ALL-SCRIPTS-PACKAGED: Scripts that were available via `~/.nixos/bin` PATH are now also available via the `nixos-scripts` package (redundant paths). No breakage. |
| **All** | SHARED-PREAMBLE: WireGuard scripts produce identical behavior. SINGLE-KEY-TOOL: `sops-rotate-keys add-host <name>` replaces `sops-add-t14`. |

---

## Open Questions

1. **Should `lib/common.sh` be distributed with `pkgs/nixos-scripts`?** If WireGuard scripts source it, the library must be present. Yes -- copy `$src/lib/common.sh` to `$out/bin/lib/` during installPhase. This adds ~20 lines. Decision: YES, do it in ALL-SCRIPTS-PACKAGED.

2. **Should other scripts adopt `lib/common.sh`?** `nixos-build`, `sops-rotate-keys`, `code-work`, `export-mate-config` all have their own REPO_ROOT detection and could benefit. This is OUT of scope for this change but should be considered as follow-up.

3. **Should `compare-palette` and `webcam` really be packaged?** They are dev tools with no system dependency. The proposal says YES, so they go in. But they are niche and could be argued as unnecessary in the package.

4. **Should `home-manager switch` remain available as a manual fallback on mact2?** Yes. The `home-manager` binary itself is not removed. Users can still run `home-manager switch --flake ...` manually if they need to activate HM independently. The fix only removes it from the automated `nixos-build` workflow.

---

## Architecture Decisions Summary

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Remove HM switch from Darwin code paths, not guard it with a flag | The redundant call has no valid use case. `darwin-rebuild switch` always handles HM when the module is imported. A flag adds complexity without benefit. |
| 2 | Loop-based install in `default.nix` | Reduces maintenance. Adding a new script is a one-line change to the for-list. |
| 3 | Shared library uses `BASH_SOURCE[1]` for REPO_ROOT | Resolves relative to the caller script, not the library. Works correctly when scripts and lib are both in `$out/bin/`. |
| 4 | `add-host` subcommand uses `--file` flag | Generalizes beyond t14 and beyond `opencode.yaml`. Future-proof for multi-host secret files. |
| 5 | Commit 2 (library) before Commit 3 (packaging) | The library must exist before WireGuard scripts (which source it) are packaged. Otherwise the built derivation would contain broken scripts. |
