# Archive Report: atl-skill-registry-host-local

**Change:** atl-skill-registry-host-local
**Archived:** 2026-09-08
**Archive path:** `openspec/changes/archive/2026-09-08-atl-skill-registry-host-local/`
**Status:** Completed — verification verdict `PASS`, READY-TO-ARCHIVE
**Mode:** hybrid (openspec filesystem archive + Engram task/apply-progress store updates)

## Review Verdict

**PASS** — 6/6 tasks complete, independent verification PASS (per orchestrator launch prompt,
final state at close). No CRITICAL findings. This change declared NO spec deltas
("New Capabilities: None / Modified: None"), so there was nothing to sync into `openspec/specs/`.

## Task Completion

All 6 persisted tasks are checked `[x]` in the archived `tasks.md` (no unchecked implementation
tasks):

- **Phase 1 — Linux** (T1): added `# Local AI runtime state` heading + `.atl/` to repo-root
  `.gitignore`; `git rm -r --cached .atl`; single fix-forward commit
  `chore(atl): keep skill-registry host-local — gitignore .atl/ and untrack it`; pushed.
- **Phase 2 — mact2** (T2): pulled shared branch on mact2, cleared stale cache, forced refresh so
  the stale Linux md became a `/Users/jcuzmar/...` registry.
- **Phase 3 — Verification** (T3 Linux, T4 mact2, T5 fresh-clone): per-host ignore + cleanliness +
  content checks passed; fresh clone regenerates `.atl/` and stays clean.
- **Cross-cutting** (C1): no `.nix` files changed; derivations and `shared/opencode/runtime-config.nix`
  untouched; no secrets decrypted; history never rewritten.

## Summary

The ATL skill registry (`.atl/` — machine-generated, host-specific skill index) is now host-local.
The repo no longer tracks `.atl/skill-registry.md`; each checkout regenerates its own registry via
the OpenCode startup `/skill-registry` refresh without Git churn. This resolves the cross-host
divergence where mact2 carried a stale Linux-generated registry frozen by cache-hit behavior.

Implemented in commit `73e071f` (`chore(atl): keep skill-registry host-local — gitignore .atl/ and
untrack it`).

## Spec Sync

| Domain | Action | Details |
|--------|--------|---------|
| (none) | N/A | This change declared NO delta specs ("New Capabilities: None / Modified: None"). No `specs/` directory existed in the change folder and nothing was synced into `openspec/specs/`. |

## Mechanical Copy Verification

- Change folder moved with `git mv` to `openspec/changes/archive/2026-09-08-atl-skill-registry-host-local/`;
  MANDATORY `diff -r` readback of the pre-move recursive snapshot vs. the archived destination
  returned an **empty diff (PASS)** — byte identity preserved. `archive-report.md` is additive-only
  and was not in the source snapshot.

## Validation

- No `openspec` CLI exists in the repo; the openspec archive convention is validated by the
  mechanical `diff -r` readback above (empty) plus the archive structure checks:
  active `openspec/changes/atl-skill-registry-host-local/` is gone; archived folder contains
  `exploration.md`, `proposal.md`, and `tasks.md` (6/6 checked).
- Engram task (2459) and apply-progress (2460) observations updated to note ARCHIVED (evidence
  retained, not deleted).

## Outstanding

- None mandatory. The optional upstream follow-ups noted in the proposal (report stale-md /
  portability behavior; document `EnsureATLIgnored` defaults) remain out of scope and require
  separate approval.
