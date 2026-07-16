# SDD Review Policy + Iteration Protocol

This policy applies to **every SDD change in this workspace**, including future
changes that do not restate it in their own specs.

## SDD Workflow

```
explore -> propose -> spec -> design -> tasks -> apply
                                                   |
                                              review gate
                                                   |
                              +-------------------+-------------------+
                              |                   |                   |
                            done               retry             reiterate
                              |                   |                   |
                          verify             re-apply          re-explore
                              |              (same spec,      (full cycle:
                          archive             same design)      explore ->
                                                               propose ->
                                                               spec ->
                                                               design ->
                                                               tasks ->
                                                               apply)
```

## Review Gate (After Every Apply)

After every successful `sdd-apply` slice, the orchestrator MUST:

1. **Commit and push** every affected repository/branch for that slice.
2. **Ensure the GitHub diff or PR is visible** for every affected repository.
3. **Update `apply-progress`** with repo / branch / commit / PR info for the slice.
4. **Present the user with exactly THREE options** via the `question` tool:

| Option | Action | Use when |
|--------|--------|----------|
| `done` | Continue to verify -> archive | The change is correct |
| `retry` | Re-apply only (same spec, same design). The agent adjusts tasks and re-applies. | Small fix, well-understood |
| `reiterate` | Full SDD cycle from explore. Reads all artifacts as context, overwrites each phase. | Large rework, needs rethinking |

5. **Record the chosen verdict** as the review artifact.

Do NOT offer a fourth option. Do NOT auto-advance. Do NOT launch `sdd-verify`
unless the verdict is `done`.

Inline-fixes is **not** an option. If apply needs changes, the approach needs
re-examination -- not partial fixes.

## Retry (Re-apply Only)

When `retry` is chosen:
- The sub-agent re-reads spec, design, and tasks as context.
- Adjusts implementation and re-applies directly.
- Does NOT re-explore, re-propose, re-spec, or re-design.
- Overwrites the apply-progress artifact.

## Reiterate (Full SDD Cycle)

When `reiterate` is chosen:
- The sub-agent MUST read ALL existing artifacts as context: proposal, specs,
  design, tasks, apply-progress, review.
- Builds on known facts, not from scratch.
- Re-runs explore -> propose -> spec -> design -> tasks -> apply.
- Each phase overwrites its artifact.
- Old artifacts are preserved in Engram history / git history.
- The full cycle is **AUTOMATIC** -- no user questions between phases.

## Verify Gate

Do **not** run `sdd-verify` unless the review verdict is `done`.

## Artifact Expectations

When the active artifact store is OpenSpec or Hybrid:
- `openspec/changes/{change}/apply-progress.md`
- `openspec/changes/{change}/review.md`

When the active artifact store is Engram or Hybrid:
- `sdd/{change}/apply-progress`
- `sdd/{change}/review`

## Orchestrator Expectations

Before any later `sdd-apply` or `sdd-verify`, reread: proposal, specs, design,
tasks, apply-progress, review.

## Priority

This policy is global and transversal. It applies even when a specific SDD
change forgets to restate it.
