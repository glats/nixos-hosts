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

### Requirement: RG-001: Single Source of Truth

The review gate content MUST live in exactly one file: `shared/assets/review-gate.md`. OpenCode MUST continue deploying review-gate.md to `~/.config/opencode/review-gate.md` (unchanged path). Claude Code MUST deploy review-gate.md to `~/.claude/review-gate.md` via the `extraAssetsShared` mechanism: `lib/packages.nix` passes `shared/assets/` to `pkgs/gentle-ai-assets/default.nix`, which copies the file into the derivation store, and `shared/claude-code.nix` sources from `${pkgs.gentle-ai-assets}/share/gentle-ai/review-gate.md`.

#### Scenario: Both tools deploy from shared source

- GIVEN `shared/assets/review-gate.md` is the authoritative source
- WHEN home-manager deploys to any host
- THEN `~/.config/opencode/review-gate.md` and `~/.claude/review-gate.md` contain identical content

#### Scenario: Single edit propagates to both tools

- GIVEN `shared/assets/review-gate.md` is modified
- WHEN home-manager switch runs
- THEN both deployed copies reflect the edit

#### Scenario: Claude Code deploys via derivation path

- GIVEN `shared/assets/review-gate.md` has content
- WHEN the `gentle-ai-assets` derivation builds
- THEN the derivation store contains `share/gentle-ai/review-gate.md`
- AND `shared/claude-code.nix` references that derivation path

### Requirement: RG-002: Content Correctness

The review gate file MUST present exactly 3 options: done, retry, reiterate. The file MUST NOT present a fourth option. The content MUST be platform-agnostic (no OpenCode-specific or Claude-specific tool references).

#### Scenario: Gate presents exactly 3 options

- GIVEN the review gate file is read after an `sdd-apply` slice
- WHEN the orchestrator presents options to the user
- THEN exactly 3 options appear: done, retry, reiterate
- AND no fourth option exists

#### Scenario: Platform-agnostic content

- GIVEN the gate file is deployed to both OpenCode and Claude Code
- WHEN the file is read on either platform
- THEN no tool-specific references (e.g., "claude", "opencode") appear in the gate prose

### Requirement: RG-003: No Regression

OpenCode's review gate behavior MUST remain identical to current state. `shared/opencode.nix` MUST NOT be modified. OpenCode's existing orchestrator overlay deployment path MUST NOT change.

#### Scenario: OpenCode unchanged

- GIVEN the existing review-gate.md in OpenCode's orchestrator overlay
- WHEN this change is deployed
- THEN `git diff` on `shared/opencode.nix` and `shared/opencode/assets/opencode/review-gate.md` shows zero changes

### Requirement: RG-004: Claude Code Gain

Claude Code MUST have `~/.claude/review-gate.md` after deployment containing done/retry/reiterate. The file MUST be sourced from `${pkgs.gentle-ai-assets}/share/gentle-ai/review-gate.md` via `shared/claude-code.nix`. The derivation path MUST be reachable via the `extraAssetsShared` mechanism in `lib/packages.nix` and `pkgs/gentle-ai-assets/default.nix`.

#### Scenario: Claude Code receives review gate

- GIVEN a fresh deployment on any host
- WHEN home-manager switch runs
- THEN `~/.claude/review-gate.md` exists with done/retry/reiterate content
- AND the file is sourced from the derivation `${pkgs.gentle-ai-assets}/share/gentle-ai/review-gate.md`
- AND the source originates at `shared/assets/review-gate.md`

### Requirement: RG-005: Host Coverage

All 4 hosts (rog, thinkcentre, t14, mact2) MUST deploy `review-gate.md` to `~/.claude/review-gate.md` via `shared/claude-code.nix`.

#### Scenario: All hosts covered

- GIVEN any of rog, thinkcentre, t14, or mact2
- WHEN home-manager switch runs
- THEN `~/.claude/review-gate.md` exists with the done/retry/reiterate gate content
