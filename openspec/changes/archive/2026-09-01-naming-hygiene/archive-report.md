# Archive Report: naming-hygiene

## Change Summary
OPSEC naming hygiene: renamed the mact2↔rog private-link stack to neutral infrastructure
language (bin/opencode-home, bin/device-link, `sing-box-link.nix` server/client,
`link.*` options, launchd `org.nixos.sing-box`, `/var/log/sing-box.log`,
`secrets/shared/link-uuids.yaml`, `link/uuid_*` sops decls, `docs/home-link.md`) and
neutralized sensitive vocabulary in comments/docs across the repo. Merged to master via
commit `cd72118` ("refactor(naming): neutralize sensitive identifiers"). Includes the
folded-in urltest safe-default reorder (`outbounds = ["direct" "home-out"]`).

## Archive Mode
Hybrid (filesystem + Engram)

## Artifact Observation IDs

| Artifact | Engram ID | Type |
|----------|-----------|------|
| proposal | (Engram proposal not found — see note) | — |
| tasks | (Engram tasks not found — see note) | — |
| apply-progress | #2233 | architecture |
| follow-up decision (manual daemon) | #2234 | decision |
| round-2 verify discovery | #2237 | discovery |

Note: Engram search returned no `sdd/naming-hygiene/{proposal,tasks}` observations; the
filesystem `proposal.md`/`tasks.md` are the authoritative artifacts for this change. This
is an intentional partial archive of Engram observations, not of work.

## Specs Synced
None. This change is proposal + tasks only (no `specs/` directory). Archive moves the
folder without a spec sync, per the launch instructions.

## Archive Contents
| File | Status |
|------|--------|
| proposal.md | ✅ |
| tasks.md | ✅ (32/32 tasks complete, reconciled) |
| archive-report.md | ✅ (this file, additive) |

No design.md, specs/, or verify-report.md was ever created for this change (proposal+tasks
only; final-state evidence in `mact2-openai-tls-tunnel-via-rog/verify-report.md` V-A–V-F
round-2).

## Stale Checkbox Reconciliation (exceptional repair)
Phase 7 USER-RUN tasks were substantively completed before close (see reconciliation note
at top of tasks.md): 7.1 sops rename (link-uuids.yaml tracked, old opencode-tunnel.yaml
absent — verify V-E); 7.2 deploys (production office traffic flowed — verify R3);
7.3 daemon rename (org.nixos.sing-box evaluated — verify V-C); 7.4 branch deletion is an
orchestrator step and the branch is already absent. Marked `[x]` with reconciliation note.

## Review Gate
No structured review context (`reviewGate`) discovered for this change. Informational;
archive proceeded under ordinary repository policy with the Task Completion Gate passed.

## Source of Truth Updated
None — no main spec is associated with this change.

## SDD Cycle Complete
The change has been fully planned, implemented, merged, verified, and archived.
