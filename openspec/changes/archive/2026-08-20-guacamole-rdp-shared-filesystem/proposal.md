# Proposal: Guacamole RDP Shared Filesystem (Drive Redirection)

## Intent

Enable file transfer between local clients and RDP sessions by giving the guacd container a writable, host-backed directory. Today `guacamoled` (guacd) has **no volumes**, so drive redirection — performed by guacd, not the webapp — silently fails.

## Scope

### In Scope
- Bind-mount `/srv/glats/guacamole/drive` → `/drive` in the `guacamoled` container.
- `systemd.tmpfiles.rules` entry creating the dir owned by UID/GID **1000** (guacd's user).
- Documented one-time admin-UI step (postgres DB) enabling `enable-drive=true` per RDP connection.

### Out of Scope
- Per-connection subdir isolation (`create-drive-path=true`) — optional refinement, not default.
- Samba/CIFS integration (Option C).
- nginx, secrets, firewall changes (verified unnecessary).
- Windows/GPO target-side configuration.

## Capabilities

> Contract between proposal and specs phases. Existing specs: `boot`, `hardware-nvidia` (unrelated).

### New Capabilities

None

### Modified Capabilities

None

Config-only infra change; no spec-level behavior deltas.

## Approach

Option A (exploration-recommended): single shared host dir.
- `guacamoled.volumes = [ "/srv/glats/guacamole/drive:/drive" ]`
- `systemd.tmpfiles.rules = [ "d /srv/glats/guacamole/drive 0750 1000 1000 -" ]`
- Manual UI (postgres, survives rebuilds): per RDP connection `enable-drive=true`, `drive-path=/drive`, optional `drive-name`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `linux/system/services/network/guacamole.nix` | Modified | Add volume + tmpfiles rule to `guacamoled` |
| Admin UI (postgres DB) | Manual | Per-connection drive params (outside Nix) |
| `hosts/rog/default.nix` | None | Already imports module (line 83) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| UID mismatch (guacd ≠ 1000) → permission denied | Low | Verify `docker exec guacamoled id -u`; tmpfiles uses numeric 1000 |
| UI `drive-path` set to host path | Med | Document container-internal `/drive` |
| Shared dir readable by any enabled connection | Low | 0750; per-connection subpaths if multi-user |

## Rollback Plan

1. Remove the `volumes` line from `guacamoled` and the tmpfiles rule.
2. `nixos-build` to redeploy.
3. Drive dir is additive — optionally `rmdir /srv/glats/guacamole/drive`.
4. No DB changes made by Nix; UI params are independent and harmless.

## Dependencies

None new. Existing sops secret (admin password) only for the UI step.

## Success Criteria

- [ ] `nix flake check --no-build` passes; `format-nix` clean.
- [ ] `guacamoled` mounts `/drive` writable by UID 1000.
- [ ] Admin-UI step documented; file transfer works in one RDP session.

## Proposal question round — RESOLVED (user confirmed)

1. Single shared `/drive` for all connections — CONFIRMED.
2. Dedicated dir (`/srv/glats/guacamole/drive`), NOT the Samba share — CONFIRMED.
3. Both directions (upload + download) enabled — CONFIRMED.
