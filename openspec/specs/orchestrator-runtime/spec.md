# orchestrator-runtime Specification

## Purpose

Requirements for the orchestrator runtime asset (`sdd-orchestrator.md`), specifically the Review-Checkpoint Gate control flow.

## Requirements

### ORC-RC-001: Review-Checkpoint Gate Section

`sdd-orchestrator.md` MUST contain a section named `Review-Checkpoint Gate
(MANDATORY)`, positioned after the existing `Apply-Progress Continuity
(MANDATORY)` section. The section MUST be marked as non-optional (e.g. with
`(MANDATORY)` in the heading) so that it cannot be treated as advisory by the
runtime.

#### Scenario: Section exists at correct position

- GIVEN `sdd-orchestrator.md` is loaded at runtime
- WHEN the orchestrator processes a session after `sdd-apply` returns
- THEN the `Review-Checkpoint Gate (MANDATORY)` section is present in the
  loaded asset and appears after `Apply-Progress Continuity (MANDATORY)`

#### Scenario: Section is absent before this change

- GIVEN `sdd-orchestrator.md` without the `Review-Checkpoint Gate` section
- WHEN an `sdd-apply` slice completes
- THEN no deterministic routing block enforces the gate
- AND the source counterpart MUST be updated to include the section so the fix
  survives a `nixos-build` re-deploy

### ORC-RC-002: Checkpoint Lookup After Every Apply Slice

After every `sdd-apply` slice returns, the orchestrator MUST locate and read
the `review-checkpoint` artifact for the active change before launching any
subsequent `sdd-apply` or `sdd-verify`. This lookup is NOT optional and MUST
NOT be skipped regardless of apply outcome.

#### Scenario: Apply succeeds — gate still runs

- GIVEN an `sdd-apply` slice completes with status `success`
- WHEN the orchestrator receives the result
- THEN it locates the `review-checkpoint` before launching the next phase
- AND does NOT proceed to `sdd-verify` before reading the checkpoint

#### Scenario: No checkpoint found — hard stop

- GIVEN no `review-checkpoint` artifact exists for the active change
- WHEN the orchestrator looks up the checkpoint
- THEN it STOPS and reports "no review-checkpoint found"
- AND MUST NOT advance to the next phase

### ORC-RC-003: Artifact-Store-Aware Checkpoint Lookup

The gate lookup MUST resolve the checkpoint artifact according to the active
artifact store mode, using the same routing pattern established by the
`opencode-sdd-artifact-store-alignment` change.

| Mode | Lookup method |
|---|---|
| `openspec` or `hybrid` | Read `openspec/changes/{change}/review-checkpoint.md` |
| `engram` or `hybrid` | `mem_search("sdd/{change}/review-checkpoint")` then `mem_get_observation` |

For `hybrid`, BOTH lookups MUST be performed. The `openspec` result is
canonical for file-based state; the `engram` result supplements it.

#### Scenario: openspec mode resolves file

- GIVEN artifact store mode is `openspec`
- AND `openspec/changes/{change}/review-checkpoint.md` exists
- WHEN the orchestrator runs the gate
- THEN it reads the file as the checkpoint source
- AND MUST NOT attempt an Engram search

#### Scenario: engram mode resolves memory

- GIVEN artifact store mode is `engram`
- AND the change exists only in Engram (no openspec directory)
- WHEN the orchestrator runs the gate
- THEN it calls `mem_search("sdd/{change}/review-checkpoint")` and then
  `mem_get_observation` to get the full artifact
- AND MUST NOT treat a missing file as an error

#### Scenario: hybrid mode uses both stores

- GIVEN artifact store mode is `hybrid`
- WHEN the orchestrator runs the gate
- THEN it performs both the file read and the Engram search
- AND reconciles results (openspec file is canonical for file state)

#### Scenario: Unknown store mode halts

- GIVEN artifact store mode is unrecognized or absent
- WHEN the orchestrator attempts checkpoint lookup
- THEN it STOPS and reports the unrecognized mode rather than proceeding

### ORC-RC-004: Deterministic Verdict Routing

After reading the checkpoint, the orchestrator MUST apply the following
verdict decision table without discretion. No additional heuristics or
intermediate states are permitted.

| Verdict | Action |
|---|---|
| `approved` | Continue to next phase (`sdd-verify` or next apply slice) |
| `proceed` | Continue to next phase (escape hatch; record verdict as `proceed`) |
| `changes-requested` | STOP; present binary decision |
| `blocked` | STOP; present binary decision |
| `pending` | STOP; present binary decision |
| missing / unreadable | STOP; report "no review-checkpoint found" |

The orchestrator MUST NOT invent an intermediate action (e.g. inline fix,
partial rework, silent continue) that is not in this table.

#### Scenario: Approved continues

- GIVEN review-checkpoint verdict is `approved`
- WHEN the orchestrator reads the checkpoint
- THEN it launches `sdd-verify` without asking the user

#### Scenario: Changes-requested halts

- GIVEN review-checkpoint verdict is `changes-requested`
- WHEN the orchestrator reads the checkpoint
- THEN it STOPS, MUST NOT auto-advance, and presents the binary decision

#### Scenario: Blocked halts

- GIVEN review-checkpoint verdict is `blocked`
- WHEN the orchestrator reads the checkpoint
- THEN it STOPS and presents the binary decision; behavior identical to
  `changes-requested`

#### Scenario: Pending halts

- GIVEN review-checkpoint verdict is `pending`
- WHEN the orchestrator reads the checkpoint
- THEN it STOPS and presents the binary decision; does not assume the review
  will resolve in the affirmative

### ORC-RC-005: Binary Decision Presentation

When the gate requires a stop (verdicts: `changes-requested`, `blocked`,
`pending`, or missing), the orchestrator MUST present exactly two options to
the user via the `question` tool or equivalent interactive prompt:

1. **full-iteration** — re-explore → re-apply (reads all previous artifacts as
   context; each phase overwrites its artifact)
2. **proceed** — skip the gate; record verdict as `proceed` and continue to
   the next phase

The orchestrator MUST NOT offer a third option (e.g. inline fixes, partial
rework) at this gate. Rationale: a failed review indicates the approach needs
re-examination; partial fixes without re-exploration lead to invented solutions.
This rule is consistent with `RP-002` in the `review-gates` spec.

#### Scenario: Binary decision presented — changes-requested

- GIVEN review-checkpoint verdict is `changes-requested`
- WHEN the orchestrator reads the checkpoint
- THEN it presents exactly two options: `full-iteration` and `proceed`
- AND no third option (inline fix, partial rework) is offered

#### Scenario: Binary decision presented — blocked

- GIVEN review-checkpoint verdict is `blocked`
- WHEN the orchestrator reads the checkpoint
- THEN it presents exactly two options: `full-iteration` and `proceed`

#### Scenario: Binary decision presented — missing checkpoint

- GIVEN no `review-checkpoint` artifact found
- WHEN the orchestrator runs the gate
- THEN it reports "no review-checkpoint found" and presents `full-iteration`
  or `proceed` as recovery options

### ORC-RC-006: Verify Gate Hard Block

The orchestrator MUST NOT launch `sdd-verify` unless the latest
`review-checkpoint` for the active change has verdict `approved` or `proceed`.
This constraint applies even when the user has not explicitly asked for a
review check.

#### Scenario: Verify blocked without checkpoint

- GIVEN no passing review-checkpoint exists
- WHEN the orchestrator is about to launch `sdd-verify`
- THEN it MUST run the gate first and MUST NOT bypass it
- AND if the gate returns a stop condition, verify is not launched

#### Scenario: Verify allowed after approved

- GIVEN review-checkpoint verdict is `approved`
- WHEN the orchestrator evaluates the gate before `sdd-verify`
- THEN it launches `sdd-verify` immediately

### ORC-RC-007: Source File Parity

The `Review-Checkpoint Gate (MANDATORY)` section MUST be present in both:

1. `~/.config/opencode/sdd-orchestrator.md` (deployed runtime — primary
   behavioral surface)
2. `shared/opencode/assets/opencode/sdd-orchestrator.md` (source — required
   for rebuild durability via the Nix deployment pipeline)

If the source file is not updated, the next `nixos-build` run will overwrite
the runtime file and remove the gate.

#### Scenario: Runtime file modified — source also modified

- GIVEN the `Review-Checkpoint Gate` section is added to the runtime file
- WHEN the source file (`shared/opencode/assets/opencode/sdd-orchestrator.md`)
  is inspected
- THEN it contains the identical section

#### Scenario: Nix rebuild preserves the gate

- GIVEN both runtime and source files contain the `Review-Checkpoint Gate`
  section
- WHEN `nixos-build` runs and the activation script deploys the runtime file
- THEN the deployed `~/.config/opencode/sdd-orchestrator.md` still contains
  the section
