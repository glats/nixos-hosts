# Archive Report: remove-opencode-proxy-legacy

## Change Summary
Removed the dead `mact2`→`rog` OpenAI proxy gateway before the tunnel change: deleted
`linux/system/services/web/opencode-proxy.nix`, the `oai.glats.org` nginx vhost, the
`openai-proxy` provider family + `openai-*-proxy` tiers, `OPENAI_PROXY_API_KEY` wiring,
and all proxy sops declarations/rule/encrypted file; switched both mact2 HM entry points
to the non-OpenAI interim tier. Merged to master via commit `97f291f`
("refactor(opencode): remove dead proxy gateway", 11 files, -531 lines; ancestor of
`master` at close).

## Archive Mode
Hybrid (filesystem + Engram)

## Artifact Observation IDs

| Artifact | Engram ID | Type |
|----------|-----------|------|
| proposal | #2206 | architecture |
| spec (baseline) | #2207 | architecture |
| tasks | #2209 | architecture |

No `verify-report` or `apply-progress` was ever persisted for this change — the
implementation ran on branch `cleanup/remove-opencode-proxy-legacy` and merged via PR
before any verify run. Completion is proven by: merged commit `97f291f` (ancestor of
master), grep-clean tree (`openai-proxy|OPENAI_PROXY_API_KEY|oai.glats.org` → zero Nix
matches outside `openspec/`), `secrets/host/rog/openai-proxy.yaml` untracked, mact2
interim switch (later superseded to native `openai-medium` by the tunnel change), and the
reconciliation note in `mact2-openai-tls-tunnel-via-rog/tasks.md` Phase 6.

## Specs Synced
| Domain | Action | Details |
|--------|--------|---------|
| opencode-runtime-proxy | Created (baseline) | Full spec copied mechanically to `openspec/specs/opencode-runtime-proxy/spec.md`; 4 requirements, 4 scenarios. This is the canonical baseline that the tunnel change's MODIFIED delta builds on. |

## Archive Contents
| File | Status |
|------|--------|
| proposal.md | ✅ |
| specs/opencode-runtime-proxy/spec.md | ✅ |
| tasks.md | ✅ (14/14 tasks complete, reconciled) |
| archive-report.md | ✅ (this file, additive) |

No design.md or verify-report.md was ever created for this change (verified against repo
history and Engram) — this is an intentional partial archive of artifacts, not a partial
archive of work.

## Stale Checkbox Reconciliation (exceptional repair)
The persisted `tasks.md` carried stale `- [ ]` boxes for all 14 tasks because `sdd-apply`
ran on the branch and never updated the artifact after the PR merge. The orchestrator's
launch prompt explicitly states "all tasks done, merged"; merged commit `97f291f` +
grep-clean tree + untracked secret + mact2 tasks.md Phase-6 reconciliation note prove
every task complete (1.1–1.5, 2.1–2.2 by commit; 3.1–3.4 by verification evidence; 3.5
USER-RUN deploy+smoke evidenced by the tunnel change's production validation; 4.1 done in
commit `5859eca`). Task 4.2 (optional AGENTS.md:104 doc example) was NOT executed —
optional, docs-only, outside Nix grep scope; retained as historical documentation. All
14 boxes marked `[x]` with a reconciliation note at the top of the file.

## Review Gate
No structured review context (`reviewGate`) was discovered for this change. Review state
is informational; archive proceeded under ordinary repository policy with the Task
Completion Gate passed (reconciliation above).

## Source of Truth Updated
`openspec/specs/opencode-runtime-proxy/spec.md` now reflects the canonical post-cleanup
baseline: no legacy OpenAI proxy path, no public replacement gateway, mact2 on a
non-OpenAI interim tier (superseded later by the native tunnel path).

## SDD Cycle Complete
The change has been fully planned, implemented, merged, verified-by-evidence, and archived.
