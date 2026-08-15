# wireguard-config-export Specification

## Purpose

On-demand export of server-generated WireGuard client configs from the root-only `/etc/wireguard/clients/` into `/home/glats/Documents/wireguard/`, with correct ownership/permissions, idempotent overwrite, and stale-file pruning. Applies to rog only.

## Requirements

### Requirement: On-demand export of client configs

The `export-wireguard-configs` script MUST copy every `/etc/wireguard/clients/<name>.conf` to `/home/glats/Documents/wireguard/<name>.conf`. Each exported file MUST be owned by `glats:users` and MUST have mode `600`. The script SHALL use `sudo` internally to read the root-only source directory.

#### Scenario: Happy path export [rog]

- GIVEN `rog` has 5 peer configs in `/etc/wireguard/clients/` (oneplus9, mac, thinkpad, samsung, thinkphone)
- WHEN `glats` runs `export-wireguard-configs`
- THEN all 5 `.conf` files MUST exist in `/home/glats/Documents/wireguard/`
- AND each MUST be owned `glats:users` with mode `600`

#### Scenario: Destination directory auto-created [rog]

- GIVEN `/home/glats/Documents/wireguard/` does not exist
- WHEN `glats` runs `export-wireguard-configs`
- THEN the directory MUST be created
- AND it MUST be populated with the exported `.conf` files

### Requirement: Idempotent overwrite

Re-running the script MUST overwrite existing destination files from the authoritative source and MUST NOT create duplicate or orphaned copies.

#### Scenario: Re-run overwrites without duplicates [rog]

- GIVEN a previous export already populated the destination
- WHEN `glats` runs `export-wireguard-configs` again
- THEN each `.conf` MUST be overwritten with source content
- AND the destination MUST contain exactly one `.conf` per source peer

### Requirement: Stale-file pruning

The script MUST remove destination `.conf` files that no longer have a corresponding source file in `/etc/wireguard/clients/`.

#### Scenario: Removed peer pruned [rog]

- GIVEN a peer's `.conf` was previously exported but no longer exists in `/etc/wireguard/clients/`
- WHEN `glats` runs `export-wireguard-configs`
- THEN that peer's destination `.conf` MUST be removed
- AND all current peers' `.conf` files MUST remain

### Requirement: Missing or empty source safety

The script MUST NOT crash and MUST NOT delete any destination file when the source directory is missing or contains no `.conf` files.

#### Scenario: Missing source directory [rog]

- GIVEN `/etc/wireguard/clients/` does not exist
- WHEN `glats` runs `export-wireguard-configs`
- THEN the script MUST exit non-zero with a clear error on stderr
- AND no destination `.conf` files MUST be deleted

#### Scenario: Empty source directory [rog]

- GIVEN `/etc/wireguard/clients/` exists but contains no `.conf` files
- WHEN `glats` runs `export-wireguard-configs`
- THEN the script MUST exit successfully
- AND existing destination `.conf` files MUST remain untouched

### Requirement: sudo failure handling

If `sudo` fails (missing password, non-interactive prompt, or insufficient permission), the script MUST exit non-zero and MUST print a clear error describing the failure.

#### Scenario: sudo unavailable [rog]

- GIVEN `sudo` cannot authenticate (e.g., non-interactive session without cached credentials)
- WHEN `glats` runs `export-wireguard-configs`
- THEN the script MUST exit non-zero
- AND MUST print a clear error explaining the sudo failure

### Requirement: Script registration

The script MUST be registered in `pkgs/nixos-scripts/default.nix` so `export-wireguard-configs` is available on PATH for `glats`.

#### Scenario: Script on PATH [rog]

- GIVEN the `nixos-scripts` package is built
- WHEN `nix flake check --no-build` runs
- THEN `export-wireguard-configs` MUST be present in the package's `$out/bin`
