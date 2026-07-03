# Proposal: opencode-review-policy-enforcement

## Intent

The review-gate policy is already deployed and loaded at runtime. The problem
is that the active runtime orchestrator — `~/.config/opencode/sdd-orchestrator.md`
— does not implement gate logic as an explicit, deterministic control-flow branch.
It relies on the orchestrator choosing to follow instruction text. This change
makes enforcement structural: the orchestrator file gains explicit, mandatory
checkpoint-reading, verdict-parsing, and hard-stop rules so the gate cannot be
silently bypassed.

This is an **enforcement/runtime-behavior change**, not a deployment change.
The deployment stack (Nix build, `home.file` entries, activation script) is
already correct and is not touched by this change.

## Active Runtime Surface

The primary implementation surface is the deployed runtime layer at
`~/.config/opencode/`. That is the operational surface that is active regardless
of which repo or project the user is currently in.

| File | Role |
|---|---|
| `~/.config/opencode/sdd-orchestrator.md` | **Primary target** — orchestrator runtime contract |
| `~/.config/opencode/instructions/orchestrator.md` | Secondary reference — policy text already correct |
| `~/.config/opencode/sdd-review-policy.md` | Secondary reference — policy text already correct |

The canonical source for these runtime files lives in the repo under
`shared/opencode/assets/opencode/sdd-orchestrator.md` and
`shared/opencode/instructions/orchestrator.md`. The Nix deployment pipeline
(`shared/opencode.nix` + activation script) copies them to `~/.config/opencode/`
on each build. Therefore, the durable fix must also land in the source files so
it survives rebuilds — but the proposal frames the change by its runtime effect,
not by its source location.

## Scope

### In Scope

- Add an explicit **review-checkpoint guard** section to `sdd-orchestrator.md`
  (runtime: `~/.config/opencode/sdd-orchestrator.md`; source:
  `shared/opencode/assets/opencode/sdd-orchestrator.md`) that:
  1. Mandates locating the `review-checkpoint` artifact after every apply slice
     before launching a subsequent apply or verify phase.
  2. Specifies deterministic verdict parsing: `approved`/`proceed` → continue;
     `changes-requested`/`blocked`/`pending`/missing → hard stop.
  3. Mandates presenting the binary decision (`full-iteration` or `proceed`)
     when a stop is required.
  4. Integrates with the existing artifact-store routing so the gate works for
     `openspec`, `engram`, and `hybrid` modes.
- Correct `openspec/specs/review-gates/spec.md`:
  - `RP-005` currently states "policy MUST be enforceable as instruction text
    alone". This is demonstrably false and must be rewritten to state that the
    policy requires an explicit control-flow section in the orchestrator runtime
    asset, not instruction-text compliance alone.
- Apply matching changes to the source-layer counterparts so the fix survives
  nix rebuilds:
  - `shared/opencode/assets/opencode/sdd-orchestrator.md` (source of
    `~/.config/opencode/sdd-orchestrator.md`)

### Out of Scope

- Plugin or command-layer enforcement (Approach C from exploration) — not needed
  as a first fix.
- Changes to `sdd-review-policy.md` — policy text is already correct.
- Changes to `instructions/orchestrator.md` — delivery of policy text is already
  correct.
- Changes to `shared/opencode.nix`, `agents.nix`, or `local-agent-overlays.json`
  — deployment pipeline is correct.
- SDD skill files (`sdd-apply.md`, `sdd-verify.md`, etc.) — no changes needed.
- Host configuration (NixOS modules, services) — not relevant.

## Capabilities

### Modified Capabilities

- `sdd-checkpoint-enforcement`: The orchestrator runtime now implements the
  review gate as an explicit control-flow branch, not as advisory prompt text.
  This is the contract `sdd-spec` must specify.

### No New Capabilities

All behavioral intent already exists in `instructions/orchestrator.md` and
`sdd-review-policy.md`. This change operationalizes existing intent into the
main runtime routing asset.

## Approach

### Step 1 — Add checkpoint guard to `sdd-orchestrator.md`

Insert a new `### Review-Checkpoint Gate (MANDATORY)` section into
`~/.config/opencode/sdd-orchestrator.md` (and its source counterpart) immediately
after the existing `### Apply-Progress Continuity (MANDATORY)` section. The
section must:

1. State that after every `sdd-apply` returns, the orchestrator MUST locate
   the `review-checkpoint` for the active change before launching any subsequent
   `sdd-apply` or `sdd-verify`.
2. Specify artifact-store-aware lookup:
   - `openspec`/`hybrid`: read `openspec/changes/{change}/review-checkpoint.md`
   - `engram`/`hybrid`: `mem_search("sdd/{change}/review-checkpoint")` +
     `mem_get_observation`
3. Define the verdict decision table:
   - `approved` or `proceed` → continue to next phase
   - `changes-requested`, `blocked`, `pending` → STOP; present binary decision
   - missing/unreadable → STOP; report "no review-checkpoint found"
4. State that when a stop is required, the orchestrator MUST present exactly
   two options via the `question` tool: `full-iteration` and `proceed`.
5. State that the orchestrator MUST NOT launch `sdd-verify` without a passing
   or explicitly-proceeded checkpoint.

### Step 2 — Correct `RP-005` in `openspec/specs/review-gates/spec.md`

Rewrite `RP-005` to state that the policy requires an explicit checkpoint-reading
and routing section in the orchestrator runtime asset. The current claim that
instruction text alone is sufficient must be removed. Update the scenarios to
match.

### Why not instruction text only?

`instructions/orchestrator.md` already contains the full policy text, and the
observed behavior still bypasses the gate. The root cause (confirmed in the
exploration) is that the main runtime routing asset — `sdd-orchestrator.md` —
has no matching control-flow section. Adding it makes the gate structural, not
dependent on the LLM's willingness to honor a separate instruction file in the
same turn.

## Affected Areas

| File | Change | Layer |
|---|---|---|
| `~/.config/opencode/sdd-orchestrator.md` | New `Review-Checkpoint Gate` section (~30 lines) | Runtime (primary) |
| `shared/opencode/assets/opencode/sdd-orchestrator.md` | Same change — source that deploys to runtime | Source (required for rebuild durability) |
| `openspec/specs/review-gates/spec.md` | Rewrite `RP-005` + scenarios | Spec |

No other files are modified.

## Spec Corrections Needed

`openspec/specs/review-gates/spec.md` — `RP-005: Policy as Instruction Text`
requires a targeted rewrite:

- **Remove**: "It MUST NOT require modifications to SDD skills" — this was valid
  for the prior change but the current gap is in the orchestrator asset, not skills.
- **Replace claim**: "The policy MUST be enforceable as instruction text the
  orchestrator reads from context" must become: "The policy MUST be enforced via
  an explicit checkpoint-reading and routing section in the orchestrator runtime
  asset (`sdd-orchestrator.md`). Instruction text alone is insufficient."
- **Update scenarios**: `RP-005` scenarios must reflect orchestrator asset
  enforcement, not implicit instruction-text compliance.

Other requirements (`RP-001` through `RP-004`, `RP-006`) are accurate and
require no changes.

## Prior Change Alignment

| Prior Change | Relationship |
|---|---|
| `archive/2026-07-01-review-policy` | Established policy text and behavioral intent; explicitly deferred orchestrator-asset enforcement as out-of-scope. This change is the missing complement. |
| `archive/2026-07-01-sub-agent-instructions` | Solved instruction delivery. Delivery is now correct; this change is the next layer. |
| `opencode-sdd-artifact-store-alignment` | Identified the pattern: real runtime behavior must be in orchestrator/runtime assets, not in prompts. This change applies the same pattern to review-gate routing. The artifact-store routing section in `sdd-orchestrator.md` is the model to follow. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Runtime file differs from source file after change | High (expected) | Nix rebuild re-deploys source to runtime. Must run `nixos-build` after apply. |
| Gate interacts with automatic-mode gatekeeper in unexpected ways | Low | The Automatic Mode Gatekeeper already checks phase contracts; the new section adds a named gate that the gatekeeper can verify by existence. |
| `RP-005` rewrite invalidates archived assumptions | Medium | Prior archive (`2026-07-01-review-policy`) was written under the "instruction text is enough" premise. The archive is an audit trail — do not modify it. The spec correction is forward-only. |
| LLM still ignores the section | Low | The section is in the same file as existing mandatory gates that are observed to work. Structural placement in the main routing asset is materially more reliable than a separate instruction file. |

## Rollback Plan

1. Revert the `sdd-orchestrator.md` change (runtime + source).
2. Run `nixos-build` to re-deploy the reverted source to runtime.
3. Revert the `RP-005` rewrite in `openspec/specs/review-gates/spec.md`.

No data migration or secret handling required.

## Dependencies

- `opencode-sdd-artifact-store-alignment` must have its artifact-store routing
  section in `sdd-orchestrator.md` — this is already present in the deployed
  file (confirmed in exploration and current file read).
- No new Nix packages, flake inputs, or infrastructure changes.

## Success Criteria

- [ ] `~/.config/opencode/sdd-orchestrator.md` contains a `Review-Checkpoint Gate (MANDATORY)` section.
- [ ] The section specifies artifact-store-aware checkpoint lookup for `openspec`, `engram`, and `hybrid`.
- [ ] The section defines the verdict decision table with explicit stop conditions.
- [ ] The section mandates binary decision presentation via the `question` tool.
- [ ] `shared/opencode/assets/opencode/sdd-orchestrator.md` contains the same section (rebuild durability).
- [ ] `openspec/specs/review-gates/spec.md` `RP-005` no longer claims instruction text alone is sufficient.
- [ ] `nix flake check --no-build` passes with zero errors.
- [ ] Manual smoke test: after apply slice, orchestrator stops and presents `full-iteration`/`proceed` without requiring explicit user prompt for the gate behavior.
