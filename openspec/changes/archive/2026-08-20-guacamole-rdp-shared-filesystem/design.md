# Design: Guacamole RDP Shared Filesystem (Drive Redirection)

## Technical Approach

Enable Guacamole file transfer (RDP drive redirection) by giving the `guacamoled` (guacd) container a writable, host-backed bind mount. Drive redirection is performed by guacd — not the webapp — so guacd needs a directory it can read/write. Two declarative Nix edits to `linux/system/services/network/guacamole.nix`:

1. Bind-mount `/srv/glats/guacamole/drive` → `/drive` inside `guacamoled`.
2. A `systemd.tmpfiles.rules` entry creating the dir owned by numeric UID/GID 1000 (guacd's container user).

Connection enablement is a one-time manual admin-UI step (stored in the postgres DB, outside Nix). No specs phase — config-only infra change (Capabilities None/None).

## Architecture Decisions

| Decision | Option | Tradeoff | Choice |
|---|---|---|---|
| Drive layout | A. single shared `/drive` | all connections share one dir; simplest | **A** (resolved) |
| Dir location | dedicated `/srv/glats/guacamole/drive` vs Samba share | Samba forces guacd (UID 1000) into a `force user=glats` tree + CIFS friction | dedicated dir |
| tmpfiles scope | declare in `guacamole.nix` vs host `default.nix` | module-local keeps the service self-contained; matches samba/gonic/ftp/romm | in module |
| Owner | numeric `1000 1000` vs named `glats glats` | `guacd` is not a host user (no named lookup); numeric is explicit and durable | numeric 1000 |
| tmpfiles args | `d` type, `-` age, `0750` | `d` creates dir; `-` = no cleanup (persistent files); 0750 world-closed | `d … 0750 1000 1000 -` |
| `drive-path` value | container-internal `/drive` vs host path | host path is not visible inside the container → silent failure | `/drive` |
| Ordering | none vs explicit `before` | tmpfiles-setup runs at sysinit; oci-containers start at multi-user → already ordered | none |

## Data Flow

```
browser ──websocket──▶ guacamole webapp (:9003→8080)
                           │ Guacamole protocol
                           ▼
                        guacd (guacamoled) ──RDP──▶ Windows session
                           │ read/write /drive (bind mount)
                           ▼
              /srv/glats/guacamole/drive (host, UID/GID 1000, 0750)
```

Upload: file streams browser → webapp → guacd → written to `/drive` → presented to RDP as an RDPDR virtual drive. Download reverses. Files land on host at `/srv/glats/guacamole/drive`.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `linux/system/services/network/guacamole.nix` | Modify | add `volumes` to `guacamoled`; add `systemd.tmpfiles.rules` |
| `hosts/rog/default.nix` | None | module already imported (line 83) |
| `linux/system/services/web/nginx.nix` | None | verified sufficient (buffering off, 3600s timeouts, `clientMaxBodySize=100g`) |
| `secrets/host/rog/guacamole.yaml` | None | no new secrets |

Exact edits:

```nix
# guacamoled container (guacd) — add:
volumes = [ "/srv/glats/guacamole/drive:/drive" ];

# module scope — add:
systemd.tmpfiles.rules = [
  "d /srv/glats/guacamole/drive 0750 1000 1000 -"
];
```

The tmpfiles rule goes at module scope (same pattern as `samba.nix:64`, `gonic.nix:27`, `ftp.nix:49`); `format-nix` keeps each rule on one line.

## Interfaces / Contracts

- **Module options**: NO new options. `guacamole.nix` stays a plain config module (`{ config, pkgs, ... }`) with no `options = {}` block. It only emits `systemd.tmpfiles.rules` and a `virtualisation.oci-containers.containers.guacamoled.volumes` entry. Import line 83 unchanged.
- **Migration**: no migration — no options added, removed, or changed, so no breaking-option migration path is needed.
- **Manual DB contract (outside Nix)**: per RDP connection in admin UI → Connection → Parameters:
  - `enable-drive` = `true`
  - `drive-path` = `/drive` (container-internal; NOT the host path)
  - `drive-name` (optional) — defaults to `Guacamole Filesystem`
  - `create-drive-path` (optional) — `true` only if using a per-connection leaf dir; not needed for the shared `/drive`

## Testing Strategy

| Layer | What | Approach |
|---|---|---|
| Config | module evaluates cleanly | `nix flake check --no-build`; `format-nix` |
| Dry run | no unintended diffs | `nixos-build dry` (rog) |
| Runtime | UID matches guacd | `docker exec guacamoled id -u` → `1000` |
| Runtime | dir writable | `docker exec guacamoled touch /drive/.wtest` then host `ls -l /srv/glats/guacamole/drive` |
| E2E | transfer works | UI enable-drive step → upload + download a file in one RDP session |

## Threat Matrix

`N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.` Static Nix config change; the tmpfiles rule and bind mount are declarative. No executable or network surface is added.

## Migration / Rollout

No migration. Rollout: `nixos-build` on rog (container recreates with the new bind mount), then the one-time UI step above (persists in `dbdata` across rebuilds). Rollback: remove the `volumes` line + tmpfiles rule, rebuild; `rmdir /srv/glats/guacamole/drive` (additive, safe). UI params are independent and harmless.

## Open Questions

None.
