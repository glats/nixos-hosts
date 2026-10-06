# Proposal: Declarative Droppy Music, Preserved Native Accounts

## Intent

Expose music read-only in Droppy on `rog` through Nix, preserving native accounts. Only music is declarative: existing `shrike` and `glats` remain in persistent `/srv/glats/droppy/config/db.json`; neither is reproducible from Nix. The confirmed handoff resolves exploration's credential clarification.

## Scope

### In Scope
- Retain `/run/media/library/music:/files/music:ro` and existing volumes.
- In apply, remove accidental `sops.secrets.droppy-users`, account-seeding `docker-droppy.preStart`, encrypted seed, and adjacent Python test, scoped strictly to this work.
- Verify configuration without activation; preserve native accounts and unrelated dirty changes.

### Out of Scope
- Account creation, updates, deletion, password persistence, secret decryption, or Nix/SOPS provisioning.
- Service/image upgrades, permission cleanup, nginx changes, library filesystem changes, staging, or commits.
- Deployment and runtime verification without separate user authorization.

## Capabilities

### New Capabilities
- `droppy-music-access`: `rog` read-only music exposure, native-account preservation, and bounded verification/deployment gates.

### Modified Capabilities
None. Existing main specs contain no Droppy capability.

## Approach

Follow exploration's recommendation without repeating account creation. Keep `/config` persistence and `/files` data. Music is exposed through Droppy, not nginx aliases.

`hosts/rog/default.nix` declares `/run/media/library` as an ext4 mount with `defaults`. Design must check generated startup ordering and missing-source behavior; use only a narrowly necessary mount dependency/source guard if needed. Do not create fallback directories or redesign storage. Missing source blocks authorized deployment acceptance.

Use evaluated volumes/unit output as proof. Optional synthetic fixtures run only in a sandbox or `/home/glats/.local/opencode-v2/tmp/opencode`, never beside Nix modules or against live credentials.

## Affected Areas

| Path | Impact |
|------|--------|
| `linux/system/services/web/droppy.nix` | Keep music; remove rejected provisioning |
| `secrets/host/rog/droppy-users.json` | Remove accidental untracked seed |
| `linux/system/services/web/droppy.test.py` | Remove rejected-mechanism test |
| `hosts/rog/default.nix` | Topology reference only |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Missing source exposes empty music | Medium | Check mount ordering; gate deployment |
| Unrelated dirty work affected | Medium | Path/hunk-scoped cleanup and review |
| Account state lost | Low | No DB writes; persistent config retained |

## Rollback Plan

Remove only the music volume; authorized deployed rollback uses the previous generation. Never restore rejected provisioning or overwrite/delete accounts. Leave music data untouched.

## Dependencies

- Existing library mount and music directory; separate apply/deployment approval.

## Success Criteria

- [ ] Scoped cleanup complete; unrelated changes preserved.
- [ ] Touched-module formatting, `rog` toplevel evaluation, and generated volume/unit checks pass after cleanup.
- [ ] No account provisioning or credential output remains.
- [ ] Stop after bounded offline proof; report runtime acceptance pending.
- [ ] Only after authorized deployment: music browsable read-only; existing non-privileged `shrike` and unchanged `glats` verified without disclosing credentials.
