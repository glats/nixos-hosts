# Exploration: Guacamole RDP shared filesystem (drive redirection)

## Current State

Guacamole runs on `rog` only, declared in `linux/system/services/network/guacamole.nix` (imported solely by
`hosts/rog/default.nix` line 83). Three `oci-containers`:

| Container | Image | Port | Volumes | Role |
|-----------|-------|------|---------|------|
| `guacamoledb` | `postgres:17-alpine` | — | `/srv/glats/guacamole/dbinit`, `/srv/glats/guacamole/dbdata` | connection DB |
| `guacamoled` | `guacamole/guacd` | — | **NONE** | protocol daemon (RDP/VNC/SSH) |
| `guacamole` | `guacamole/guacamole` | `9003:8080` | `/srv/glats/guacamole/config` (ro) | webapp |

- **The gap**: the `guacamoled` (guacd) container has **no `volumes` entry at all** (lines 277-289). Drive
  redirection requires a host directory bind-mounted into guacd, because guacd — not the webapp — reads/writes
  the virtual drive files.
- Connections are managed via the **postgres-backed admin UI** (`guacadmin`, password set by the
  `guacamole-admin-setup` systemd one-shot). Connection parameters therefore live in the DB
  (`guacamole_connection` / `guacamole_connection_parameter`), **not** in Nix.
- Data-dir convention already established: everything under `/srv/glats/guacamole/` (`dbdata`, `dbinit`, `config`).
  Suggested new dir: `/srv/glats/guacamole/drive`.
- nginx (`guac.glats.org` → `127.0.0.1:9003/guacamole/`, nginx.nix lines 338-357) already has
  `proxy_buffering off`, `proxy_read_timeout 3600s`, `proxy_send_timeout 3600s`, `proxyWebsockets = true`, and a
  **global** `clientMaxBodySize = "100g"` (line 168). File transfer runs over the Guacamole websocket tunnel, so
  these settings are already sufficient — **no nginx change needed**.
- Secrets: `secrets/host/rog/guacamole.yaml` (encrypted) holds `guacamole/env` + `guacamole/admin_password`.
  Read-only; no new secrets required for this change.

## Affected Areas

- `linux/system/services/network/guacamole.nix` — add a `volumes` entry to the `guacamoled` container and a
  `systemd.tmpfiles.rules` entry to create the drive dir with correct ownership. (The only Nix code change.)
- `hosts/rog/default.nix` — no change (module already imported). Optionally add a `docker-guacamoled` timeout
  override only if needed.
- `linux/system/services/web/nginx.nix` — **no change** (verified sufficient).
- `secrets/host/rog/guacamole.yaml` — **no change** (no new secrets).
- Admin UI (postgres DB, not Nix) — per-connection parameters set once by hand via `guacadmin`.

## Verified research (MCP: context7, exa, github — cited)

1. **Connection parameters** (per-connection, stored in DB, set in admin UI → Connection → Parameters/Devices):
   - `enable-drive` = `true` — enables drive redirection (file transfer).
   - `drive-name` — label of the virtual drive as seen in Windows (default `Guacamole Filesystem`).
   - `drive-path` — **the directory on the Guacamole server (guacd's filesystem), NOT a path on the RDP server**.
     "Must be accessible by guacd and both readable and writable by the user that runs guacd."
   - `create-drive-path` = `true` — auto-create only the **final** directory; parent dirs must already exist.
   - `disable-download` / `disable-upload` — optional per-direction control.
   Source: https://guacamole.apache.org/doc/gug/configuring-guacamole.html (device redirection / file transfer);
   confirmed in guacamole-server `src/protocols/rdp/settings.c` (`GUAC_RDP_CLIENT_ARGS`).
2. **guacd image user**: `guacamole/guacd` runs as a **non-root `guacd` user, UID 1000 / GID 1000**
   (`ARG UID=1000`, `ARG GID=1000`, `USER guacd` in the Dockerfile). Switched from root → guacd in **1.3.0**
   (GUACAMOLE-1609: drive redirection broke when guacd could no longer create dirs under `/`). Source:
   https://github.com/apache/guacamole-server/blob/main/Dockerfile lines 335-341;
   https://issues.apache.org/jira/browse/GUACAMOLE-1609. → The host dir must be writable by numeric UID 1000.
3. **Official docker pattern**: guacd gets `./drive:/drive:rw` (and optionally `./record:/record:rw` for
   recordings); `drive-path` in the UI is then set to a path **inside** the container (e.g. `/drive`).
   Source: https://guacamole.apache.org/doc/gug/guacamole-docker.html and community compose examples
   (boschkundendienst/guacamole-docker-compose, smanceau44/guacamole-docker-compose).
4. **Webapp side**: file-transfer UI is **built into the webapp since 1.0** — no extension needed. Current image
   is 1.5.x (latest 1.6.0). Files uploaded in the browser are streamed over the Guacamole protocol to guacd,
   which stores them in `drive-path` and presents them to the RDP session as an RDPDR virtual drive (a network
   drive in Windows).
5. **RDP target (Windows)**: drive redirection is client-driven; normally nothing to configure on Windows. NOTE
   only: Group Policy "Do not allow drive redirection" (fDisableDrives) or restrictive RD Session Host settings
   can block it.

## Approaches

| Approach | Pros | Cons | Effort |
|----------|------|------|--------|
| **A. Single shared host dir** — mount `/srv/glats/guacamole/drive` → `/drive` in `guacamoled`, `chown`/tmpfiles to UID 1000, set `drive-path=/drive` (or `/drive/<name>`) in the UI | Minimal (1 volume + 1 tmpfiles line); matches official docker pattern; simple | All connections share one dir unless per-connection subpaths are used; relies on UID 1000 == glats host UID | Low |
| **B. Per-connection subdirs** — same as A but `drive-path=/drive/<conn>` with `create-drive-path=true` | Isolation per connection; still minimal | Only creates the leaf dir; parent `/drive` must exist + be writable; more UI setup per connection | Low |
| **C. SMB share as drive** — point the bind mount (or a CIFS mount into guacd) at the existing Samba public share `/run/media/stuff/samba` | Transferred files land directly in the existing public share (visible to other machines) | CIFS-in-container needs `cifs-utils`/`CAP_SYS_ADMIN`/credentials (fragile); or bind-mounting the samba dir forces guacd (UID 1000) to write into a `glats`-owned tree with `force user=glats`/`create mask 0664` — permission friction; higher ops risk | High |

## Recommendation

**Option A (with per-connection subpaths as an optional refinement).**

Nix change (guacamole.nix):
- Add to `guacamoled` container: `volumes = [ "/srv/glats/guacamole/drive:/drive" ];`
- Add `systemd.tmpfiles.rules = [ "d /srv/glats/guacamole/drive 0750 1000 1000 -" ];` (numeric 1000 == guacd
  UID/GID; coincides with glats' default NixOS UID 1000, verified glats is the first normal user).

Manual (DB, via admin UI — cannot be done in Nix, document in tasks/proposal):
- Per RDP connection: set `enable-drive=true`, `drive-path=/drive` (or `/drive/<name>`), optional
  `drive-name`, and `create-drive-path=true` only if using a per-connection leaf dir.

Document exact fields because they persist in postgres, not the Nix store — a rebuild alone will NOT configure
the drive; the UI step is mandatory and one-time (survives rebuilds since dbdata persists).

## Risks

- **UID mapping**: guacd is UID 1000 inside the container; bind mounts preserve numeric IDs. If the host
  `glats` user is not UID 1000, the tmpfiles rule must use a UID the guacd user can write (1000) — verify with
  `docker exec guacamoled id -u` at apply time. The dir is world-*un*writable (0750), so a wrong owner = silent
  `Permission denied` on transfer.
- **drive-path is container-internal**: setting the UI `drive-path` to a host path (e.g. `/srv/glats/...`) will
  fail — it must be the in-container mount (`/drive`).
- **create-drive-path scope**: only creates the final directory; parent `/drive` must pre-exist and be writable.
- **Container restart / image pull**: volume is a bind mount, so it survives recreation; but if the image
  ever bumps the guacd UID again, ownership breaks (low likelihood; verify after upgrades).
- **No host firewall**: `networking.firewall.enable = false`; the drive is not exposed over any new port, so no
  new exposure — but this is a server-hosted shared dir, so anyone with an RDP connection + drive enabled can
  read/write it. Keep the dir scoped (0750) and per-connection subpaths if multi-user later.

## Ready for Proposal

**Yes.** Scope is small (one Nix file + one documented UI step), approach is well-verified against official docs,
and no nginx/secrets/firewall changes are needed. The proposal MUST make the admin-UI step explicit (it is
outside Nix) and include the rollback plan (remove the `volumes` line; the drive dir is additive).
