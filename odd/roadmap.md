# Roadmap

Parent map for this repository's active product lines. Direction, capabilities, dependencies and
delivery boundaries live here; each feature owns its own document under `odd/tasks/`.

## rom-catalog

Product: one web place to pick a game by platform, ordered, with good galleries, and to download
ROMs into the library that RomM already serves.

Feature owner: `odd/tasks/rom-catalog.md`

| Delivery | Scope | Host | URL | Status |
| --- | --- | --- | --- | --- |
| D1 | RomM gallery hardening: cover/metadata providers, artwork priority, filesystem watcher, scheduled rescan | `rog` | `https://roms.glats.org` | in progress |
| D2 | `romcatalog` Go service: Internet Archive catalog, platform picker, cover gallery, resumable verified downloads into the library | `rog` | `https://rom.glats.org` | pending (source policy decision open) |
| D3 | Platform to emulator/core map, optional MCP endpoint for assistants | `rog` | `https://rom.glats.org` | pending |

Boundaries: `rog` only, no new host. RomM stays the library (metadata, screenshots, in-browser
play); `romcatalog` is the discovery and acquisition front-end. Downloads land in the same library
disk that RomM scans, so a downloaded game shows up in RomM without a second copy.

Dependencies: D2 needs D1's scan pipeline (watcher plus scheduled rescan) to surface downloaded
ROMs, and D1's provider configuration for the gallery.

Standalone application: the user approved initializing [ROMHarbor](https://github.com/glats/romharbor)
as a separate public MIT-licensed repository, based on `glats/web-base`. The repository has been
created and the verified application foundation is published on `main` at `2e373abd425a`.
`make test` and `make lint` passed. Native review could not start because of its context budget;
the user authorized reporting the failure and continuing without review for that candidate.
Catalog extraction and migration have not started. This configuration repository keeps deployment wiring
and the library layout; do not duplicate the new application's task ledger here.

Destination planning: `docs/rom-destinations.md` maps all current catalog platforms to emulator
candidates and host/handheld folders. `rog` remains the source of truth. Selected games may later
be copied to playing hosts over SSH/HTTP or to the Powkiddy V90S over a supported network route
or SD card. This map does not authorize installs, transfers, SD changes or the separate app.
Runtime emulator inventory, device connectivity and per-game launch proof remain pending.
