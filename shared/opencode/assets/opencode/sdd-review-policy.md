# SDD Review Policy + Iteration Protocol

This policy applies to **every SDD change in this workspace**, including future
changes that do not restate it in their own specs.

## SDD Workflow

```
explore -> propose -> spec -> design -> tasks -> apply  [AUTOMATIC]
                                                  |
                                                review
                                                  |
                              -------------------+-------------------
                              |                                      |
                             done                                  amend
                              |                                      |
                          verify                          ASK USER:
                                                         reiterate or redo?
                                                              |
                                              ----------------+---------------
                                              |                               |
                                         reiterate                        redo
                                    (re-explore -> re-apply)          (re-apply only)
```

## Hard Gate After Every Apply Slice

After any successful `sdd-apply` slice, stop the implementation loop and do
all of the following before any next apply:

1. **Commit and push** every affected repository/branch for that slice.
2. **Ensure the GitHub diff or PR is visible** for every affected repository.
3. **Update `apply-progress`** with repo / branch / commit / PR info for the slice.
4. **Record a `review`** for the current bundle verdict.

Do **not** start the next apply slice until the latest review says either `done`
or explicit `redo`.

If the latest review says `amend`, or is missing / unclear, implementation
**must** stop.

## Iteration Protocol

When the review verdict is `amend`, the orchestrator presents the user with a
BINARY decision:

1. **Reiterate** (high uncertainty): Full cycle from explore to apply.
   Re-explore with all previous artifacts + review feedback as context.
   Rebuild proposal, specs, design, tasks, and re-apply. Overwrites artifacts
   via `topic_key` upsert (Engram) or file overwrite (OpenSpec). Old approach is
   context, not discarded.
2. **Redo** (low uncertainty): Re-apply directly. The spec and design are solid;
   the change is small and well-understood. The agent adjusts tasks implicitly.
   No need to revisit propose/spec/design.

Inline-fixes is **not** an option. If an apply slice failed review, the approach
needs re-examination -- not partial fixes.

**Decision caching**: once the user chooses for a change, the orchestrator reuses
that decision for subsequent review gates in the same change without re-presenting.

## Reiterate Protocol

When `reiterate` is chosen:
- The sub-agent MUST read ALL existing artifacts as context: proposal, specs,
  design, tasks, apply-progress, review.
- Builds on known facts, not from scratch.
- Each phase overwrites its artifact (`topic_key` upsert / file overwrite).
- The review from the failed iteration is preserved separately -- NOT
  overwritten by new iterations.
- Old approach preserved in Engram history / git history.
- Re-explore through re-apply is **AUTOMATIC** -- no user questions between phases.

## Guard Lines (Review)

Every `review` artifact MUST include these guard lines, which the orchestrator
reads to drive its decision point:

```
Rework level: explore|design|tasks|none
Iteration decision needed: Yes|No
```

- `Rework level` tells a reiterate which phase to restart from.
- `Iteration decision needed: Yes` triggers the iteration prompt to the user.
- `Iteration decision needed: No` means the review is informational only.

## Verify Gate

Do **not** run `sdd-verify` until the latest review says `done` or explicit `redo`.

## Redo Escape Hatch

The user MAY say `redo` at any review gate. The orchestrator MUST record `redo`
as the verdict and continue to the next phase (apply, verify, or re-apply).

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
