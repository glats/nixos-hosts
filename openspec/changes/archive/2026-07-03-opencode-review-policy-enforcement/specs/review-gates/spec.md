# Delta Spec: review-gates — opencode-review-policy-enforcement

## Purpose

Correct `RP-005` to reflect that instruction text alone is insufficient to
enforce the review-checkpoint gate. The policy requires an explicit
control-flow section in the orchestrator runtime asset (`sdd-orchestrator.md`).

## MODIFIED Requirements

### RP-005: Orchestrator-Asset Enforcement

The review-gate policy MUST be enforced via an explicit checkpoint-reading and
routing section in the orchestrator runtime asset (`sdd-orchestrator.md`).
Instruction text loaded as context is insufficient on its own — the root cause
of observed gate-bypass is the absence of a matching control-flow block in the
main routing asset. The policy MUST NOT require modifications to SDD sub-agent
skills (`sdd-apply`, `sdd-verify`, etc.). Guard lines in the review-checkpoint
remain as the decision input:

```
Rework level: explore|design|tasks|none
Iteration decision needed: Yes|No
```

The `sdd-orchestrator.md` runtime asset MUST contain a named, mandatory
`Review-Checkpoint Gate` section that:

1. Mandates checkpoint lookup after every `sdd-apply` slice.
2. Defines deterministic verdict routing.
3. Mandates binary decision presentation when a stop is required.
4. Covers all three artifact-store modes: `openspec`, `engram`, and `hybrid`.

#### Scenario: Enforced from orchestrator asset

- GIVEN the `Review-Checkpoint Gate` section is present in `sdd-orchestrator.md`
- WHEN the orchestrator returns from an `sdd-apply` slice
- THEN it locates and reads the `review-checkpoint` artifact per the store-mode
  lookup rules in that section before launching any subsequent phase

#### Scenario: Instruction text alone does not suffice

- GIVEN `instructions/orchestrator.md` and `sdd-review-policy.md` are both
  loaded as context
- AND `sdd-orchestrator.md` has no `Review-Checkpoint Gate` section
- WHEN the orchestrator completes an `sdd-apply` slice
- THEN the gate MAY be silently bypassed because there is no deterministic
  routing block in the main asset

#### Scenario: Guard lines trigger binary decision

- GIVEN the `Review-Checkpoint Gate` section is present in `sdd-orchestrator.md`
- AND the checkpoint has `Iteration decision needed: Yes`
- WHEN the orchestrator reads the checkpoint
- THEN it presents exactly two options: `full-iteration` or `proceed`
- AND it MUST NOT auto-advance to the next phase
