# rom-catalog

Objective: give the user one web place to pick a game by platform, ordered, with good galleries,
and to download the ROMs that are missing from the library that RomM already serves.
Branch: `feat/rom`. Delivery strategy: `ask-on-risk` (work-unit commits on the branch; push and
PR stay with the user). Test runner: `nix eval .#nixosConfigurations.rog.config.system.build.toplevel.drvPath`,
`nix flake check --no-build`, `go -C pkgs/nixos-scripts test ./...` (from D2 on).

## Specs

S1. RomM keeps serving the library at `https://roms.glats.org`, and its gallery shows cover art
for games that RomM can match by file name or hash. Zero-key providers are used first
(libretro thumbnails, Hasheous, LaunchBox); IGDB and a ScreenScraper account stay optional.
S2. RomM's `config.yml` is rendered by Nix into `/srv/glats/romm/config/config.yml` and written
only when its content changes. Metadata priority is `igdb, ss, moby, launchbox, hasheous, ra,
gamelist, tgdb, flashpoint, hltb`; artwork priority is `ss, igdb, moby, sgdb, libretro,
launchbox, hasheous, ra, tgdb, flashpoint`; cover priority is `ss, igdb, libretro, hasheous`;
screenshot priority is `ss, igdb, moby`; region priority is `us, wor, ss, eu, jp`; language
priority is `en, es, fr`; scanned media types are `box2d, box3d, miximage, screenshot,
title_screen, marquee`.
S3. The RomM container re-scans when the library filesystem changes
(`ENABLE_RESCAN_ON_FILESYSTEM_CHANGE=true`, 5 minute debounce) and runs a nightly scheduled
rescan (`SCHEDULED_RESCAN_CRON=0 3 * * *`); the scan timeout is 28800 seconds.
S4. `HASHEOUS_API_ENABLED=true` and `LAUNCHBOX_API_ENABLED=true` (with
`ENABLE_SCHEDULED_UPDATE_LAUNCHBOX_METADATA=true`) turn on the zero-key providers. Provider
credentials that need an account (IGDB, ScreenScraper user) are read from sops when present and
are never written into the repository.
S5. ROMHarbor is the separately published application, consumed through a pinned external flake input rather than embedding application changes in `nixos-scripts`. It exposes a platform picker, a searchable game grid with cover art, a per-game detail view, and a download action. Preserve the legacy `pkgs/nixos-scripts/cmd/romcatalog` and `internal/romcatalog` source as a rollback reference; the log retains its implementation history.
S6. A download is resumable (HTTP `Range`), verifies the source checksum before the final move,
and writes only inside `/run/media/library/roms/<romm-platform-slug>/`. RomM then sees the new
file through its read-only bind mount and surfaces it in its own gallery.
S7. Every catalog platform maps to a RomM platform slug, the libretro cores that run it, and the
ROM file extensions it accepts, so the same catalog serves RetroArch and the RomM in-browser
player.
S8. `romcatalog` is served at `https://rom.glats.org` by nginx, bound to `127.0.0.1`, behind the
existing Authelia integration, with the wildcard `*.glats.org` certificate. The user approved
replacing Basic Auth during recovery. Preserve the existing global LAN-bypass policy; externally,
unauthenticated requests must not reach application data or enqueue downloads.
S9. Requested coverage remains Internet Archive plus an extra source. Recovery explicitly uses
Internet Archive only: dlarchive now rejects listing with HTTP 403, and lolroms live search and
catalog integration remain unverified. Extra-source acceptance is pending, not complete.
Earlier research rejected Myrient (shut
down 2026-03-31, the host answers 200 with a notice page), MiNERVA (torrent only, needs aria2 and
peers), dlpsgame (links are base64 hidden behind one-click hosts with captchas), nopaystation
(serves installers that need RAP and zRIF licences, not playable dumps).
S10. The download page is one flow: platform picker, search, per-card download button with
progress and the final path. The platform page states the folder the ROM lands in.
S11. Restore usable catalog access after the user request "entonces arergalrlo par apoder usarlo."
Preserve the mounted library and newer unrelated host configuration. Verify the service, public
authentication boundary and platform browsing before claiming recovery. System activation and
durable Git integration remain subject to repository authorization policy.
S12. User clarification, verbatim: "se que no es bloqueante para jugar pero lo neceistamos para dejar mi stack listo no? enotnces si lo agfregaria a todo list." Community-ready ROMHarbor distribution is required for the complete stack, not an optional later enhancement: finish and verify the standalone flake/NixOS module, Docker/Compose packaging and versioned GHCR release workflow. Actual source/image publication and deployment remain separately authorized. This does not make community packaging a prerequisite for an isolated gameplay test.
S13. Complete the full seven-item list quoted verbatim in L26: command/query correction; security and usable web downloads; verified flake/module and Docker/Compose; authorized versioned GHCR publication; stack integration and download/library/RomM acceptance; actual macm5 gameplay, controls and saving plus Powkiddy transfer. Continue authorized safe work without transition-by-transition approval; surface only concrete blockers or required explicit consent. Keep this session in the original NixOS worktree.
S14. User correction, verbatim: "se supone que homebrew instala usando nix. no enitendo porque lo estad descargando para macm5". Manage macm5 applications through the existing nix-darwin declarations; do not use imperative brew installation as a parallel configuration path. Verify declared versus active state first. A broad activation with the current upgrade/cleanup settings remains separately gated.
S15. User delivery instruction, verbatim: "yo creo que ya opdemos mergearr con master lo de nixos. hare build desde alla". Prepare the verified ROMHarbor host integration and merge the NixOS work into local master, preserving unrelated changes. This supersedes L22's earlier exclusion from master. Builds and host activation remain exclusively user-owned, reinforced by "si. yo activo por si caso"; do not build or activate hosts or restart services.

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S1-S4 | parent inline (one understood change, no writer trigger) | built | L7, L10 |
| T2 | S5, S7 | parent inline (Go service, one unit) | built | L10 |
| T3 | S6, S9 | delegated worker (download unit, disjoint surface) plus parent inline (sources) | partial; extra source unavailable | L9, L10, L13 |
| T4 | S8 | parent inline | built | L10 |
| T5 | S7, S9 | parent inline, optional MCP endpoint | pending | - |
| T6 | S5, S8-S9, S11 | parent inline; read-only mapping delegated because deployment history exceeds inline evidence budget | runtime recovered and auth/browsing verified; fresh download acceptance pending | L13, L24 |
| T7 | S12 | parent orchestration from this NixOS worktree; application distribution owned by ROMHarbor | published v0.1.0; CI and anonymous GHCR read passed | ROMHarbor `248fedc`, L31 |
| T8 | S13 | bounded ROMHarbor command/query writer for long-session context backstop; independent whole-feature verification | independent verification and four native lenses passed; acknowledgement burned and source published | ROMHarbor `091df6b`, L31 |
| T9 | S5, S8, S10, S13, S15 | parent inline integration; read-only explorer for cross-repository mapping beyond inline budget | active: pinned module wiring and local master merge; end-to-end acceptance waits for user deployment | no running cutover or activation authorized |
| T10 | S7, S13-S14 | parent declarative device readiness and real gameplay/transfer proof | pending; hardware and interaction evidence required | no inferred emulator gameplay success; no imperative brew installation |

Route evidence: no delegation trigger holds for T1 (single understood change, one file plus docs);
T2-T5 are one behaviour each, so they stay inline per the write rule.

## Log

L1 (2026-11-13, user, verbatim): "quiero tener un catalog web en el cual pueda descargar el rom que yo quiera para cualquier emulador que yo quiera. rom-cli (Python, terminal con interfaz Textual): busca y descarga ROMs/ISOs de varias plataformas (SNES, GBA, Switch, etc.), con catálogo, descargas resumibles y organización por carpeta.
- Romifleur: aplicación de escritorio con interfaz moderna para buscar y descargar ROMs de consolas clásicas.
- RomGoGetter: gestor/curador que descarga y filtra desde fuentes como Internet Archive, con opciones 1G1R, verificación, etc.
- romgi: pensado para Android (ideal para handhelds tipo Anbernic/Retroid).
- Otros más nicho como rom-mcp (para integración con asistentes) o herramientas que apuntan a archivos públicos de Internet Archive. en mi nixos con rom.glats.org quizas. odd-project caveman"

L2 (2026-11-13, user, verbatim): "no, no es necesario. que despliegues y que hsots debo tener"

L3 (2026-11-13, user, verbatim): "quiero que hagas un explore. mi idea es que tenga un lugar web o algo donde eliga el juego a que plataforma y que este todo ordenado y gallerias buenas. entiendes?"

L4 (2026-11-13, discovery, host state verified over ssh to `rog` at 172.16.0.5): `rog` runs the
RomM container (`rommapp/romm:latest`, sha256 ce9d86ab…) plus `romm-db` (mariadb:11), both up.
nginx publishes `roms.glats.org` to `127.0.0.1:8081`. The library disk `/run/media/library`
(ext4, 3.6T, 776G free) is bind-mounted read-only at `/romm/library` and holds `roms/` with 11
platform folders: arcade (138 files), gb (1559), gba (1028), gbc (750), genesis (0, empty),
megadrive (1162), n64 (460), nds (101), nes (9879), psx (5), snes (719) — about 15.8k files total.
DNS `*.glats.org` already resolves through Cloudflare and the wildcard certificate covers
`rom.glats.org`, which currently hits the nginx catch-all (444). `/srv/glats/romm/config/config.yml`
exists and is empty, so RomM runs on defaults.

L5 (2026-11-13, discovery, explore handoff): RomM is the gallery the user describes and no
reusable headless downloader exists. RomM's frontend hardcodes `baseURL: "/api"`, so a custom
backend must coexist with RomM rather than replace it. Zero-key cover sources inside RomM are
libretro thumbnails and Hasheous; `libretro` is not in the default `scan.priority.artwork` list
but is in its documented default order. RomM reads `config.yml` from `/romm/config/config.yml`
and re-reads it on every scan; the file is edited two-way from the web UI, so Nix must re-render
it on every deployment. The library mount can stay read-only: the downloader writes on the host
path and RomM only reads. IA `advancedsearch.php` needs no key; `/metadata/<id>` returns per-file
`name,size,md5,sha1,format`; `/download/<id>/<file>` honours `Range` (206 verified); IA has no
per-game cover art at the item level, but per-game items commonly ship `00_coverscreenshot.png`
and `screenshot_00.png`. Platform sets on IA are single large archives (`Nintendo - Game Boy.rar`,
251MB) rather than per-file entries, so per-game items are the download unit; per-platform sets
are the bulk option. No screenshot, no DOM extraction, no copyrighted payloads beyond the
catalog's own purpose.

L6 (2026-11-14, research): RomM env names confirmed against the upstream `env.template`:
`HASHEOUS_API_ENABLED`, `LAUNCHBOX_API_ENABLED`, `ENABLE_SCHEDULED_UPDATE_LAUNCHBOX_METADATA`,
`ENABLE_RESCAN_ON_FILESYSTEM_CHANGE`, `RESCAN_ON_FILESYSTEM_CHANGE_DELAY`,
`ENABLE_SCHEDULED_RESCAN`, `SCHEDULED_RESCAN_CRON`, `SCAN_TIMEOUT`. ScreenScraper developer
credentials are baked into the upstream image (`SCREENSCRAPER_DEV_ID`, `SCREENSCRAPER_DEV_PASSWORD`)
and are read by the `ss` handler; a personal ScreenScraper account uses
`SCREENSCRAPER_USER`/`SCREENSCRAPER_PASSWORD`.

L7 (2026-11-14, checks, delivery 1): `nix eval .#nixosConfigurations.rog.config.system.build.toplevel.drvPath`
evaluates; the built system contains `romm-config.service` whose rendered oneshot compares
`/srv/glats/romm/config/config.yml` with the Nix-rendered file and installs it only when it
differs. The rendered YAML was loaded by RomM's own parser (`ConfigManager().get_config()` inside
`rommapp/romm:latest`, sha256 ce9d86ab): `SCAN_METADATA_PRIORITY`, `SCAN_ARTWORK_PRIORITY`,
`SCAN_ARTWORK_PRIORITY_OVERRIDES` (`url_cover`, `url_screenshots`), `SCAN_MEDIA`,
`SCAN_REGION_PRIORITY` and `SCAN_LANGUAGE_PRIORITY` come back exactly as specified in S2. The
evaluated container environment carries `HASHEOUS_API_ENABLED`, `LAUNCHBOX_API_ENABLED`,
`ENABLE_SCHEDULED_UPDATE_LAUNCHBOX_METADATA`, `ENABLE_RESCAN_ON_FILESYSTEM_CHANGE`,
`RESCAN_ON_FILESYSTEM_CHANGE_DELAY`, `ENABLE_SCHEDULED_RESCAN`, `SCHEDULED_RESCAN_CRON`,
`SCAN_TIMEOUT` and `ROMM_BASE_URL`. `nix fmt` reports no changes. `nix flake check --no-build` reports "all checks passed". `romm.nix` is
imported by `hosts/rog` only. The new container environment is written into the generated
`docker-romm-start` script, so activating the system restarts the RomM container with the new
flags. Pending: that activation (user decision, repository policy keeps activation explicit), the
work-unit commit, and the first scan that repaints the gallery with the new priorities.

L8 (2026-11-14, correction): the working machine is `rog` itself (hostname `rog`, 172.16.0.5);
earlier host inspection over ssh to 172.16.0.5 was a loopback. All further checks run locally.

L9 (2026-11-14, sources explore, live probes): dlarchive serves a JSON index at
`files_api.php?action=list` with 17539 items, 200 per page, no server-side search, and
`?action=file-url&id=` resolving to token-free `direct-stor.berkasdrive.com` URLs that honour
Range. RomsGames needs a POST to `<page>?download` with the ROM page as `Referer` and mints a new
URL per call. nopaystation publishes TSV dumps with `zeus.dl.playstation.net` links, size and
SHA-256, over plain HTTP only. lolroms builds direct URLs from paths. Myrient is shut down
(2026-03-31). MiNERVA is torrent only. dlpsgame hides its links in base64 `data-payload`
attributes pointing at one-click hosts. Verified IA sets with per-game files and checksums:
`nes-collection-no-intro` (100), `nointro-snes` (1746), `nointro-nintendo-gameboy` (1958),
`ef_GBC_No-Intro` (2464), `ef_gba_no-intro_2024-02-21` (3555), `nointro.md` (2774),
`ef_nintendo_64_no-intro_2024-02-10` (1216), `ni-n-ds-dec_202401` (266),
`non-redump_sony_playstation` (261), `non-redump_sony_playstation_portable` (1137),
`mame-merged` (14769). IA item metadata publishes `size` as a number for most files and as a
string for some, so the decoder accepts both.

L10 (2026-11-14, checks, delivery 2): the `romcatalog` package is 30 tests green
(`go test ./internal/romcatalog/...`), `go vet` clean, `gofmt` clean, `go build ./...` success.
The service was smoke-tested outside the system: `GET /platform/snes` answered 200 with No-Intro
titles, regions, sizes, md5 and sha1, the libretro cover URL and the direct Internet Archive
download URL; `GET /api/games` returned the same data as JSON. The first run failed with
`json: cannot unmarshal string into Go struct field itemFile.files.size`, which produced the
`sizeValue` decoder. The package build in Nix produced
`/nix/store/bsymayy0nlkn1mmcr1549jm4zb25m2m4-nixos-scripts-1.0.0` with `romcatalog` wrapped with
`p7zip` for the 7z extraction. The `romcatalog` Nix module evaluates in the `rog` system
(`nixosConfigurations.rog` drvPath evaluated through a `path:` flake, because the new files are
not tracked by Git yet and a Git flake ignores untracked files). Pending: the activation that
installs the service and the nginx vhost, the work-unit commit, and the dlarchive adapter, which
was written after the deployment snapshot was taken.

L11 (2026-11-14, user, verbatim): "ya. si vamos a hacer una apliacion de screatch la vamos a ahcer en un repo de github a aprte y sera opensources. ok? pero cuando yo te diga lo ahremos. por ahora veamos si esto funciona."

L12 (2026-11-14, decision, from L11): the standalone application is a separate public GitHub
repository, and its construction waits for the user's explicit go. This repository keeps only the
deployment: the service, its Nix wiring, the nginx vhost and the library layout. No work unit
starts on the separate repository until the user asks for it.

L13 (2026-11-14, user, verbatim): "entonces arergalrlo par apoder usarlo."

L14 (2026-11-14, incident evidence): `romcatalog.service` was absent, port 8082 refused connections,
and the public endpoint returned 525. Current system was `8q3hqwy9gwsrd6v7y4i9i45qgybvcisw`,
built from canonical `master` without the uncommitted catalog work. Canonical HEAD is `38bfa6f8`;
the feature branch base is older (`5a32a5e`). Do not roll back the full host or activate the stale
feature tree. The library remains mounted; the earlier GBA test file still exists.

L15 (2026-11-14, recovery in progress): explicit `--sources archive.org` added to the service
after a RED assertion showed no source override. GREEN structural assertion passed. Candidate
snapshot `/tmp/opencode/romcatalog-recovery.tf0MEZ` starts at canonical HEAD and ports only
catalog source, package registration, service import and nginx vhost. It excludes unrelated
RomM settings and macm5 installation changes. Focused/suite/evaluation checks are running.
Activation, public readback and canonical integration remain pending. No commit or staging
authorized or performed. Full updated Engram feature-document mirror is pending.

L16 (2026-11-14, user, verbatim): "podemos usa authelia quizas"; after the explicit proposal
to replace Basic Auth for `rom.glats.org`, the user answered "si yo creo".

L17 (2026-11-14, approved authentication change): reused existing `mkAutheliaVhost` for port
8082 and `rom.glats.org`; no shared helper, user database, secrets or global access policy changes.
Authelia health and public portal return 200; direct authorization with an external test IP returns
401 without a session. Evaluated vhost requires auth_request, has no Basic Auth and routes only
to loopback. Independent structural verification found no SSO-switch blocker; public runtime
authentication remains unverified until activation. Candidate comparison against every tracked
canonical file found only the intended host import, nginx vhost and package registration changes.
Focused and full Go tests passed. The formatter wrapper failed outside the repository; using
the underlying installed nixfmt normalizer avoids that workspace-root limitation.

L18 (2026-11-14, user, verbatim): "sigamos", answering the explicit question authorizing
activation in `rog`, including the previously disclosed nginx, Home Manager, polkit and
shutdown/netconsole restarts.

L19 (2026-11-14, activation in progress): candidate
`/nix/store/mdisg2qddbl6m3cq9wi63c0aj2zkbk8s-nixos-system-rog-26.05.20261108.ac588ef`
passed full flake evaluation and system build. Focused/full Go tests passed; independent
structural authentication checks passed. Activation launched through the built
`switch-to-configuration switch`; completion and public readback are pending. Native review
of this mixed worktree is not approved; no receipt is claimed. Keep canonical Git integration
pending separately from runtime recovery.

L20 (2026-11-15, runtime verification and correction): activation completed; romcatalog, nginx
and Authelia were active, public application routes redirected to login (302), and the internal
authz location returned 404. SNES, GBA and Genesis listings loaded from Internet Archive.
The previous GBA file retained SHA-256
`10db686936fc7306d2932f7a8c8917a44be6fdd7875283b10af275e02c95256c`.
However a public `/api/jobs` request with forged loopback forwarding headers returned 200.
The backend was immediately stopped pending correction. The catalog-only authz location now
overwrites both client-IP headers from `$remote_addr`; the shared helper/global LAN policy is
unchanged. Negative public authentication probes must pass before restoring the backend.

L21 (2026-11-15, UI correction): HTTP regression test reproduced missing SNES folder names
on platform/detail pages while the Genesis alias stayed correct. Both handlers now reuse the
existing downloader `platformDir` resolver. Test name: `TestPagesShowPlatformDownloadDirectory`.
Focused/full tests and an intermediate system build are running. Its snapshot is not modified
while the build is active; copy the auth correction after that build completes, then build the
final candidate. Final deployment must align the system profile and boot generation, not only
`/run/current-system`. Canonical working-tree Gas Town edits appeared after snapshot creation
and must remain untouched.

L22 (2026-11-15, scope correction, user, verbatim): "ojo que nada de los de rom deberia estar en master."
Only update the feature worktree from canonical master. Do not copy or integrate ROM changes
into `master` or the canonical checkout. Deployment remains suspended to avoid competing sessions.

L23 (2026-11-15, synchronization proof): `feat/rom` advanced without creating a commit to the
current canonical HEAD `ca0ccecb7b710b4f9e6cd2ecaaa9b8743f69bf6f` (seven existing upstream
commits, zero unique feature commits). All 26 pending ROM/emulator/documentation paths were
preserved only in this worktree. New feature paths were registered with user-authorized
`git add -N`; no contents were staged. Both branch tips now match, canonical master is clean,
and no ROM paths were added there. Catalog tests and feature-scoped ExecStart evaluation pass.
No build, activation, commit or push was performed. Recovery backup and manifest are retained at
`/tmp/opencode/rom-homologation.1EWuZd`. Source synchronization does not make the public catalog
available; final authentication probes and a coordinated deployment remain pending.

L24 (2026-11-15, user deployment and readback): user reported "desplegado". No additional
activation was performed by this session. Active system and boot profile both resolve to
`/nix/store/ppvck229pdizpz5f50c8xwnwb11hzggw-nixos-system-rog-26.05.20261108.ac588ef`.
The catalog transitioned to active/running during readback and listens only on `127.0.0.1:8082`;
its ExecStart explicitly selects `archive.org`. Public home, platform and jobs routes redirect
to Authelia (302); direct internal authz access returns 404. Forged X-Forwarded-For, X-Real-IP,
both headers together and an XFF chain all redirect to login, fixing the observed bypass.
Unauthenticated POST download also redirects; no jobs were queued by probes. Local SNES search
returns 15 download buttons with the correct `/roms/snes` destination; Genesis search returns
6 with `/roms/megadrive`. Earlier GBA file SHA-256 remains unchanged. Canonical master remains
clean and contains no ROM additions. A fresh complete download and authenticated browser flow
have not been exercised in this final generation; extra-source coverage remains pending.

L25 (user scope clarification, verbatim): "se que no es bloqueante para jugar pero lo neceistamos para dejar mi stack listo no? enotnces si lo agfregaria a todo list." Flake/module, Docker/Compose and versioned GHCR publication are now explicitly tracked as full-stack deliverables in T7, alongside command/query correction, web acquisition, NixOS integration and gameplay acceptance. Do not omit them from completion briefs because gameplay can be tested earlier. This log entry changes tracking only; it does not authorize a push, image/tag publication, host activation or another workspace move.

L26 (user continuation requirement, verbatim): "no paras hasta que Sí: Docker/GHCR también forma parte de dejar tu stack completo, aunque podamos probar un juego antes. Ya quedó en el TODO y en Engram.
La lista completa queda:
1. Corregir command/query en ROMHarbor.
2. Resolver seguridad, acceso web y configuración de descargas.
3. Completar y verificar el flake y módulo NixOS.
4. Completar y verificar Docker y Compose.
5. Preparar y publicar versiones en GHCR, con autorización.
6. Integrar ROMHarbor en tu stack y validar descarga → biblioteca → RomM.
7. Probar juego, controles y guardado en macm5, y transferencia a la Powkiddy.  se cumpla"

L27 (user management-path correction): S14 quotes the user verbatim. The Mac worker had already completed one direct cask install and copied the existing SNES file when the stop instruction arrived; no process remains running and no rollback/uninstall was attempted. This was the wrong management path. Contrary to the initial parent/worker diagnosis, hosts/macm5/default.nix lines 132-135 already declare retroarch-metal and dolphin, and a full nix eval of darwinConfigurations.macm5.config.homebrew.casks confirmed both. No source declaration needed adding. The shared module has onActivation autoUpdate=true, upgrade=true and cleanup=uninstall, so a global activation is not a narrow repair. No activation or GUI/gameplay occurred. The transferred file hash matches the rog source; core, controller, audio and save acceptance remain pending. Future Mac work follows declared Nix configuration rather than repeating brew install.

L28. Workspace and evidence recovery: user authorized a permanent ROMHarbor worktree at ~/Project/romharbor-worktrees/community-distribution, anchored to ~/Project/romharbor/.git. The NixOS session stayed here. All 146 file entries, modes and pending states matched the retained temporary backup; parent tests and all-systems evaluation passed at the new path. Post-command/query Docker, actual Compose persistence and x86_64 Nix package/module/KVM service proofs passed. Independent whole-feature verification found no blockers; publication and host cutover remain pending.
L29. Current runtime readback: rog library is mounted, nginx and RomM are active, but romcatalog.service is absent and port 8082 is closed. Local TLS SNI for rom.glats.org is rejected while roms.glats.org returns 200, explaining the public 525. RomM's read-only mount can read the existing SNES file; an authenticated browser search did not find Lethal Foes yet. No scan or service restart was initiated. macm5's active generation Brewfile excludes the two casks despite their declaration in this worktree; no broad activation was run. Powkiddy was absent from ADB and removable media during readiness inspection.
L30. Declarative SNES core: upstream nixpkgs libretro.snes9x forced a Darwin-broken frontend only through its generated install wrapper. Added pkgs/retroarch-snes9x/default.nix to reuse the pinned core with a library-only install phase, no allowBroken or pin changes, and declared its per-user RetroArch core file through macm5 Home Manager. The native Nix --no-link build passed on macm5 and produced an arm64 dylib with no broken-frontend closure. A bounded runtime test loaded the existing ROM and rendered a Spider-Man intro frame; a save state was written and the source ROM hash stayed unchanged. Physical controls, audible sound, gameplay and state reload are not proven. The test also wrote global RetroArch playlists/core options; preserve them without an unverified rollback. No Nix activation, Homebrew installation or unmanaged core download occurred in these core build/runtime actions.
L31 (2026-11-16). Application source and v0.1.0 were published with explicit user consent. Publish container run 43800544660 and main Verify run 43800536211 passed, including native ARM64 Nix builds. Anonymous GHCR manifest/config reads verified ghcr.io/glats/romharbor:0.1.0 at index sha256:90d70f184be355051c87144a5471bc494895368b31963bd1dc582229ac904b54, revision 248fedc63764e54fe0a727a78180261412a79716; container platform is AMD64 only. User then requested local master integration, verbatim: "yo creo que ya opdemos mergearr con master lo de nixos. hare build desde alla". This supersedes L22. User retains all builds and activation: "si. yo activo por si caso". A read-only map found the host still wired to the legacy binary; T9 now prepares the external module before merge. Keep the old source/cache untouched, use fresh /var/lib/romharbor state and the existing library, preserve mount dependencies and Authelia headers. Route stays inline; no writer trigger holds. Risk: items 2,3,5 (authentication boundary, shared package registration and deployment configuration). Existing full task mirror could not be located in Engram; local document is authoritative and full mirror reconciliation remains pending.
L32 (2026-11-16). User reaffirmed local integration, verbatim: "dale. si deja feat/rom en master por favbor". Parent synchronized feat/rom to master 780ecc95 without altering pending file hashes. Full operational Go suite, focused catalog tests, check-only formatting and whitespace checks passed. Parent and independent isolated Nix evaluations verified the replacement-only unit, mount requirement, glats/users identity, library-readable umask, sandbox and catalog-local Authelia forwarded-header overrides; all existing flake lock nodes and prior command registrations remained unchanged. Independent verification found no change-caused blocker. Full Linux, Darwin, standalone Home Manager and flake evaluations were unavailable with IFD disabled: gentle-ai-assets requires a build during evaluation. Parent reproduced the identical IFD restriction on canonical master with the correct checkout path, confirming it predates the ROM changes. Do not enable IFD or build to bypass the user's reserved build. Local integration does not prove runtime acceptance; source publication of this configuration, builds and activation remain unperformed. Native review is informational and separately consented, not delivery authority.
