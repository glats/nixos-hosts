# Delta Spec: bin-scripts-shared-lib — Shared Shell Preamble

## ADDED Requirements

### REQ-SHARED-1: A shared library file MUST exist at bin/lib/common.sh

A new file `bin/lib/common.sh` MUST be created containing shared shell utilities. This file MUST be sourceable from other scripts using `source "$(dirname "$0")/lib/common.sh"` (for scripts in `bin/`) or an equivalent relative path resolution.

**Scenario: common.sh is sourceable from sibling scripts**

- **Given** `bin/lib/common.sh` exists with shared utilities
- **When** a script in `bin/` executes `source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"`
- **Then** the source completes without error
- **And** shared variables/functions are available in the sourcing script's scope

### REQ-SHARED-2: REPO_ROOT detection MUST be robust and standardized

`bin/lib/common.sh` MUST define a `REPO_ROOT` variable using the following priority chain:

1. `$NIXOS_REPO` environment variable (user override)
2. `git rev-parse --show-toplevel` (git-aware detection, works from worktrees)
3. `$HOME/.nixos` (hard fallback)

This pattern MUST match the REPO_ROOT detection used in `bin/nixos-build` (lines 26-33).

**Scenario: REPO_ROOT from NIXOS_REPO env var**

- **Given** the user has set `NIXOS_REPO=/custom/path/to/nixos`
- **When** `common.sh` is sourced
- **Then** `REPO_ROOT` evaluates to `/custom/path/to/nixos`

**Scenario: REPO_ROOT from git rev-parse**

- **Given** `NIXOS_REPO` is not set
- **And** the current directory is inside a git worktree of the nixos repo
- **When** `common.sh` is sourced
- **Then** `REPO_ROOT` evaluates to the git toplevel directory

**Scenario: REPO_ROOT fallback to HOME**

- **Given** `NIXOS_REPO` is not set
- **And** `git rev-parse --show-toplevel` fails (not in a git repo)
- **When** `common.sh` is sourced
- **Then** `REPO_ROOT` evaluates to `$HOME/.nixos`

### REQ-SHARED-3: WireGuard scripts MUST source common.sh for preamble

The following scripts MUST replace their inline preamble (variables: `SCRIPT_DIR`, `REPO_ROOT`, `HOST`, and `cd "$REPO_ROOT"`) with a single `source` statement importing `bin/lib/common.sh`:

- `bin/add-wireguard-peer` (lines 1-8)
- `bin/remove-wireguard-peer` (lines 1-8)
- `bin/generate-thinkpad-wireguard` (lines 1-8)

**Scenario: add-wireguard-peer sources common.sh**

- **Given** `bin/lib/common.sh` exists with `SCRIPT_DIR`, `REPO_ROOT`, `HOST`, and `cd "$REPO_ROOT"` logic
- **When** `bin/add-wireguard-peer` is executed
- **Then** the script sources `common.sh` instead of having inline preamble lines
- **And** `SCRIPT_DIR`, `REPO_ROOT`, and `HOST` are set correctly
- **And** the working directory is `REPO_ROOT`

**Scenario: remove-wireguard-peer sources common.sh**

- **Given** `bin/lib/common.sh` exists
- **When** `bin/remove-wireguard-peer` is executed
- **Then** the script sources `common.sh` instead of having inline preamble lines
- **And** all variables resolve identically to pre-change behavior

**Scenario: generate-thinkpad-wireguard sources common.sh**

- **Given** `bin/lib/common.sh` exists
- **When** `bin/generate-thinkpad-wireguard` is executed
- **Then** the script sources `common.sh` instead of having inline preamble lines
- **And** all variables resolve identically to pre-change behavior

### REQ-SHARED-4: WireGuard scripts MUST produce identical behavior after refactoring

After replacing the inline preamble with `source bin/lib/common.sh`, the three WireGuard scripts MUST produce functionally identical output for the same inputs. No behavioral change is introduced.

**Scenario: add-wireguard-peer creates same PSK file**

- **Given** a valid peer name "test-peer" and no existing secret file
- **When** `bin/add-wireguard-peer test-peer` is executed after the refactoring
- **Then** `secrets/wireguard/peer-test-peer-psk` is created with mode 600
- **And** the file contains a valid WireGuard preshared key
- **And** the output messages match pre-change output

**Scenario: remove-wireguard-peer removes same peer**

- **Given** a peer "test-peer" exists with a secret file and entry in `modules/wireguard.nix`
- **When** `bin/remove-wireguard-peer test-peer` is executed after the refactoring
- **Then** the secret file is moved to `secrets/wireguard/.removed/`
- **And** the peer block is removed from `modules/wireguard.nix`
- **And** a backup file is created with timestamp

**Scenario: generate-thinkpad-wireguard produces same config**

- **Given** a valid server endpoint "vpn.example.com"
- **When** `bin/generate-thinkpad-wireguard vpn.example.com` is executed after the refactoring
- **Then** `thinkpad-wireguard.conf` is created with mode 600
- **And** the configuration contains correct Interface and Peer sections
- **And** the thinkpad public key is updated in `hosts/rog/services/wireguard.nix`

### REQ-SHARED-5: Source path MUST work from installed location

Scripts installed via the `nixos-scripts` derivation (in the nix store, e.g., `/nix/store/.../bin/`) MUST correctly resolve `common.sh` from their installed location. The relative source path `$(dirname "$0")/lib/common.sh` MUST work both from the repo's `bin/` directory and from `$out/bin/` in the nix store.

**Scenario: sourcing works from nix store path**

- **Given** `nixos-scripts` has been built and installed
- **And** a WireGuard script is invoked from `$PATH` (resolved to nix store)
- **When** the script executes `source "$(dirname "$0")/lib/common.sh"`
- **Then** the source succeeds (no "file not found" error)
- **And** all shared variables are available

**Implicit constraint**: `bin/lib/common.sh` MUST be present in the derivation's source (`src = ../../bin` includes the `lib/` subdirectory automatically since it copies the whole `bin/` tree). The `installPhase` MUST NOT need to explicitly copy `lib/common.sh` to `$out/bin` (it should remain under `$out/lib/` or be accessible relative to the scripts). If the derivation's `installPhase` only copies scripts individually from `$src` to `$out/bin`, then `lib/` MUST also be copied to maintain the relative path structure.
