# Tasks: Guacamole RDP Shared Filesystem (Drive Redirection)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~10-20 (1 file: guacamole.nix) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | stacked-to-main |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: stacked-to-main
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Bind `/srv/glats/guacamole/drive` into `guacamoled` + tmpfiles dir | PR 1 | `nix flake check --no-build` | `nixos-build dry` then real `nixos-build` on rog; `docker exec guacamoled id -u` → 1000 | Remove `volumes` line + tmpfiles rule, rebuild; dir additive, UI params independent |

## Phase 1: Nix Edit (guacamole.nix)

- [x] 1.1 In `linux/system/services/network/guacamole.nix`, container `guacamoled` (lines 277-289, currently no volumes): add `volumes = [ "/srv/glats/guacamole/drive:/drive" ];`
- [x] 1.2 In same file at module scope: add `systemd.tmpfiles.rules = [ "d /srv/glats/guacamole/drive 0750 1000 1000 -" ];` (pattern: samba.nix:64, gonic.nix:27, ftp.nix:49)

## Phase 2: Format + Static Check

- [x] 2.1 Run `format-nix`; confirm `git diff --stat` shows only `guacamole.nix`
- [x] 2.2 Run `nix flake check --no-build` — must exit 0

## Phase 3: Deploy + Runtime Verification (rog)

- [x] 3.1 Run `nixos-build dry` on rog — expect only docker-guacamoled + tmpfiles diff
- [x] 3.2 Run `nixos-build` on rog — container recreates with bind mount; check "switching to generation"
- [x] 3.3 Verify UID: `docker exec guacamoled id -u` → `1000` (silent Permission denied if wrong owner)
- [x] 3.4 Verify writable: `docker exec guacamoled touch /drive/.wtest`; host `ls -l /srv/glats/guacamole/drive` → owner 1000; delete `.wtest`

## Phase 4: Manual UI Step (postgres DB, NOT Nix) + E2E

- [ ] 4.1 In admin UI (guac.glats.org, `guacadmin`): per RDP connection → Parameters → `enable-drive=true`, `drive-path=/drive` (container path, NOT host), optional `drive-name`; both directions enabled; shared single `/drive`
- [ ] 4.2 Document the manual step above (survives rebuilds in `dbdata`; not automatable via Nix)
- [ ] 4.3 E2E: in one RDP session, upload + download a file via the drive; confirm file lands on host at `/srv/glats/guacamole/drive`
