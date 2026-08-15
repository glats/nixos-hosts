# Proposal: WireGuard client config export to ~/Documents

## Intent

- Let `glats` copy the 5 generated WireGuard client configs from the root-only `/etc/wireguard/clients/*.conf` into `~/Documents/wireguard/` on demand — without embedding secrets in the Nix store or exporting automatically.
- Host scope: **rog only** (module imported only by `hosts/rog/default.nix`).

## Scope

### In Scope
- New `bin/export-wireguard-configs` bash script (plain bash + coreutils only).
- Register script in `pkgs/nixos-scripts/default.nix` (already on PATH via `linux/home/shell.nix`).
- Copies every `/etc/wireguard/clients/<name>.conf` → `/home/glats/Documents/wireguard/<name>.conf`, owned `glats:users`, mode 600.
- Uses sudo internally to read the root-only source (matches repo pattern, e.g. `bin/generate-thinkpad-wireguard`).

### Out of Scope
- Changing `system.activationScripts.wireguard-client-configs` (no auto-export).
- Legacy stale `bin/{add,remove}-wireguard-peer`, `generate-thinkpad-wireguard` (pre-refactor paths).
- Pruning stale configs in `/etc/wireguard/clients/` itself.
- macOS/darwin hosts.

## Capabilities

### New Capabilities
- `wireguard-config-export`: on-demand export of server-generated client configs from `/etc/wireguard/clients/` into `~/Documents/wireguard/`, correct ownership/permissions, idempotent overwrite, stale-file pruning.

### Modified Capabilities
- None.

## Approach

- Standalone script, run manually (USER DECISION — not activation).
- `mkdir -p` destination; `install -o glats -g users -m 600` each source `.conf`.
- Sync destination to match source: prune destination `.conf` files absent from `/etc/wireguard/clients/` (no hardcoded peer list needed).
- No new packages; no new NixOS module options.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `bin/export-wireguard-configs` | New | On-demand export script |
| `pkgs/nixos-scripts/default.nix` | Modified | Register script in `$out/bin` |
| `linux/system/services/network/wireguard.nix` | Unchanged | Source of `/etc/wireguard/clients/*.conf` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Stale exports (script is manual) | Med | Always overwrite from authoritative `/etc`; prune destination files absent from source |
| Hardcoded `glats:users` | Low | Matches existing repo convention (droppy/arr-stack) |
| sudo read of 600 root files | Low | Matches existing `generate-thinkpad-wireguard` pattern |

## Rollback Plan

- Remove `bin/export-wireguard-configs` and its `cp`/`chmod` block in `pkgs/nixos-scripts/default.nix`; `format-nix && nix flake check --no-build`. Script mutates no system state; delete exports with `rm -rf ~/Documents/wireguard`.

## Dependencies

- `pkgs.nixos-scripts` already on PATH (`linux/home/shell.nix`).

## Success Criteria

- [ ] Script copies all 5 `.conf` into `~/Documents/wireguard/`, mode 600, owner `glats:users`.
- [ ] Re-running is idempotent; removed peers' destination files are pruned.
- [ ] `format-nix` + `nix flake check --no-build` pass.
