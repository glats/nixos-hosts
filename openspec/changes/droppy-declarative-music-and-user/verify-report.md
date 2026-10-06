```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:b9f4e1cd4f630123b070e1f7e13200dc97f3c9d4c863b590c081845151aea03d
verdict: fail
blockers: 1
critical_findings: 1
requirements: 0/6
scenarios: 0/8
test_command: "python3 /home/glats/.local/opencode-v2/tmp/opencode/droppy-postdeploy-verify.py"
test_exit_code: 0
test_output_hash: sha256:fb7c036366feabb56c08fb5ee302fc95f01f66024325810172d77b575970ac27
build_command: "NOT RUN: task 3.3 remains incomplete; full offline verification blocked by task-completeness gate."
build_exit_code: 125
build_output_hash: sha256:2fa5123db272d6fecc227db59b9fd96326c88d004a08f5a662107585c059c9ae
```

## Verification Report

Change: `droppy-declarative-music-and-user`. Standard mode; Strict TDD disabled. Post-deployment read-only verification on `rog`, 2026-10-05. Deployment infrastructure checks PASS; full SDD acceptance BLOCKED / partial, not archive-ready. The strict envelope uses FAIL because required login/browsing acceptance remains incomplete, not because the deployed music mount failed.

### Completeness

| Metric | Value |
|---|---|
| Requirements / scenarios | 6 / 8, counted from retrieved spec headings |
| Tasks total | 14 |
| Completed or explicitly dispositioned | 13 |
| Incomplete | 1: task 3.3 |

Task 2.5 is explicitly skipped / not applicable, not executed: there is no provisioning merge mechanism to test and no implemented preflight helper needing a synthetic fixture. Its actual wording concerns an optional missing-source fixture; no negative-source fixture was run and the unavailable-source scenario remains untested. Task 3.2 is dispositioned as successful post-deployment source verification only. Deployment was already completed according to the user; this phase cannot attest a pre-action preflight or retroactively label its source check as preflight. Task 3.3 remains unchecked: user-confirmed existing-account login and authenticated browsing are unavailable.

### Build, Tests, and Coverage

The exact temporary Python command in the envelope executed with exit 0. It performed read-only source/runtime assertions, not a full offline suite. Sanitized combined output is retained at `/home/glats/.local/opencode-v2/tmp/opencode/droppy-postdeploy-test-output.txt` and hashed in the envelope. Coverage is unavailable.

Full formatting, `rog` drvPath evaluation, evaluated volume/unit checks, configured `nix flake check --no-build`, and `nixos-build dry` were not rerun: the verify skill prohibits the full suite while task 3.3 remains incomplete. Exit 125 records this genuine prerequisite, not a failed build or missing review authority. Prior apply formatter/evaluation results remain contextual evidence only. No activation or build/deployment wrapper was executed.

### Actual Deployment Proof

| Check | Current execution evidence |
|---|---|
| Deployed generation | `/run/current-system` resolves to `/nix/store/9wwrpw70phzgmmfrkbig0zhcj4z8p0n4-nixos-system-rog-26.05.20260822.a9e6d84` |
| Loaded unit | `/etc/systemd/system/docker-droppy.service` and the current closure's unit resolve to `/nix/store/xfdi8q63xc9s75r8r7l8kn9vbvp3i44j-unit-docker-droppy.service/docker-droppy.service`; service active/running; `DropInPaths` empty |
| Actual ExecStart | Closure-backed script `/nix/store/5kl0kf3vmjci05pdjib2b4lv7pcslg0c-unit-script-docker-droppy-start/bin/docker-droppy-start` contains the music `-v` argument and both original volumes |
| Actual ExecStartPre | `/nix/store/iprw9ibq3vilj10ydw6x9drr60dxfsy9-pre-start/bin/pre-start` is the normal OCI cleanup hook (`docker rm -f droppy || true`); no account bootstrap, DB, seed, or SOPS references. It was inspected, never executed by verification |
| Applied SOPS | Activation manifests were parsed for secret-name metadata only; no `droppy-users` declaration. `/run/secrets/droppy-users` absent. Nothing decrypted |
| Source mount after deployment | `findmnt --mountpoint /run/media/library` reports `/dev/sdc1`, ext4, UUID `608cd7cf-3cb4-4589-8f36-c558fb4e32a3`; music is a directory resolving inside this genuine mount |
| Running container | `droppy` running, image `ghcr.io/droppyjs/droppy:v1.3.1` |
| Music bind | Source `/run/media/library/music`, destination `/files/music`, type bind, mode `ro`, `RW=false` |
| Original binds | `/srv/glats/droppy/config` to `/config` and `/run/media/stuff/droppy` to `/files`, both preserved as writable binds |
| Readability | Read-only `docker exec` confirms original files directory and music directory readable, and an existing MP3 sample readable; metadata-only sample lookup, no content emitted and no writes attempted |
| HTTP health | Unauthenticated `GET http://127.0.0.1:9002/` returns HTTP 200; no login, cookies retained, passwords submitted, or authenticated sessions used |

`RW=false` is Docker-level proof of a read-only bind, not an executed application write-denial test. No write was attempted against live music. Directory/sample readability and HTTP health do not establish authenticated UI browsing.

### Account Evidence and Limits

Only whitelisted native account metadata was emitted from an in-memory read of `/srv/glats/droppy/config/db.json`: `glats` exists with `privileged=True`; `shrike` exists with `privileged=False`. The persistent `/config` bind is confirmed. No hashes, passwords, sessions, tokens, shared links, or complete database output were printed or persisted. No password-shape inspection or backup comparison was needed or performed.

No account or DB write, account creation/removal, session invalidation, or native login occurred. The sole source change introduces no account mutation machinery. There is no trustworthy pre-change comparison baseline in this handoff, so original `glats` hash preservation, unchanged prior privilege values, session/link preservation, and actual credential validity are not independently proven. Current presence and flags are proven; historical preservation is not inferred from them. Original credentials were not supplied.

### Spec Compliance Matrix

| Requirement | Scenario | Status and covering evidence |
|---|---|---|
| Declarative read-only music access | Music is accessible after authorized deployment [rog] | PARTIAL: actual deployed volumes, read-only bind, music sample/original directory readability, HTTP 200; authenticated browsing and application write denial not exercised |
| Missing-source acceptance gate | Source unavailable [rog] | UNTESTED: source exists now; negative-source fixture skipped; no historical pre-action gate attested |
| Preserve native persistent accounts | Existing state survives the change [rog] | PARTIAL: current native names/flags and persistent config verified; no mutation machinery; historical credentials/sessions/links not compared |
| Remove rejected pending provisioning only after apply approval | Scoped cleanup [rog] | PARTIAL: sole music-line diff, rejected artifacts absent, deployed bootstrap/SOPS absence; no independent historical live-state baseline |
| Bounded offline verification | Offline proof succeeds [rog] | UNTESTED in this phase: full current offline suite blocked; prior apply evidence contextual only |
| Bounded offline verification | Offline proof fails [rog] | UNTESTED: no negative offline fixture run |
| Separate deployment authorization | Deployment not approved [rog] | PARTIAL: verification performed no activation, service action, or live login; past unapproved-phase scenario not replayed |
| Separate deployment authorization | Authorized runtime acceptance [rog] | PARTIAL: user reported deployment and authorized read-only checks; existing-account login/authenticated browsing confirmation pending |

No scenario is promoted to full compliance solely from source inspection or incomplete runtime evidence: 0/8 fully compliant, 0/6 fully completed requirements.

### Correctness and Design Coherence

| Check | Finding |
|---|---|
| Final code scope | Removing the single music-volume line restores `HEAD` module bytes; original config/files mappings, permission service/timer, signature, image, ports, and limits unchanged |
| Rejected artifacts | Seed and adjacent Python test absent, checked without reading/decrypting secrets |
| Mount startup ordering | Loaded service orders after Docker/socket/network-online with normal sysinit ordering; no explicit library dependency. Unit has `StartLimitIntervalSec=0` |
| Missing-source semantics | Docker `-v` can create a missing source; design's acceptance/manual gate is not autonomous fail-closed protection |
| Verification scope | Only tasks/report artifacts and approved temporary evidence files changed; unrelated dirty work preserved; no product code edit, staging, commit, push, service action, account mutation, or archive |

The post-deployment source check is successful but cannot eliminate the historical preflight gap or future mount-loss race. A mounted library now does not guarantee it was checked before deployment. No startup guard or stronger guarantee was added.

### Issues and Required Evidence

CRITICAL: Task 3.3 and required authenticated runtime acceptance remain incomplete. Supply user confirmation that existing `glats` and non-privileged `shrike` can log in and browse music/original files, without disclosing credentials. Prefer user-operated confirmation; an agent login requires explicit permission to create sessions and privately available credentials. Do not request passwords in artifacts or chat.

WARNING: No trustworthy baseline proves original password/hash, session/link, or historical privilege preservation. If stronger historical proof is required, provide an authorized protected baseline for internal metadata comparison only; no sensitive output and no secret decryption.

WARNING: Independent full offline verification remains blocked by incomplete tasks. Once acceptance tasks are genuinely complete, rerun scoped formatting/evaluation and relevant configured gates under authorization; do not mark login done to bypass the gate. Negative-source and failure-path scenarios still lack passing covering execution evidence.

WARNING: Missing-source manual acceptance gate and residual mount-loss race remain. Current source availability is proven after deployment only; no fail-closed startup or pre-action preflight is claimed.

SUGGESTION: None; no scope expansion or fixes attempted.

### Verdict

BLOCKED for full SDD acceptance; deployed mount, source/readability, HTTP health, no-bootstrap/SOPS, and safe current-account metadata checks PASS. Not ready for archive. No archive or settlement performed.
