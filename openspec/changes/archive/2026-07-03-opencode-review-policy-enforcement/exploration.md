# Exploration: opencode-review-policy-enforcement

## Goal

Define an evidence-based SDD change around the real enforcement gap: the OpenCode
review policy is deployed correctly, but current behavior still depends on the
orchestrator merely following prompt text.

## Current State

- Confirmed: Nix deployment is already correct and should not be the focus of
  this change. Runtime files are deployed to `~/.config/opencode`, while the
  persistent repo-backed sources live under `shared/opencode`,
  `shared/opencode/assets`, and `shared/opencode/skills`.
- Confirmed: commit `4cf7699` added `shared/opencode/sdd-review-policy.md` and
  wired it into `shared/opencode.nix`, so the policy is loaded at runtime via
  `opencode.json` instructions and copied into `~/.config/opencode/`.
- Confirmed: `shared/opencode/local-agent-overlays.json` and
  `shared/opencode/agents.nix` prepend `instructions/orchestrator.md` to the
  `gentle-orchestrator` prompt and `instructions/universal.md` to subagents.
- Confirmed: `shared/opencode/instructions/orchestrator.md` contains the review
  gate policy text, including `review-checkpoint`, `apply-progress`, and the
  binary `full-iteration` vs `proceed` rule.
- Confirmed: `shared/opencode/assets/opencode/sdd-orchestrator.md` does not
  contain explicit runtime logic for `review-checkpoint` discovery, parsing,
  guard-line evaluation, or a hard stop before later `sdd-apply` / `sdd-verify`.
  Its only matching logic today is generic `apply-progress` continuity.
- Confirmed: `openspec/specs/review-gates/spec.md` currently claims the policy
  is enforceable from instruction text alone (`RP-005`), but the inspected
  runtime behavior is advisory only.

## Enforcement Gap

The current system has successful policy distribution but no reliable mechanism
that forces the orchestrator to:

1. read the latest `review-checkpoint` artifact after each apply slice,
2. parse verdict and guard lines deterministically,
3. block the next `sdd-apply` or `sdd-verify` when verdict is not `approved` or
   `proceed`, and
4. present only the binary recovery path when rework is required.

In practice, the gate exists as prompt guidance, not as a checked runtime branch
in the orchestrator flow.

## Affected Areas

- `shared/opencode/assets/opencode/sdd-orchestrator.md` — most likely place to
  add explicit checkpoint-reading and gate-routing behavior.
- `shared/opencode/instructions/orchestrator.md` — policy source currently says
  what must happen, but does not itself make it enforceable.
- `shared/opencode/local-agent-overlays.json` — proves the policy reaches the
  orchestrator prompt, so this layer is not the missing piece.
- `shared/opencode/agents.nix` — proves instruction prepending is wired
  correctly, again indicating distribution is not the root cause.
- `openspec/specs/review-gates/spec.md` — likely needs follow-up changes because
  its current “instruction text is enough” requirement does not match reality.
- Potentially related command/status contracts under packaged OpenCode/Gentle AI
  assets if the final implementation needs shared gate state handling beyond the
  main orchestrator asset.

## Overlap With Existing Changes

- `archive/2026-07-01-review-policy`: established the review policy text and the
  behavioral intent, but it assumed prompt-level enforcement was sufficient.
- `archive/2026-07-01-sub-agent-instructions`: solved instruction delivery to
  orchestrator/subagents, which is a prerequisite for this change but not the
  enforcement itself.
- `opencode-sdd-artifact-store-alignment`: relevant because it already identified
  that real runtime behavior must be implemented in orchestrator/runtime assets,
  not only asserted in prompts. This new change likely touches similar surfaces,
  but for review-gate routing instead of artifact-store routing.

## Likely Implementation Surfaces

### 1. Runtime orchestrator asset

Add explicit control-flow rules to
`shared/opencode/assets/opencode/sdd-orchestrator.md` so the orchestrator must:

- resolve the active artifact store,
- locate `review-checkpoint` in that store,
- parse verdict plus guard lines,
- stop when checkpoint is missing or non-approving,
- offer only `full-iteration` or `proceed` when required, and
- refuse `sdd-verify` / later `sdd-apply` without a passing checkpoint.

This is the most direct surface because it controls routing behavior, not just
prompt decoration.

### 2. Pure instruction text

Strengthening `shared/opencode/instructions/orchestrator.md` alone is unlikely to
be enough. That file already expresses the policy clearly; the observed problem is
that the main runtime orchestrator asset does not appear to operationalize it as
hard gating.

### 3. Additional runtime/plugin enforcement

If prompt-level orchestrator routing still proves insufficient, a stronger option
would be a plugin or command-layer enforcement mechanism that validates gate state
before apply/verify transitions. This would be more enforceable, but also higher
complexity and broader in scope than updating the orchestrator asset first.

## Approaches

| Approach | Description | Pros | Cons | Complexity |
| --- | --- | --- | --- | --- |
| A. Tighten instruction text only | Refine `instructions/orchestrator.md` wording and maybe `review-gates` spec language | Smallest change | Does not address the observed root cause; still prompt-only | Low |
| B. Add explicit gate logic to runtime orchestrator asset | Update `shared/opencode/assets/opencode/sdd-orchestrator.md` to require checkpoint lookup/parsing and branch routing | Matches the confirmed gap; keeps change focused; likely enough for real enforcement | Needs careful alignment with artifact stores and existing SDD routing rules | Medium |
| C. Add plugin or command-layer gatekeeper | Enforce review state outside prompt flow | Strongest technical enforcement | Larger design surface; more moving parts; probably unnecessary as first fix | High |

## Recommendation

Proceed with **Approach B**.

This change should treat the problem as an orchestrator runtime-behavior gap, not
as a deployment gap and not as a wording gap. The most credible fix is to make
the main runtime orchestrator asset explicitly read and enforce
`review-checkpoint` state before continuing the SDD pipeline.

The follow-up proposal should also expect a spec correction: the current
`review-gates` spec overstates what instruction text alone can guarantee.

## Risks

- The orchestrator asset may need to coordinate with existing artifact-store
  routing rules so review gating works for OpenSpec, Engram, and hybrid flows.
- If the OpenCode/Gentle AI runtime cannot reliably “parse” artifacts from prompt
  instructions alone, a later plugin/command-layer enforcement step may still be
  needed.
- The existing `RP-005` requirement may need to be rewritten, which could affect
  archived assumptions from the earlier review-policy change.

## Exploration Conclusion

The issue is not that the review policy fails to deploy; it deploys correctly.
The issue is that the active orchestrator runtime does not yet implement review
checkpoint handling as a hard branch in SDD control flow. The next change phase
should therefore define enforceable orchestrator behavior, with runtime assets as
the primary implementation surface and pure instruction text as supportive only.
