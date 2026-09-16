# Archive Report: Harden macm5 Apple Silicon Onboarding

## Archive State

- Change: `harden-macm5-apple-silicon-onboarding`
- Archive date: `2026-09-16`
- Archive disposition: `intentional-with-warnings`
- Artifact store: hybrid (OpenSpec filesystem plus Engram archive report)
- Archived path: `openspec/changes/archive/2026-09-16-harden-macm5-apple-silicon-onboarding/`

This is an intentional partial archive authorized by the user. Tasks 1.1, 1.2, and 1.3 remain unchecked because the preflight, lifecycle, and retirement-guard harnesses were not implemented and were excluded from the maintainer-approved evidence-gated retirement slice. They are recorded as pending/excluded, not falsely marked complete. The archived task register therefore reports 11 of 14 tasks complete.

The native retirement evidence is accepted with its stated limitation: commit `5ac16d9` pushed the mact2 retirement; an authorized SOPS owner subsequently removed `uuid_mact2` and re-encrypted the link UUID ciphertext; rog was deployed; and mact2 was enterprise-formatted, making direct failed-auth probing impossible. Task 4.2 is checked on that accepted deployment evidence, with the limitation recorded. Recovery remains restricted to macm5 Git, generation, and identity state. No encrypted secret content was inspected.

No known CRITICAL verification issues were reported. The native status command still reported archive blocked because the persisted task plan names `/nix` outside the authorized edit roots and no filesystem `verify-report.md` exists; these are recorded facts, not silently corrected. The explicit partial-archive authorization permits this intentional-with-warnings archive without changing the unchecked tasks or fabricating a verification artifact.

## Specs Synced

| Domain | Action | Details |
|---|---|---|
| `tunnel-device-onboarding` | Updated | Replaced the lifecycle requirement with macm5-first provisioning and post-acceptance mact2 revocation; added scenarios for replacing the identity and blocking premature revocation. Existing runtime-only Android delivery requirements were preserved. |
| `darwin-host-retirement` | Created | Mechanically copied the complete delta as the new canonical spec. |
| `macm5-apple-silicon-onboarding` | Created | Mechanically copied the complete delta as the new canonical spec. |

Canonical specs now updated:

- `openspec/specs/tunnel-device-onboarding/spec.md`
- `openspec/specs/darwin-host-retirement/spec.md`
- `openspec/specs/macm5-apple-silicon-onboarding/spec.md`

## Archived Contents

The pre-move change tree was snapshotted and moved mechanically with `git mv`. It contains `exploration.md`, `proposal.md`, `specs/`, `design.md`, `tasks.md`, and `apply-progress.md`. The archive report is additive and was created after the snapshot, so it is excluded from the identity comparison.

## Mechanical Readback

Delta-to-canonical copy readbacks used `diff -r` for `darwin-host-retirement` and `macm5-apple-silicon-onboarding`; both produced no output before the destination move.

Archive move readback:

```text
<empty output>
```

The command was:

```text
diff -r "$snapshot_root/source" "openspec/changes/archive/2026-09-16-harden-macm5-apple-silicon-onboarding"
```

It returned status 0 with verbatim empty output. The active change directory no longer exists.

## Verification Notes

- `git diff --check` passes.
- The final-state facts above supersede intermediate evidence snapshots where they differ.
- The repository's encrypted link UUID content was not read or modified during this archive operation.
- Unrelated untracked change directories were preserved.

## Pending / Excluded Work

- 1.1: preflight harness for fresh Determinate-only state, `/nix`, daemon socket, and PATH — pending/excluded.
- 1.2: lifecycle and failed-auth/leakage harness — pending/excluded.
- 1.3: retirement guard test — pending/excluded.

These tasks remain available for a separately authorized follow-up change; this archive does not claim the SDD cycle is fully complete.
