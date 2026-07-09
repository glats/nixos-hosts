# Delta for Review Gates

## MODIFIED Requirements

### RP-001: Review Hard Gate

The orchestrator MUST stop after every successful `sdd-apply` slice, update
`apply-progress`, and record a `review-checkpoint` with a verdict. The orchestrator
MUST NOT launch `sdd-verify` or the next apply slice until the verdict is `done` or
`redo`. Verdicts: `done`, `amend`, `reiterate`, `redo`.

#### Scenario: Done proceeds

- GIVEN review-checkpoint verdict `done`
- WHEN orchestrator reads the checkpoint
- THEN it launches `sdd-verify`

#### Scenario: Amend halts

- GIVEN review-checkpoint verdict `amend`
- WHEN orchestrator reads the checkpoint
- THEN it STOPS and presents iteration options; MUST NOT auto-advance

#### Scenario: Missing checkpoint halts

- GIVEN no review-checkpoint found after apply
- WHEN orchestrator checks for a verdict
- THEN it STOPS and reports "no review-checkpoint found"

### RP-002: Iteration Decision Gate (Binary)

When the review-checkpoint indicates changes are needed, the orchestrator MUST present
exactly two options:

1. **reiterate**: re-explore -> re-apply (automatic, reads all previous artifacts)
2. **redo**: skip the gate, continue to verify

The orchestrator MUST NOT offer inline-fixes or partial rework. Rationale: if apply
failed review, the approach needs re-examination. Partial fixes without re-exploring
lead the agent to invent solutions.

#### Scenario: Binary decision presented

- GIVEN review-checkpoint with `amend`
- WHEN orchestrator reads it
- THEN exactly two options are presented: reiterate or redo

#### Scenario: Reiterate chosen

- GIVEN user chooses `reiterate`
- WHEN orchestrator launches re-explore
- THEN re-explore reads all previous artifacts as context

#### Scenario: Redo bypasses gate

- GIVEN user says "redo"
- WHEN orchestrator reads the directive
- THEN gate is bypassed and continue to next phase

### RP-003: Re-Explore Protocol

When `reiterate` is chosen, re-explore MUST read ALL existing artifacts: proposal,
specs, design, tasks, apply-progress, review-checkpoint. Each phase overwrites its
artifact. No new SDD change -- iteration stays within the same change. Re-explore
through re-apply is AUTOMATIC (no user questions between phases). The review-checkpoint
from the failed iteration is preserved as context.

#### Scenario: Builds on known facts

- GIVEN `reiterate` and existing artifacts
- WHEN re-explore launches
- THEN it reads ALL artifacts and builds on them, not from scratch

#### Scenario: Automatic pipeline

- GIVEN `reiterate` chosen
- WHEN orchestrator runs re-explore -> propose -> spec -> design -> tasks -> apply
- THEN it does NOT ask user between phases

### RP-005: Orchestrator-Asset Enforcement

The review-gate policy MUST be enforced via an explicit checkpoint-reading and routing
section in the orchestrator runtime asset (`sdd-orchestrator.md`). Instruction text
loaded as context is insufficient on its own. The policy MUST NOT require modifications
to SDD skills (`sdd-apply`, `sdd-verify`, etc.). Guard lines in the review-checkpoint
remain as the decision input:

```
Rework level: explore|design|tasks|none
Iteration decision needed: Yes|No
```

#### Scenario: Enforced from orchestrator asset

- GIVEN the `Review-Checkpoint Gate` section is present in `sdd-orchestrator.md`
- WHEN the orchestrator returns from an `sdd-apply` slice
- THEN it locates and reads the `review-checkpoint` artifact per store-mode lookup
  rules before launching any subsequent phase

#### Scenario: Instruction text alone does not suffice

- GIVEN `instructions/orchestrator.md` and `sdd-review-policy.md` are both loaded
  as context
- AND `sdd-orchestrator.md` has no `Review-Checkpoint Gate` section
- WHEN the orchestrator completes an `sdd-apply` slice
- THEN the gate MAY be silently bypassed because there is no deterministic routing
  block in the main asset

#### Scenario: Guard lines trigger user prompt

- GIVEN checkpoint has `Iteration decision needed: Yes`
- WHEN orchestrator reads the checkpoint
- THEN it presents exactly two options: reiterate or redo

### RP-006: Redo Escape Hatch

The user MAY say `redo` at any review gate. The orchestrator MUST record `redo` as
the verdict and continue to the next phase.

#### Scenario: Redo bypasses gate

- GIVEN checkpoint verdict is `amend`
- WHEN user says `redo`
- THEN verdict is recorded as `redo` and orchestrator launches next phase

#### Scenario: Redo at verify gate

- GIVEN user says `redo` before verify
- WHEN orchestrator checks the checkpoint
- THEN it launches `sdd-verify` regardless of prior verdict

## REMOVED Requirements

### Verdicts: blocked, pending

The verdicts `blocked` and `pending` MUST be removed from all active policy files
(`sdd-review-policy.md`, `sdd-orchestrator.md`, `instructions/orchestrator.md`).
These verdicts were never used in practice and their presence adds confusion.

(Reason: The user's preferred terminology set (done, amend, reiterate, redo) does
not include blocked or pending. Neither verdict had a distinct codepath -- both
behaved identically to amend (stop, present binary decision). Consolidating to
four verdicts simplifies the decision table and reduces cognitive load.)

(Migration: Review-checkpoint artifacts that reference blocked or pending in
existing sessions are treated as amend. The decision table in
`ORC-RC-004` is updated to map: `blocked`/`pending` -> STOP, present binary
decision (same as amend). No behavior change for existing checkpoints.)

## RENAMED Requirements

### Terminology Mapping (across all RP-* and ORC-RC-* requirements)

The following terminology changes apply uniformly across all review-gates
and orchestrator-runtime requirements:

| Old Term | New Term |
|----------|----------|
| `approved` | `done` |
| `changes-requested` | `amend` |
| `full-iteration` | `reiterate` |
| `proceed` | `redo` |
| `blocked` | (removed) |
| `pending` | (removed) |

#### Scenario: All policy files use new terminology

- GIVEN `sdd-review-policy.md`, `sdd-orchestrator.md`, and `instructions/orchestrator.md`
  are updated
- WHEN any of the three files is inspected
- THEN no occurrence of `approved`, `changes-requested`, `full-iteration`, or
  `proceed` SHALL be found in verdict/decision contexts
- AND no occurrence of `blocked` or `pending` SHALL be found
- AND the terms `done`, `amend`, `reiterate`, and `redo` SHALL appear instead
