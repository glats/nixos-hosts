# review-gates Specification

## Purpose

Behavioral requirements for the SDD review policy — an instruction layer governing orchestrator gate behavior after every `sdd-apply` slice. These requirements describe WHAT the orchestrator MUST do, not implementation details.

## Requirements

### RP-001: Review Hard Gate

The orchestrator MUST stop after every successful `sdd-apply` slice, update `apply-progress`, and record a `review-checkpoint` with a verdict. The orchestrator MUST NOT launch `sdd-verify` or the next apply slice until the verdict is `approved` or `proceed`. Verdicts: `approved`, `changes-requested`, `blocked`, `pending`, `proceed`.

#### Scenario: Approved proceeds

- GIVEN review-checkpoint verdict `approved`
- WHEN orchestrator reads the checkpoint
- THEN it launches `sdd-verify`

#### Scenario: Changes-requested halts

- GIVEN review-checkpoint verdict `changes-requested`
- WHEN orchestrator reads the checkpoint
- THEN it STOPS and presents iteration options; MUST NOT auto-advance

#### Scenario: Missing checkpoint halts

- GIVEN no review-checkpoint found after apply
- WHEN orchestrator checks for a verdict
- THEN it STOPS and reports "no review-checkpoint found"

### RP-002: Iteration Decision Gate (Binary)

When the review-checkpoint indicates changes are needed, the orchestrator MUST present exactly two options:

1. **full-iteration**: re-explore → re-apply (automatic, reads all previous artifacts)
2. **proceed**: skip the gate, continue to verify

The orchestrator MUST NOT offer inline-fixes or partial rework. Rationale: if apply failed review, the approach needs re-examination. Partial fixes without re-exploring lead the agent to invent solutions.

#### Scenario: Binary decision presented

- GIVEN review-checkpoint with changes-requested
- WHEN orchestrator reads it
- THEN exactly two options are presented: full-iteration or proceed

#### Scenario: Full iteration chosen

- GIVEN user chooses full-iteration
- WHEN orchestrator launches re-explore
- THEN re-explore reads all previous artifacts as context

#### Scenario: Proceed bypasses gate

- GIVEN user says "proceed"
- WHEN orchestrator reads the directive
- THEN gate is bypassed and continue to next phase

### RP-003: Re-Explore Protocol

When `full-iteration` is chosen, re-explore MUST read ALL existing artifacts: proposal, specs, design, tasks, apply-progress, review-checkpoint. Each phase overwrites its artifact. No new SDD change — iteration stays within the same change. Re-explore through re-apply is AUTOMATIC (no user questions between phases). The review-checkpoint from the failed iteration is preserved as context.

#### Scenario: Builds on known facts

- GIVEN `full-iteration` and existing artifacts
- WHEN re-explore launches
- THEN it reads ALL artifacts and builds on them, not from scratch

#### Scenario: Automatic pipeline

- GIVEN `full-iteration` chosen
- WHEN orchestrator runs re-explore → propose → spec → design → tasks → apply
- THEN it does NOT ask user between phases

### RP-004: Artifact Lifecycle

Artifacts follow an overwrite model: `topic_key` upsert (Engram) or file overwrite (OpenSpec). The `review-checkpoint` is an exception — preserved as a separate artifact, NOT overwritten by new iterations. After archive, the final checkpoint is in the archive report.

#### Scenario: Upsert replaces in-place

- GIVEN `sdd/{change}/proposal` exists in Engram
- WHEN new iteration writes a proposal
- THEN `topic_key` upsert updates it; no duplicate created

#### Scenario: Old checkpoint survives iteration

- GIVEN a review-checkpoint with `changes-requested`
- WHEN full iteration overwrites other artifacts
- THEN the checkpoint is preserved separately

### RP-005: Orchestrator-Asset Enforcement

The review-gate policy MUST be enforced via an explicit checkpoint-reading and routing section in the orchestrator runtime asset (`sdd-orchestrator.md`). Instruction text loaded as context is insufficient on its own. The policy MUST NOT require modifications to SDD skills (`sdd-apply`, `sdd-verify`, etc.). Guard lines in the review-checkpoint remain as the decision input:

```
Rework level: explore|design|tasks|none
Iteration decision needed: Yes|No
```

#### Scenario: Enforced from orchestrator asset

- GIVEN the `Review-Checkpoint Gate` section is present in `sdd-orchestrator.md`
- WHEN the orchestrator returns from an `sdd-apply` slice
- THEN it locates and reads the `review-checkpoint` artifact per store-mode lookup rules before launching any subsequent phase

#### Scenario: Instruction text alone does not suffice

- GIVEN `instructions/orchestrator.md` and `sdd-review-policy.md` are both loaded as context
- AND `sdd-orchestrator.md` has no `Review-Checkpoint Gate` section
- WHEN the orchestrator completes an `sdd-apply` slice
- THEN the gate MAY be silently bypassed because there is no deterministic routing block in the main asset

#### Scenario: Guard lines trigger user prompt

- GIVEN checkpoint has `Iteration decision needed: Yes`
- WHEN orchestrator reads the checkpoint
- THEN it presents exactly two options: full-iteration or proceed

### RP-006: Proceed Escape Hatch

The user MAY say `proceed` at any review gate. The orchestrator MUST record `proceed` as the verdict and continue to the next phase.

#### Scenario: Proceed bypasses gate

- GIVEN checkpoint verdict is `changes-requested`
- WHEN user says `proceed`
- THEN verdict is recorded as `proceed` and orchestrator launches next phase

#### Scenario: Proceed at verify gate

- GIVEN user says `proceed` before verify
- WHEN orchestrator checks the checkpoint
- THEN it launches `sdd-verify` regardless of prior verdict

### RP-007: Policy File Source

The `sdd-review-policy.md` file SHALL be Nix-managed via `extraAssets` + `opencode.nix` deployment, replacing the previously manual placement at `~/.config/opencode/sdd-review-policy.md`. No behavioral change to the review gates themselves — the orchestrator reads the file from the same path. This requirement exists solely to document the source change.

#### Scenario: File present after rebuild

- GIVEN `nixos-build switch` completes
- WHEN orchestrator reads `~/.config/opencode/sdd-review-policy.md`
- THEN the file exists AND contains the review policy content

#### Scenario: Behavior unchanged

- GIVEN the policy file is now Nix-managed
- WHEN the orchestrator runs the Review Gate protocol
- THEN verdict resolution, binary decision presentation, and gate enforcement SHALL behave identically to before
