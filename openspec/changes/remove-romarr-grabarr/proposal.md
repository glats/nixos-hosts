# Proposal: Remove Romarr + Grabarr

## Intent

Romarr (ROM acquisition manager) and Grabarr (ROM Torznab bridge) are unused services that add complexity, maintenance surface, and secret management overhead without delivering value. Remove both completely while preserving all other media services.

## Scope

### In Scope
- Remove romarr container + systemd services from `linux/system/services/media/romarr.nix`
- Delete `linux/system/services/media/romarr.nix` (53 lines)
- Remove grabarr container from `linux/system/services/media/grabarr.nix`
- Delete `linux/system/services/media/grabarr.nix` (38 lines)
- Remove both imports from `hosts/rog/default.nix` (lines 63, 65)
- Remove romarr nginx vhost (`romarr.glats.org`) from `linux/system/services/web/nginx.nix` (lines 491-494)
- Remove grabarr nginx vhost (`grabarr.glats.org`) from `linux/system/services/web/nginx.nix` (lines 501-504)
- Remove romarr secret declaration from `hosts/rog/secrets.nix` (lines 66-69)
- Remove encrypted secret file `secrets/host/rog/romarr.yaml`

### Out of Scope
- RomM + MariaDB (romm.nix, romm-db) — untouched
- RomM nginx vhost (`roms.glats.org`) — untouched
- qBittorrent, Prowlarr, arr-stack — untouched
- All other services (jellyfin, nginx, authelia, wireguard, etc.) — untouched
- RomM download mount (`/run/media/library:/romm/library:ro`) — untouched
- Data cleanup on disk (`/srv/glats/romarr/`, `/srv/glats/grabarr/`) — manual step, not in this change

## Capabilities

### New Capabilities
None.

### Modified Capabilities
None. Pure removal — no spec-level behavior changes.

## Approach

Four files modified, two files deleted:

| File | Action | Lines |
|------|--------|-------|
| `hosts/rog/default.nix` | Remove 2 import lines | L63, L65 |
| `linux/system/services/web/nginx.nix` | Remove 2 vhost blocks | L491-494, L501-504 |
| `hosts/rog/secrets.nix` | Remove romarr secret | L66-69 |
| `linux/system/services/media/romarr.nix` | Delete file | Entire (53) |
| `linux/system/services/media/grabarr.nix` | Delete file | Entire (38) |
| `secrets/host/rog/romarr.yaml` | Delete file | Entire |

No other files reference romarr or grabarr. All references are contained to these six files.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `hosts/rog/default.nix` | Modified | Remove 2 service imports |
| `linux/system/services/web/nginx.nix` | Modified | Remove 2 vhost blocks |
| `hosts/rog/secrets.nix` | Modified | Remove sops secret declaration |
| `linux/system/services/media/romarr.nix` | Removed | Full file deletion |
| `linux/system/services/media/grabarr.nix` | Removed | Full file deletion |
| `secrets/host/rog/romarr.yaml` | Removed | Encrypted secret cleanup |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| RomM depends on romarr mounts/volumes | Low | RomM uses `/run/media/library:/romm/library:ro` — no shared volumes with romarr |
| Other services reference removed vhosts | Low | Grep confirmed only nginx.nix references these vhosts |
| Secrets file has side effects | Low | Only romarr references `romarr.yaml`; RomM secrets use `romm.yaml` (separate) |

## Rollback Plan

Revert the commit. All removals are pure deletions — `git revert` restores everything instantly. No data migration needed since disk directories are preserved manually.

## Dependencies

None. No service depends on romarr or grabarr. They are leaf nodes in the service graph.

## Success Criteria

- [ ] `nix flake check --no-build` passes on rog
- [ ] No romarr or grabarr references remain in any `.nix` file
- [ ] RomM vhost (`roms.glats.org`) still present in nginx.nix
- [ ] RomM module still imported in `hosts/rog/default.nix`
- [ ] All arr-stack, qbittorrent, jellyfin services unaffected
