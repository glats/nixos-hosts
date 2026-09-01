# Authelia SSO - Service Access Exemption Analysis

## Architecture Context

All services bind to `127.0.0.1:PORT` (localhost only). Nginx reverse proxy handles external access.
Inter-service communication (ARR stack, qBittorrent, etc.) uses localhost:PORT directly -- never goes
through nginx. Therefore **adding Authelia SSO to nginx does NOT break internal API traffic**.

Only **external clients** (browser, mobile apps, third-party API consumers) are affected.

---

## Current Auth State

| Subdomain | Auth |
|-----------|------|
| auth.glats.org | Authelia portal |
| openfang.glats.org | **Authelia SSO** (with API exemptions) |
| All others | **No auth** (not protected) |

---

## Understanding exempt-location / nginx auth_request pattern

Authelia protects via `auth_request /internal/authelia/authz` on a `location /` block. To exempt a path,
you define **more specific location blocks BEFORE** the protected `/` block. Nginx processes
longest-prefix-match first, so specific paths match before `/`.

Pattern (from openfang):
```
# Exempt: no auth_request
location /api/ { proxy_pass ...; }
location /v1/  { proxy_pass ...; }
location /ws   { proxy_pass ...; }

# Protected: has auth_request
location / {
    auth_request /internal/authelia/authz;
    proxy_pass ...;
}
```

---

## Service-by-Service Analysis

### 1. tty.glats.org (Wetty) -- :9004

| Property | Value |
|----------|-------|
| Description | Browser-based SSH terminal using xterm.js |
| Has API? | No REST API. Pure WebSocket terminal. |
| WebSocket? | YES -- base path `/` upgraded to WebSocket |
| Mobile apps? | None |
| Integrations | None |
| **Exemption needed?** | **NO** -- full protection desired. Terminal should always require SSO. |
| Notes | Simple service. No API to exempt. All traffic is the terminal session. Fully protect. |

---

### 2. guac.glats.org (Guacamole) -- :9003

| Property | Value |
|----------|-------|
| Description | Browser-based remote desktop (RDP/VNC/SSH) via HTML5 |
| Has API? | YES -- REST API at `/api/` (connection management, session info, sharing) |
| WebSocket? | YES -- Guacamole protocol uses a WebSocket stream for remote desktop |
| Mobile apps? | Yes -- Guacamole mobile client uses REST API + WebSocket stream |
| Integrations | None (standalone) |
| **Exemption needed?** | **MAYBE** -- exempt `/api/` and the Guacamole WebSocket streaming endpoint if mobile clients need direct API access |
| Notes | Guacamole has its own auth layer. If mobile clients connect externally, they will fail with Authelia redirect. |
| | Recommendation: Protect fully (Guacamole has its own login on top). If mobile client issues, exempt `/api/` and the streaming endpoint. |

---

### 3. file.glats.org (FileShelter) -- :5091

| Property | Value |
|----------|-------|
| Description | Self-hosted file sharing with time-limited links |
| Has API? | No real REST API. Pure web forms for upload/download. |
| WebSocket? | No |
| Mobile apps? | None (uses browser) |
| Integrations | None |
| **Exemption needed?** | **NO** -- full protection desired |
| Notes | No API to exempt. Simple web app. Currently has basic auth (htpasswd). Replace with Authelia. |

---

### 4. qbit.glats.org (qBittorrent) -- :8080

| Property | Value |
|----------|-------|
| Description | BitTorrent client with Web UI |
| Has API? | YES -- `/api/v2/` (auth, app, torrents, sync, transfer, log, rss, search modules) |
| WebSocket? | NO -- uses polling for UI updates |
| Mobile apps? | Yes -- many third-party apps connect via `/api/v2/` (e.g., qBittorrent Remote, transmissions) |
| Integrations | **Sonarr/Radarr** download completed torrents via localhost:8080 (**NOT affected**) |
| **Exemption needed?** | **YES** -- exempt `/api/v2/` for mobile apps |
| Notes | ARR stack connects via localhost:8080 internally (never goes through nginx). No impact. |
| | But mobile apps connecting from external WAN WILL hit Authelia. Must exempt `/api/v2/`. |
| | API uses cookie-based auth after POST to `/api/v2/auth/login`. |
| | **Exempt path**: `/api/v2/` |

---

### 5. gonic.glats.org (Gonic) -- :4747

| Property | Value |
|----------|-------|
| Description | Music streaming server, Subsonic-compatible |
| Has API? | YES -- Subsonic API at `/rest/` (all methods: getArtists, getAlbum, stream, search2, search3, etc.) |
| WebSocket? | No |
| Mobile apps? | YES -- DSub, Ultrasonic, Substreamer, Symfonium, Sonixd connect via `/rest/` with `u`/`p` params |
| Integrations | Lidarr can connect internally. Not affected. |
| **Exemption needed?** | **YES** -- exempt `/rest/` for mobile music apps |
| Notes | Subsonic API uses URL params for auth (`?u=user&p=pass` or token auth). |
| | Mobile apps CANNOT handle Authelia redirect -- they expect XML/JSON responses. |
| | App MUST see `{"subsonic-response":...}` not HTML login page. |
| | **Exempt path**: `/rest/` |

---

### 6. radarr.glats.org (Radarr) -- :7878

| Property | Value |
|----------|-------|
| Description | Movie collection manager (automatic downloading + organization) |
| Has API? | YES -- `/api/v3/` (all CRUD: movie, calendar, command, history, release, indexer, etc.) |
| | Also: `/api` (API info), `/login`, `/logout`, `/feed/v3/calendar/radarr.ics` |
| WebSocket? | No (uses SignalR or polling for UI) |
| Mobile apps? | Yes -- Lumixarr, NZB360, third-party connect via `/api/v3/` with API key |
| Integrations | **Prowlarr** -- connects via localhost:7878 API key (internal, **NOT affected**) |
| | **Bazarr** -- connects via localhost:7878 API key (internal, **NOT affected**) |
| | **Overseerr/Jellyseerr** -- connects via localhost:7878 API key (internal, **NOT affected**) |
| **Exemption needed?** | **YES** -- exempt `/api/v3/` and `/api` for mobile apps/external monitoring |
| Notes | All inter-service ARR communication uses localhost:PORT directly. **No Authelia impact.** |
| | API authentication uses `X-Api-Key` header (not cookies). |
| | If using external tools (NZB360, etc.) that connect via the public domain, they need an exemption. |
| | **Exempt paths**: `/api/`, `/api/v3/` |

---

### 7. sonarr.glats.org (Sonarr) -- :8989

| Property | Value |
|----------|-------|
| Description | TV series collection manager (automatic downloading + organization) |
| Has API? | YES -- `/api/v3/` (all CRUD: series, episode, calendar, command, history, release, etc.) |
| | Also: `/api`, `/login`, `/logout`, `/feed/v3/calendar/sonarr.ics` |
| WebSocket? | No |
| Mobile apps? | Yes -- Lumixarr, NZB360, third-party connect via `/api/v3/` with API key |
| Integrations | **Prowlarr** -- connects via localhost:8989 (internal, **NOT affected**) |
| | **Bazarr** -- connects via localhost:8989 (internal, **NOT affected**) |
| | **Overseerr/Jellyseerr** -- connects via localhost:8989 (internal, **NOT affected**) |
| **Exemption needed?** | **YES** -- exempt `/api/v3/` and `/api` for mobile apps/external monitoring |
| Notes | Same as Radarr. All internal communication on localhost. |
| | **Exempt paths**: `/api/`, `/api/v3/` |

---

### 8. prowlarr.glats.org (Prowlarr) -- :9696

| Property | Value |
|----------|-------|
| Description | Indexer manager -- syncs trackers to Radarr/Sonarr/Lidarr |
| Has API? | YES -- `/api/v1/` (indexer, search, history, download client, notification, etc.) |
| | Also: `/api`, `/login`, `/content/{path}` |
| WebSocket? | No |
| Mobile apps? | No dedicated mobile apps. But NZB360 can connect. |
| Integrations | **Radarr** -- Prowlarr pushes indexers to Radarr via localhost:7878 (**NOT affected**) |
| | **Sonarr** -- Prowlarr pushes indexers to Sonarr via localhost:8989 (**NOT affected**) |
| | Connects to **external indexers** (torrent trackers, Usenet) directly -- **NOT affected** |
| **Exemption needed?** | **YES** -- exempt `/api/v1/` and `/api` |
| Notes | Prowlarr's external indexer connections are outbound (not going through nginx). No effect. |
| | Internal app sync is localhost. No effect. |
| | If third-party tools connect externally, they need an exemption. |
| | **Exempt paths**: `/api/`, `/api/v1/` |

---

### 9. bazarr.glats.org (Bazarr) -- :6767

| Property | Value |
|----------|-------|
| Description | Subtitle manager for Radarr/Sonarr -- downloads and syncs subtitles |
| Has API? | YES -- `/api/` (subtitles, episodes, movies, system, settings, etc.) |
| | Notable: `/api/system/ping` (unauthenticated health check) |
| WebSocket? | No |
| Mobile apps? | No |
| Integrations | **Radarr** -- connects via localhost:7878 (**NOT affected**) |
| | **Sonarr** -- connects via localhost:8989 (**NOT affected**) |
| **Exemption needed?** | **YES** -- exempt `/api/` |
| Notes | All internal communication on localhost. No effect. |
| | **Exempt paths**: `/api/` |

---

### 10. seerr.glats.org (Jellyseerr/Overseerr) -- :5055

| Property | Value |
|----------|-------|
| Description | Media request management -- users can request movies/TV from Radarr/Sonarr |
| Has API? | YES -- `/api/v1/` (or just paths under `/api/`) |
| | Public (no auth): `/status`, `/status/appdata` |
| | Auth-required: `/api/settings`, `/api/request`, `/api/search`, `/api/users`, `/api/media`, etc. |
| WebSocket? | No |
| Mobile apps? | Yes -- unofficial mobile apps (Overseerr mobile, etc.) connect via API |
| Integrations | **Jellyfin** -- connects for library sync via localhost:8096 (**NOT affected**) |
| | **Radarr** -- processes requests via localhost:7878 (**NOT affected**) |
| | **Sonarr** -- processes requests via localhost:8989 (**NOT affected**) |
| **Exemption needed?** | **YES** -- exempt `/api/` for mobile apps |
| Notes | Has own auth (local accounts or Jellyfin SSO). |
| | Public endpoints `/status` and `/status/appdata` don't need auth. |
| | Mobile apps can't handle Authelia redirect. |
| | **Exempt paths**: `/api/` |

---

### 11. jelly.glats.org (Jellyfin) -- :8096

| Property | Value |
|----------|-------|
| Description | Media streaming server (movies, TV, music, photos, live TV) |
| Has API? | YES -- comprehensive REST API at all paths: `/Users`, `/Items`, `/Sessions`, `/System`, `/library`, `/audio/{id}/stream`, `/videos/{id}/stream`, etc. |
| WebSocket? | YES -- `/socket` with `api_key` parameter for real-time events, playback reporting |
| Mobile apps? | YES -- **Android, iOS, Android TV, Apple TV, Roku, etc.** All connect via REST API |
| | Mobile apps use the same API paths as web UI (no separate mobile API) |
| | WebSocket at `/socket?api_key=TOKEN` for real-time features |
| Integrations | **Jellyseerr** -- connects for library sync via localhost:8096 (**NOT affected**) |
| **Exemption needed?** | **YES -- FULL EXEMPTION recommended** |
| Notes | **CRITICAL**: Jellyfin has extensive known issues behind Authelia: |
| | 1. Mobile apps (Android, iOS, TV) CANNOT handle Authelia redirects. They expect JSON. |
| | 2. WebSocket at `/socket` uses `api_key` param -- not compatible with cookie auth. |
| | 3. Jellyfin already has its own user auth system (separate from Authelia). |
| | 4. Double auth (Authelia + Jellyfin login) is poor UX for web users too. |
| | **Recommendation**: Either fully exempt Jellyfin OR use a separate subdomain for mobile apps. |
| | The best approach is full exemption -- Jellyfin's own auth is sufficient for a media server. |
| | Users can use Jellyfin's built-in "quick connect" or sharing features without auth friction. |
| | **Exemption**: entire `/` for Jellyfin (or at minimum `/socket`, `/audio/`, `/videos/`, `/Users/`, `/Items/`, `/System/`) |

---

### 12. code.glats.org (code-server) -- :9008

| Property | Value |
|----------|-------|
| Description | VS Code in browser -- full IDE |
| Has API? | YES -- VS Code paths: `/api/`, `/resource/`, `/lib/vscode/`, `/build/` |
| | Extensions marketplace connects to `/api/` (or external open-vsx.org) |
| WebSocket? | YES -- root `/` is WebSocket-upgraded for terminal, editor protocol |
| Mobile apps? | No (uses browser) |
| Integrations | None directly (VS Code extensions fetch from external marketplaces) |
| **Exemption needed?** | **NO** -- full protection desired |
| Notes | code-server has its own password auth. Adding Authelia gives SSO layer. |
| | VS Code extensions fetch from external (open-vsx.org or Microsoft marketplace) -- not affected. |
| | The `/api/` paths are for VS Code internals (not external API consumers). |
| | If custom extension marketplace is configured, `/api/` might need an exemption. Default is fine. |
| | Full protection is recommended. |

---

## Summary Table

| Service | Subdomain | Port | Has API | WS | API Paths | Mobile Apps | Exempt? | Exempt Paths |
|---------|-----------|------|---------|----|-----------|-------------|---------|--------------|
| Wetty | tty | 9004 | NO | YES | (none) | No | **NO** | -- |
| Guacamole | guac | 9003 | YES | YES | `/api/`, streaming endpoint | Yes | MAYBE | `/api/`, streaming endpoint |
| FileShelter | file | 5091 | NO | NO | (none) | No | **NO** | -- |
| qBittorrent | qbit | 8080 | YES | NO | `/api/v2/` | Yes | **YES** | `/api/v2/` |
| Gonic | gonic | 4747 | YES | NO | `/rest/` | **Yes (DSub, etc.)** | **YES** | `/rest/` |
| Radarr | radarr | 7878 | YES | NO | `/api/`, `/api/v3/` | Yes | **YES** | `/api/`, `/api/v3/` |
| Sonarr | sonarr | 8989 | YES | NO | `/api/`, `/api/v3/` | Yes | **YES** | `/api/`, `/api/v3/` |
| Prowlarr | prowlarr | 9696 | YES | NO | `/api/`, `/api/v1/` | Some | **YES** | `/api/`, `/api/v1/` |
| Bazarr | bazarr | 6767 | YES | NO | `/api/` | No | **YES** | `/api/` |
| Jellyseerr | seerr | 5055 | YES | NO | `/api/`, `/status`, `/status/appdata` | Yes | **YES** | `/api/`, `/status`, `/status/appdata` |
| Jellyfin | jelly | 8096 | YES | **YES** | `ALL paths`, `/socket` | **Yes (many)** | **YES (full exemption recommended)** | `/` (entire domain) |
| code-server | code | 9008 | YES | **YES** | `/`, `/api/`, `/resource/`, `/lib/vscode/` | No | **NO** | -- |

---

## Key Findings

### ARR Stack (Radarr/Sonarr/Prowlarr/Bazarr)
- **INTERNAL communication uses localhost:PORT directly** -- never goes through nginx
- Adding Authelia SSO does NOT break service-to-service communication
- API paths need an exemption ONLY if external tools (NZB360, Lumixarr) connect via the public domain
- If you only use browser for ARR stack management, you DON'T need API exemptions at all

### qBittorrent
- ARR stack downloads via localhost:8080 internally -- no impact
- Third-party mobile apps need an `/api/v2/` exemption if they connect externally
- API uses cookie-based auth (POST to `/api/v2/auth/login`) -- compatible with Authelia? Potentially conflicting

### Gonic
- **MUST exempt `/rest/`** if you want Subsonic mobile apps (DSub, Ultrasonic, etc.) to work
- These apps cannot handle Authelia redirects -- period
- If you only use browser/WiFi streaming, exemption is optional

### Jellyfin -- Special Case
**Strong recommendation: fully exempt Jellyfin from Authelia.**

Reasons:
1. Jellyfin has mature built-in auth (users, passwords, API keys, quick connect)
2. Mobile/TV apps CANNOT work with Authelia (confirmed by many community reports)
3. WebSocket at `/socket` uses `api_key` param -- incompatible with cookie auth
4. Double auth is poor UX (login to Authelia, then login to Jellyfin again)
5. Jellyfin supports user sharing (invite friends) -- would conflict with Authelia

Alternative: Use `jelly.glats.org` for web users (with Authelia) and a separate subdomain
for mobile apps (no Authelia). But this is messy.

### Guacamole
Works fine fully protected. Has its own login page as secondary auth layer.
If mobile Guacamole client is used externally, exempt `/api/` and the streaming endpoints.

### Wetty, FileShelter, code-server
No exemption needed. These are browser-only services that benefit from SSO.

---

## Recommended nginx Config Pattern

For each service that needs an API exemption, add specific location blocks BEFORE the protected `/` block:

```nginx
# Exempt: no auth_request (API/WebSocket paths)
location /api/v2/ { proxy_pass http://127.0.0.1:8080; proxy_websockets true; ... }
location /rest/   { proxy_pass http://127.0.0.1:4747; ... }

# Protected
location / {
    auth_request /internal/authelia/authz;
    proxy_pass http://127.0.0.1:8080;
}
```

Or for Jellyfin (full exemption):
```nginx
# No auth_request at all
location / {
    proxy_pass http://127.0.0.1:8096;
    proxy_websockets true;
}
```

---

## Implementation Priority

1. **Jellyfin** -- FULL EXEMPTION (or protect with its own auth only)
2. **Gonic** -- exempt `/rest/` for music apps
3. **qBittorrent** -- exempt `/api/v2/` for mobile apps
4. **ARR stack** -- exempt `/api/` if external tools connect via domain
5. **Jellyseerr** -- exempt `/api/` for mobile apps
6. **All others** -- full Authelia protection (no exemption needed)
