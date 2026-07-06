# Delta Spec: nixos-scripts-packaging — All Scripts Packaged

## ADDED Requirements

### REQ-PACKAGING-1: All bin/ scripts MUST be included in the derivation

Every executable script in `bin/` that is NOT a shared library file (i.e., files NOT under `bin/lib/`) MUST be copied into the `nixos-scripts` derivation output. This includes both currently packaged scripts and currently unpackaged scripts.

The full list of scripts that MUST be in `$out/bin` after building:

1. `code-work` (already packaged)
2. `format-nix` (already packaged)
3. `nixos-build` (already packaged)
4. `export-mate-config` (already packaged)
5. `sync-opencode-remote` (NEW — currently unpackaged)
6. `sops-rotate-keys` (NEW — currently unpackaged)
7. `compare-palette` (NEW — currently unpackaged)
8. `generate-thinkpad-wireguard` (NEW — currently unpackaged)
9. `remove-wireguard-peer` (NEW — currently unpackaged)
10. `add-wireguard-peer` (NEW — currently unpackaged)
11. `webcam` (NEW — currently unpackaged)

`sops-add-t14` SHALL NOT be packaged (it is deleted per the SINGLE-KEY-TOOL capability).

**Scenario: nix build produces all expected scripts**

- **Given** the `pkgs/nixos-scripts/default.nix` has been updated
- **When** a nix build of `#nixos-scripts` completes successfully
- **Then** `ls $out/bin` shows exactly: `add-wireguard-peer`, `code-work`, `compare-palette`, `export-mate-config`, `format-nix`, `generate-thinkpad-wireguard`, `nixos-build`, `remove-wireguard-peer`, `sops-rotate-keys`, `sync-opencode-remote`, `webcam`
- **And** `sops-add-t14` is NOT present in `$out/bin`
- **And** no `lib/` directory exists under `$out/bin`
- **And** total script count in `$out/bin` is 11

### REQ-PACKAGING-2: Scripts MUST be installed with execute permissions

Every script copied to `$out/bin` in the `installPhase` MUST have its execute permission bit set via `chmod +x`.

**Scenario: all scripts are executable**

- **Given** the derivation has been built
- **When** checking permissions on each file in `$out/bin`
- **Then** every file has the execute bit set (`-rwxr-xr-x` or equivalent)
- **And** running `$out/bin/webcam --help` does not produce a permission error (even if the script itself exits with usage)

### REQ-PACKAGING-3: Shared library files MUST NOT be installed as executables

Files under `bin/lib/` (specifically `bin/lib/common.sh`) MUST NOT be copied to `$out/bin`. These are internal library files sourced by scripts at runtime and are not standalone executables.

**Scenario: lib/common.sh is not in output**

- **Given** `bin/lib/common.sh` exists as a helper library
- **When** the derivation is built
- **Then** `common.sh` does NOT appear in `$out/bin`
- **And** scripts that source `lib/common.sh` resolve it via relative path from their own location

### REQ-PACKAGING-4: Derivation source MUST remain correct

The `src` attribute of the derivation MUST still be `../../bin` (the `bin/` directory at the repo root). The source directory MUST include all scripts AND any new `lib/` subdirectories added as part of this change.

**Scenario: nix flake check passes after packaging update**

- **Given** all scripts have been added to the derivation `installPhase`
- **When** running `nix flake check --no-build` from the repo root
- **Then** the check exits with code 0
- **And** no evaluation errors are reported for the `nixos-scripts` derivation

**Scenario: scripts are available to hosts via home.packages**

- **Given** `nixos-scripts` is in `home.packages` via `home-linux/shell.nix` or `home-darwin/shell.nix`
- **When** a `nixos-build switch` or `darwin-rebuild switch` completes on any host
- **Then** all 11 scripts are available on `$PATH`
- **And** `which webcam`, `which sync-opencode-remote`, etc. resolve to the nix store path
