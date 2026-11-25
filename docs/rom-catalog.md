# ROM catalog on rog

Two web surfaces, one library disk.

| URL | Service | Role |
| --- | --- | --- |
| `https://roms.glats.org` | RomM (`rommapp/romm` container) | The library: covers, metadata, screenshots, in-browser play |
| `https://rom.glats.org` | ROMHarbor (`romharbor.service`) | The download page: pick a platform, pick a game, download it |

Both read the same library disk, `/run/media/library`, whose `roms/` folder is bind-mounted
read-only into RomM at `/romm/library`. Downloads are written on the host side of that mount, so
a downloaded game shows up in RomM without a second copy, in the folder of its platform.

Feature document: `odd/tasks/rom-catalog.md`. Roadmap: `odd/roadmap.md`.

Destination compatibility and transfer planning: [ROM destinations](rom-destinations.md).

## Download page

ROMHarbor is the separate community application at [glats/romharbor](https://github.com/glats/romharbor).
The `romharbor` flake input pins v0.1.9's commit `d3452e8a82488b0b492f68c2bde3ddf05c277803`;
only `rog` imports its NixOS module. Application changes belong in that repository, not in the
legacy `pkgs/nixos-scripts/internal/romcatalog` source retained here for rollback reference.
nginx serves it at `https://rom.glats.org`, bound to
`127.0.0.1:8082`. Recovery now uses the existing Authelia nginx integration instead of the
earlier Basic Auth file. External unauthenticated users must be redirected to `auth.glats.org`;
the existing global LAN-bypass policy is unchanged. Public login redirects and rejection of
forged client-IP headers were verified after the user deployment on 2026-11-15.

The service uses fresh database/cache state under `/var/lib/romharbor`, preserves the old
`/var/lib/romcatalog` cache, and writes to the existing `/run/media/library/roms` library.
Its required library mount must be available before startup. Build and activation are performed
by the user; this source configuration does not prove that the running host has switched services.
Do not run the old and new services together on port 8082.

The page is one flow: pick a platform, search the catalog, press Download. The card of each game
carries the download button and shows the progress and the final path. The platform page shows
the folder the ROM lands in.

| Route | What it serves |
| --- | --- |
| `GET /` | The platform picker |
| `GET /platform/{slug}` | The games of a platform, with a search box |
| `GET /game/{id}` | The detail of one game: files, checksums, source page |
| `GET /api/platforms` | The platforms and their game counts |
| `GET /api/games` | The games of a platform, filtered by `q` |
| `POST /api/download` | Starts the download of one game, returns a job |
| `GET /api/job?id=` | The state of a download job |

Every download resumes with HTTP `Range`, verifies the checksum the source publishes, extracts
the archive when the ROM is packed, and installs the ROM atomically in
`/run/media/library/roms/<platform>/`. The path is sanitized and the result is verified to stay
inside the library root.

## Sources

| Source | Platforms | Works today | Direct URL | Notes |
| --- | --- | --- | --- | --- |
| Internet Archive | nes, snes, gb, gbc, gba, genesis, n64, nds, psx, psp, arcade | Yes | Yes | Per-game items with the No-Intro or Redump name, size and md5/sha1 per file. The set items are curated per platform in `archiveorg.go`. |
| dlarchive | Previously indexed extra platforms | No | Not reverified | Listing now returns 403: `File listing is not public. Use a direct file link.` Disabled for recovery. |
| Myrient | everything | No | No | Shut down on 2026-03-31. The host answers 200 with a notice page for every path. |
| MiNERVA | No-Intro, Redump, TOSEC, MAME | Yes | No | Torrent only, so a download needs aria2 and peers. |
| lolroms | Candidate extra platforms | Unverified | Not reverified | Fixture tests pass, but live search and empty-query catalog integration remain unresolved. Disabled for recovery. |
| romsgames | many | Yes | Yes | Needs a POST with the page as `Referer`, and mints a new URL per call. |
| dlpsgame | ps3, ps4, ps5 | Search only | No | The links are base64 hidden and point to one-click hosts with captchas. |
| nopaystation | ps1, psp, ps3, vita | Yes | Yes | Serves installers (`.pkg`) that need RAP and zRIF licences, not playable dumps. |

`services.romharbor.sources` explicitly selects `archive.org` and `lolroms`; `lolroms` supplies retail
PlayStation and the other consoles `archive.org` lacks, verified live for PS1 search and download in v0.1.9.
Other supplemental providers remain disabled until verified.
A platform in the table is not a promise that a
working source supplies games for it.

### Historical recovery checkpoint (2026-11-15)

The active system built from canonical `master` no longer contained the catalog module or
nginx vhost. The earlier deployment came from an external copy of uncommitted `feat/rom`
work, so a later canonical rebuild removed it. The library remained mounted and intact.

An initial isolated recovery candidate was prepared in `/tmp/opencode/romcatalog-recovery.tf0MEZ`
to preserve newer canonical changes. After competing activations were identified, deployments
from this session stopped. The user subsequently deployed the updated feature configuration.
Current active system and boot profile both resolve to
`/nix/store/ppvck229pdizpz5f50c8xwnwb11hzggw-nixos-system-rog-26.05.20261108.ac588ef`.
Focused/full Go tests, flake evaluation and the corrected candidate build passed before deployment.

At that checkpoint, explicit user instruction kept ROM changes only in `feat/rom`; canonical `master` was clean
and contains no ROM additions. Both branch tips were synchronized to `ca0ccecb`, preserving the
pending feature files only in its worktree. Another deployment from canonical `master` without
the feature would remove the catalog again. Coordinate a single deployment owner; do not merge
ROM work into `master` or activate a stale snapshot without authorization. On 2026-11-16 the user
authorized local master integration and reserved builds and activation for themselves; that later
instruction supersedes the earlier branch restriction. Runtime observations below are historical,
not proof that the newly pinned ROMHarbor service is deployed.

An initial negative test found that forged forwarded-IP headers could exploit the inherited
LAN-bypass policy. The backend was stopped while a catalog-local override was added to replace
both client-IP headers with nginx's `$remote_addr`. After the user deployment, the service is
active on loopback; ordinary and forged-header external requests redirect to Authelia, including
POST download requests, and the internal authz location returns 404. SNES/Genesis searches load
games and show the correct platform destinations. No jobs were queued by authentication probes,
and the earlier GBA test file retains its SHA-256. A fresh complete download and an authenticated
browser flow remain untested in this final generation; supplemental sources remain unavailable.

### Covers

Internet Archive has no item-level cover art, so the gallery uses the libretro thumbnail
collection of each platform (`thumbnails.libretro.com/<System>/Named_Boxarts/<name>.png`), which
matches by name and needs no key. The catalog fills the cover URL when it lists a platform, and
the page falls back to a placeholder when there is no match. RomM fills the rest of the artwork
with libretro, Hasheous, LaunchBox and ScreenScraper.

## Gallery (delivery 1)

RomM's provider configuration lives in `linux/system/services/media/romm.nix`. The module renders
`config.yml` into `/srv/glats/romm/config/config.yml` with the `romm-config.service` oneshot,
which writes only when the rendered content differs. RomM re-reads that file on every scan.

Configured priorities:

- metadata: `igdb, ss, moby, launchbox, hasheous, ra, gamelist, tgdb, flashpoint, hltb`
- artwork: `ss, igdb, moby, sgdb, libretro, launchbox, hasheous, ra, tgdb, flashpoint`
- cover: `ss, igdb, libretro, hasheous`
- screenshot: `ss, igdb, moby`
- region: `us, wor, ss, eu, jp`
- language: `en, es, fr`
- media: `box2d, box3d, miximage, screenshot, title_screen, marquee`

Enabled container flags: `HASHEOUS_API_ENABLED`, `LAUNCHBOX_API_ENABLED`,
`ENABLE_SCHEDULED_UPDATE_LAUNCHBOX_METADATA`, `ENABLE_RESCAN_ON_FILESYSTEM_CHANGE` (5 minute
debounce), `ENABLE_SCHEDULED_RESCAN` (`0 3 * * *`), `SCAN_TIMEOUT=28800`, `ROMM_BASE_URL`.

Zero-key providers that need no account: libretro thumbnails, Hasheous, LaunchBox. The upstream
image already carries ScreenScraper developer credentials (`SCREENSCRAPER_DEV_ID`,
`SCREENSCRAPER_DEV_PASSWORD`), which the `ss` handler reads.

### Optional account credentials

IGDB and a personal ScreenScraper account improve cover quality but need the user's own
credentials. They are read from sops when present and are never stored in the repository. Adding
them is a follow-up: create `secrets/host/rog/romm-providers.yaml` (creation rule before the
generic host rule in `.sops.yaml`), then map `IGDB_CLIENT_ID`, `IGDB_CLIENT_SECRET`,
`SCREENSCRAPER_USER` and `SCREENSCRAPER_PASSWORD` into the container environment.

### Rescan

The container re-scans by itself when files land in the library, and nightly at 03:00. To force a
rescan from the UI: RomM's settings, `Library -> Library Management`. A scan of the current
library (about 15.8k files) needs the extended timeout configured above.

## Operations

```bash
# the catalog service
systemctl status romcatalog
journalctl -u romcatalog -f

# container and logs
docker ps --filter name=romm
docker logs --tail 50 romm

# rendered config on the host
cat /srv/glats/romm/config/config.yml

# library layout
ls /run/media/library/roms
```

Source decisions and delivery state are tracked in `odd/tasks/rom-catalog.md`.
