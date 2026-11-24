# Port remap to the 9000 band

Objective: consolidate every locally reachable service port into 9000+ and release
8000-8999 for development use, without touching protocol-fixed ports.
Branch: master. Delivery: local work-unit commits only; push/PR/switch are user-owned.

## Specs

S1. qBittorrent must not use 8080.
    Verbatim: "no quiero que qbitorrent use el 8080"
    Applied: `webuiPort = 9017` in `linux/system/services/media/qbittorrent.nix:11`,
    nginx vhost `qbit.${domain}` at `linux/system/services/web/nginx.nix:553`,
    and the five doc references in `docs/authelia-access-exemptions.md`.

S2. All locally reachable service ports must live at 9000 or above, whenever no
    protocol or app constraint forbids it.
    Verbatim: "quiero etnender el desorden y tener todos desde el 9000 en adelante
    siempre cuando no sea oblitagorio pasar poe httpss"

S3. The 8000 block must be released for development use.
    Verbatim: "y si va a pasar por https. cerrar los 8000 . prque los ocupo par
    desarrollos entiendes?"

S4. Constraint clarification (verified, see Log L2): HTTPS is not bound to any port.
    Every public vhost terminates TLS in nginx (`useACMEHost` + `forceSSL`) and
    proxies to plain HTTP on loopback. No upstream service listens on TLS.
    Therefore "must go through HTTPS" never pins an upstream port; it only requires
    the service to stay behind a nginx vhost.

S5. Protocol-fixed and well-known ports are out of scope and must not move:
    21 ftp, 22 ssh, 53 AdGuard DNS, 80/443 nginx, 139/445 samba, 631 CUPS,
    3389 xrdp, 51820 wireguard, 6881 qBittorrent torrenting.

S6. Ports owned by non-managed local tooling must never be assigned to services:
    9011 (node, opencode-go proxy), 9999 (python, opencode-go proxy),
    7437 (engram), 11434 (ollama), 4011/4012 (sing-box tunnel).

S7. Cross-host contract: `shared/nix-cache.nix` pins harmonia at 8501 and is
    imported by rog, thinkcentre, t14, macm5 and samsung. Moving it must happen as
    one coordinated change across all five hosts, never unilaterally.

## Inventory (observed)

Verified from `ss -Hltnp` on rog plus repository sources.

Already in the 9000 band, no change needed:
9002 droppy ([web/droppy.nix:7](linux/system/services/web/droppy.nix)),
9003 guacamole ([network/guacamole.nix:289](linux/system/services/network/guacamole.nix)),
9004 wetty ([web/wetty.nix:9](linux/system/services/web/wetty.nix)),
9008 code-server ([web/code-server.nix:7](linux/system/services/web/code-server.nix)),
9015 cobalt ([web/cobalt.nix:9](linux/system/services/web/cobalt.nix)),
9016 dozzle ([web/dozzle.nix:9](linux/system/services/web/dozzle.nix)),
9017 qBittorrent (S1), 9091 Authelia ([web/authelia.nix:93](linux/system/services/web/authelia.nix)).

Nix-controlled, cheap to move (module line plus one nginx line):

| Service | Now | Target | Evidence |
|---|---|---|---|
| gonic | 4747 | 9006 | `network/gonic.nix:8`, `web/nginx.nix:388` |
| fileshelter | 5091 | 9007 | `web/fileshelter.nix:11`, `web/nginx.nix:458` |
| romm | 8081 | 9009 | `media/romm.nix:4`, `web/nginx.nix:563` |
| romharbor | 8082 | 9010 | `media/romharbor.nix:6`, `web/nginx.nix:570` |
| flaresolverr | 8191 | 9014 | `media/flaresolverr.nix:6`, consumed by Prowlarr config |
| bazarr | 6767 | 9018 | `media/arr-stack.nix:42`, `web/nginx.nix:141` |
| adguard web | 3000 | 9023 | `network/adguardhome.nix:50`, LAN only, no vhost |

App-owned, expensive to move (no nixpkgs option; port lives in app state):

| Service | Now | Target | Why expensive |
|---|---|---|---|
| jellyseerr | 5055 | 9005 | host-network container, `web/seerr.nix`; `settings.json` holds radarr 7878 and sonarr 8989 |
| jellyfin | 8096 | 9013 | host-network container; port in `config/network.xml`; `web/nginx.nix:352,368` |
| sonarr | 8989 | 9019 | nixpkgs has no `listenPort`; `config.xml` carries no `Port` element, factory default |
| radarr | 7878 | 9020 | same as sonarr |
| prowlarr | 9696 | 9021 | same as sonarr; also holds indexer/app links to sonarr/radarr |
| openfang | 50051 | 9022 | external binary, port not declared in Nix; `web/nginx.nix:618,629,640,653` |

Held back deliberately: nix-cache 5000/8501 (S7).
Dead file: `media/romcatalog.nix` defines 8082 too and is not imported by rog.

## Tasks

T1 [S1] DONE, activation pending — qBittorrent moved to 9017 in module, nginx and docs.
T2 [S2,S3] pending — Nix-controlled batch: gonic, fileshelter, romm, romharbor,
   flaresolverr, bazarr, adguard. One commit, tests are the eval plus a vhost smoke check.
T3 [S2,S3] pending — app-owned batch: sonarr, radarr, prowlarr, jellyfin, jellyseerr,
   openfang, including repairing stored links (bazarr `config.yaml`, jellyseerr
   `settings.json`, Prowlarr app links, qBittorrent download client in Sonarr/Radarr).
T4 [S3] pending — nix-cache 8501 coordinated across five hosts (high risk, item 3).
T5 [S3] pending — delete dead `media/romcatalog.nix`.
T6 pending — activation: `nixos-build switch`, then `ss -Hltnp` shows nothing of ours
   in 8000-8999, and every vhost answers through nginx.
T7 pending, user-owned — edit the Sonarr and Radarr download client from
   `localhost:8080` to `localhost:9017` in their own UI. Lives in each app database,
   not in this repository. Must run before or with T6, otherwise completed-download
   import breaks. Also verified: `qBittorrent.conf` has no `WebUI\Port` line, only
   `Session\Port=6881` and `WebUI\Password_PBKDF2`, so the `--webui-port` flag from
   the module is authoritative and nothing persists 8080.

T3 risk line: item 3 (contracts others consume: app-to-app URLs persisted in
databases) and item 5 (service restarts). Needs a verifier.

## Risks

The qBittorrent move is inert until activation, and Sonarr/Radarr still point their
download client at `localhost:8080` in their own database. Until that client is
edited to 9017 the completed-download import breaks, independently of T2/T3.

Moving ARR ports breaks every stored link in both directions: bazarr to radarr,
jellyseerr to radarr/sonarr, prowlarr to sonarr/radarr, arr to qBittorrent.
Each must be repaired in the same work unit or downloads and metadata stop.

`nix-cache` at 8501 is a substituter URL on four client hosts; a unilateral move
breaks binary cache resolution everywhere.

## Log

L1. User: "no quiero que qbitorrent use el 8080"

L2. User: "ya bien. entonces veo que hay un desorden en los puertos cierto? mir
antiguamente yo partia todos mis servicos desde el 9000 pero solo loca. para netrar
com localhost:9012 . con docker compose en su tiempo. pero no toda slas web se peudan
porque algunas obligadas pasan por https. entonces quiero etnender el desorden y
tener todos desde el 9000 en adelante siempre cuando no sea oblitagorio pasar poe
httpss. y si va a pasar por https. cerrar los 8000 . prque los ocupo par desarrollos
entiendes?"

L3. Correction premise found during exploration: HTTPS does not constrain upstream
ports in this repository. Every vhost uses `useACMEHost` plus `forceSSL` and proxies
to loopback HTTP, so no service needs a specific port to be HTTPS-capable. The real
blockers are protocol-fixed ports and app-owned defaults outside Nix.

L4. User: "ojo no te pedi cambios pero no hagas rollback. que descrubirs so far?"
Interpreted as: keep the applied qBittorrent change, report findings instead of
continuing. No rollback performed.

L5. User chose "Solo el plan, sin cambios": this document is the deliverable. No
configuration file is to be modified until the user reviews it.

L6. Evidence observed on rog before writing this plan: port 8080 still listening
(qBittorrent not restarted, change inert), 9011 and 9999 held by the user's
opencode-go proxy processes, 8096 Jellyfin, 8082 romharbor, 50051 openfang.

L7. User: "deja todo anotado en el odd"
Action: this document and its Engram mirror carry the full handoff state below.
No configuration touched in this step.

L8. State at handoff (verified).
Working tree on master, ahead of origin/master by 1 commit before this session.
Modified by this session: `linux/system/services/media/qbittorrent.nix` (webuiPort
8080 to 9017), `linux/system/services/web/nginx.nix` (qbit vhost port to 9017),
`docs/authelia-access-exemptions.md` (five port references). Also modified but NOT
ours: `linux/system/services/media/romm.nix` adds `TASK_TIMEOUT = "28800"` inside
the container environment; it was already dirty when the session started and was
left untouched.
Verification already run: `nix fmt` on both touched Nix files reported 0 changed;
`nix eval .#nixosConfigurations.rog.config.system.build.toplevel.drvPath` evaluated
to a valid store path.
Untouched: `.worktrees/rog-maquilinux-org` holds its own copies of these files; no
edits were made there. Nothing was committed, pushed, or switched.

L9. Open decisions for the next session: confirm the target port numbers in the
Inventory tables, then choose the order between T2 (Nix-controlled batch) and T3
(app-owned batch). T4 (nix-cache) and T5 (delete romcatalog.nix) stay independent.
T7 must not be forgotten when T6 runs.
