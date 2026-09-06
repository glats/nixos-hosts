# Archive Report: gentle-ai-v2-5-0-alignment

**Change:** gentle-ai-v2-5-0-alignment
**Archived:** 2026-09-06
**Archive path:** `openspec/changes/archive/2026-09-06-gentle-ai-v2-5-0-alignment/`
**Mode:** hybrid (openspec filesystem + Engram observation)

## What Shipped

Commit `e8b195c` (`feat(gentle-ai): pin v2.5.0 + permission-only agent grants`) implements the change: `gentle-ai-src` pinned to tag `v2.5.0` (`f5dd1a6c`) with `vendorHash` recomputed, four managed plugin lifecycle options (`modelVariants`, `opencodeReviewTransport`, `sddTaskResultArtifacts`, `skillRegistry` — the latter two on by default), `backgroundAgents`/`background-agents.ts` removed with an unconditional activation-time legacy `rm`, agent merging migrated from deprecated `tools` to `permission`-shaped grants via `smartMerge` + `stripReplace`, and `docs/gentle-ai-update.md` rewritten to the tagged v2.x workflow. `e8b195c` is an ancestor of `origin/master`; follow-up `18e5fe4` (archive of 7 stale changes) is also pushed.

## Verify Outcome

`verify-report.md` carries the admitted `gentle-ai.verify-result/v1` envelope (`evidence_revision sha256:3a1de0f8…`, `test_output_hash sha256:e74d452a…`, `build_output_hash sha256:241f17ad…`), admitted via `gentle-ai sdd-verify-validate`:

- `verdict: pass_with_warnings`, `blockers: 0`, `critical_findings: 0`
- `requirements: 6/6`, `scenarios: 7/7`
- Build PASS (both derivations + t14 activation package + asset and jq gates); Tests PASS (`go -C pkgs/nixos-scripts test ./...`, `format-nix --check`, `nix flake check --no-build` all exit 0)

No CRITICAL findings — archive proceeds.

## Standing Warning (single)

The evaluator cannot reach t14 over SSH; its live deployment is **user-attested**. Rog is the machine-verifiable live canary (post-deployment: exactly 11 `gentle-sdd-*.md`, no bare `sdd-*.md`, no legacy/disabled plugin files). This is the only open observability limitation at close; it does not block any requirement or scenario.

## Task Completion Gate

All 13 implementation tasks are marked `[x]` in the archived `tasks.md` (including user-gated Phase 6: `6.1` commit `e8b195c` pushed; `6.2` user deployed rog + t14 canary, `e8b195c` and `18e5fe4` ancestors of `origin/master`). No stale unchecked implementation tasks — gate passes, no reconciliation needed.

## Spec Sync

| Domain | Action | Details |
|--------|--------|---------|
| gentle-ai-declarative-runtime | Created (NEW) | Full canonical spec; 6 requirements / 7 scenarios. Delta spec was authored flat (`openspec/changes/gentle-ai-v2-5-0-alignment/spec.md`, no `specs/<domain>/` subdir) and IS a full spec (no ADDED/MODIFIED/REMOVED/RENAMED sections); no main spec existed, so it was copied mechanically to `openspec/specs/gentle-ai-declarative-runtime/spec.md` (byte-identical, mode normalized to 0644). Capability name taken from the proposal's New Capabilities section. |

## Follow-ups (documented, not part of this change)

- **sdd-research model gap**: `shared/opencode/agents.nix` `sddPhases` omits `sdd-research`, so that agent gets no per-phase model assignment. Pre-existing, explicitly out of scope (spec Out of Scope + exploration Risks). Candidate for a future change.
- **Theme component**: user-chosen deferral (decorative only; exploration recommendation (d)).
- **Worktree `sdd/rog-hyprland-server-parallel`**: parallel SDD change in `.worktrees/sdd/rog-hyprland-server-parallel` (branch `sdd/rog-hyprland-server-parallel`); cleanup deferred by user, unrelated to this change.

## Mechanical Copy Verification

Spec sync (`cp` → temp → `diff -r` → `mv`): `diff_status=0` — **empty diff (PASS)**.
Archive move: `git mv` (fallback `mv` not needed); post-move check confirmed the source directory is gone; MANDATORY `diff -r` of the pre-move recursive snapshot vs. the archived destination returned an **empty diff (PASS)** — byte identity preserved for all 6 artifacts. `archive-report.md` is additive-only and was not in the source snapshot.

## Git State at Close (not committed — user-initiated commit per repo convention)

- Staged: rename of 5 tracked artifacts to `openspec/changes/archive/2026-09-06-gentle-ai-v2-5-0-alignment/`; new file `verify-report.md` (was untracked; staged so the directory `git mv` could move the whole folder); new canonical spec `openspec/specs/gentle-ai-declarative-runtime/spec.md`.
- Unstaged: `tasks.md` content modification (reconciled 13/13) at the archived path.
- Untouched pre-existing state: `.atl/skill-registry.md` modified, `.atl/.skill-registry.cache.json` untracked, `openspec/changes/ai-backup-manifest-scope/` untracked.

## Engram Traceability

Persisted as `sdd/gentle-ai-v2-5-0-alignment/archive-report` (hybrid mode). Artifact observations read during this archive phase:

- `#2326` explore
- `#2327` proposal
- `#2328` spec
- `#2329` design
- `#2331` tasks
- `#2332` apply-progress
- `#2368` verify

## Validation

- `nix flake check --no-build`: not re-run in archive phase (no production code touched; per repo policy the change's own verify gate already passed and no Nix files were edited by this phase).
- No production code, `.atl` files, or other changes were touched.