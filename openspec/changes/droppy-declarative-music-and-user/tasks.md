# Tasks: Droppy Declarative Music and Preserved Native Accounts

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~30 deletions + 2 file deletions |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | single PR |
| Delivery strategy | ask-on-risk (default; none injected) |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Scoped cleanup + offline proof | PR 1 | `nix eval .#nixosConfigurations.rog.config.virtualisation.oci-containers.containers.droppy.volumes` | N/A — runtime gated, no Docker/service action | Revert removal via git; never restore rejected provisioning |

## Status Baseline

- Completed planning: `exploration.md`, `proposal.md`, `specs/droppy-music-access/spec.md`, `design.md`.
- Apply-start inspection: the approved music line was already present as the only `droppy.nix` diff; the `sops.secrets.droppy-users` and `docker-droppy.preStart` blocks were already absent, as were the seed and `droppy.test.py`. No provisioning cleanup edits or file deletions were needed.
- Already-created live (not Nix-reproducible): `shrike` hot-provisioned in runtime `db.json`; `glats` unchanged.

## Blocker / Decision Before Apply

- Design `File Changes` says "remove unused `config` argument"; approved scope forbids speculative cleanup (arg pre-existed unused at HEAD). Minimal correction: drop that clause from `design.md`; keep `{ config, pkgs, ... }`. Do not remove any arg.
- Missing-source: spec is an acceptance gate only; design's manual preflight matches it and explicitly disclaims fail-closed startup. No silent reinterpretation, so no spec change is required. `hosts/rog/default.nix:228` (`startLimitIntervalSec = 0`) further means apply/verify MUST NOT claim fail-closed startup; record the residual mount-loss race.

## Phase 1: Scoped cleanup (apply, separately authorized)

- [x] 1.1 Confirm `linux/system/services/web/droppy.nix` contains no `sops.secrets.droppy-users` block; none was present at apply start.
- [x] 1.2 Confirm `docker-droppy.preStart` has no account-provisioning block; none was present at apply start. Preserve the pre-existing `config` argument and permission units.
- [x] 1.3 Retain `"/run/media/library/music:/files/music:ro"`, `/config`, and `/files` volume lines unchanged.
- [x] 1.4 Confirm `secrets/host/rog/droppy-users.json` is absent without reading or decrypting it.
- [x] 1.5 Confirm `linux/system/services/web/droppy.test.py` is absent; add no adjacent replacement Python test.
- [x] 1.6 Confirm unrelated dirty files remain untouched; edits were limited to this task artifact.

## Phase 2: Offline proof

- [x] 2.1 `nix fmt -- linux/system/services/web/droppy.nix` completed; formatter reported 0 files changed.
- [x] 2.2 `nix eval --json .#nixosConfigurations.rog.config.virtualisation.oci-containers.containers.droppy.volumes` returned exactly `/srv/glats/droppy/config:/config`, `/run/media/stuff/droppy:/files`, and `/run/media/library/music:/files/music:ro`.
- [x] 2.3 Evaluated `docker-droppy.preStart` as empty, confirmed `droppy-users` absent from `config.sops.secrets`, and confirmed generated unit text has no account-provisioning references; OCI-generated lifecycle hooks remain.
- [x] 2.4 `nix eval --raw .#nixosConfigurations.rog.config.system.build.toplevel.drvPath` succeeded with `/nix/store/761szca1j5ib904qh362wk0krh5j0m05-nixos-system-rog-26.05.20260822.a9e6d84.drv`.
- [x] 2.5 Disposition: optional synthetic fixture SKIPPED / N/A, not run. Rejected provisioning was removed, so no provisioning merge tests are needed; no implemented preflight helper exists to exercise. This task originally concerns a missing-source fixture, and that negative-source scenario remains untested. Actual source availability was checked read-only after deployment instead; no Docker absence experiment or fallback directory creation.

## Phase 3: Authorization boundary (post-deployment read-only verification authorized)

- [x] 3.1 Stop after offline proof; report configuration acceptance separately from pending runtime acceptance (spec Separate deployment authorization).
- [x] 3.2 Post-deployment source availability verified under the user's read-only authorization: `/run/media/library` is mounted from `/dev/sdc1`, ext4, UUID `608cd7cf-3cb4-4589-8f36-c558fb4e32a3`; music is a directory resolving inside it. This is NOT a pre-action preflight: deployment was already reported complete, and historical preflight timing is unproven. No service action or fallback creation occurred. The original missing-source acceptance gate and mount-loss risk remain; no fail-closed guarantee is claimed.
- [ ] 3.3 User-confirmed authenticated read-only music/original-files browsing and existing `glats` / non-privileged `shrike` login remain pending. Safe current DB metadata proves both records exist, `glats` privileged=True and `shrike` privileged=False; actual deployed music bind has RW=false and a music sample is readable, with HTTP 200. No live login, credential validation, historical hash comparison, account/DB write, or credential output occurred. Supply user confirmation without credentials; agent login would need separate explicit session-mutation permission.

### Work Unit Evidence — Unit 1: Scoped cleanup + offline proof

| Evidence | Result |
|---|---|
| Focused test command and exact result | `nix eval --json .#nixosConfigurations.rog.config.virtualisation.oci-containers.containers.droppy.volumes` succeeded; exactly three expected volume strings, including the read-only music bind. Generated-unit assertions succeeded: empty `preStart`, no `droppy-users` secret attr, and no account-provisioning terms in unit text. |
| Runtime harness command/scenario and exact result | N/A — runtime intentionally gated; no Docker, service action, activation, account/database access, or live login test was performed. |
| Rollback boundary | Revert only the music bind if needed; never restore rejected provisioning. The accidental seed and adjacent test were already absent at apply start. |

Prior apply offline proof completed: `nix fmt -- linux/system/services/web/droppy.nix` succeeded (0 files changed); `rog` toplevel drvPath evaluation succeeded. These are prior apply results, not independent current full-suite evidence.

Post-deployment verification (2026-10-05): `python3 /home/glats/.local/opencode-v2/tmp/opencode/droppy-postdeploy-verify.py` exited 0. Current closure and loaded unit match, no drop-ins, expected deployed volumes, OCI-only preStart, no applied `droppy-users` SOPS declaration, correct source mount, running container music RW=false, readable existing MP3 and original directory, HTTP 200, and safe native account flags confirmed. The source module remains exactly one music-line insertion relative to HEAD; permission units unchanged; rejected artifacts absent. No deployment/restart, account mutation, music write, staging, commit, push, or archive occurred. Full independent offline suite remains blocked by incomplete task 3.3; authenticated runtime acceptance and historical credential/session/link preservation are not proven. See the admitted `verify-report.md` for exact evidence hashes and limits.

Threat matrix is N/A per design; no RED-test task applies.
