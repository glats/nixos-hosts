# Design: opencode-review-policy-enforcement

## Technical Approach

This change inserts a single mandatory section — `Review-Checkpoint Gate (MANDATORY)` —
into `sdd-orchestrator.md`. The section turns an advisory policy (currently expressed
only in `instructions/orchestrator.md` and `sdd-review-policy.md`) into a deterministic
control-flow branch that lives in the same runtime asset that owns all other mandatory
SDD gates.

The insertion strategy is additive: no existing section is removed or restructured.
The section is placed immediately after `Apply-Progress Continuity (MANDATORY)` and
before `Engram Topic Key Format`, following the same sequential-gate pattern already
established in the file.

The change is applied to both the deployed runtime file and its source counterpart.
No other files are modified.

---

## Architecture Decisions

### AD-1: Structural gate in the routing asset, not in instruction text

**Decision**: The enforcement lives in `sdd-orchestrator.md`, not in
`instructions/orchestrator.md` or `sdd-review-policy.md`.

**Rationale**: `instructions/orchestrator.md` already expresses the policy fully.
Observed behavior still bypasses the gate. The root cause (confirmed in exploration) is
that `sdd-orchestrator.md` — the file that defines all other mandatory routing gates —
has no matching control-flow section. Strengthening instruction text again is
Approach A (rejected). The fix must be in the same layer as `Apply-Progress Continuity`,
`SDD Entry Routing`, and `SDD Session Preflight`, because that is the layer the
orchestrator treats as authoritative over its own routing behavior.

### AD-2: Position immediately after Apply-Progress Continuity

**Decision**: Insert between `Apply-Progress Continuity (MANDATORY)` and
`Engram Topic Key Format`.

**Rationale**: `Apply-Progress Continuity` fires when launching `sdd-apply` for a
continuation batch. The checkpoint gate fires after `sdd-apply` returns. Placing them
adjacent makes the post-apply sequence readable in order: (1) prepare apply launch with
progress context → (2) after apply returns, evaluate the checkpoint gate. The
`Engram Topic Key Format` section is a reference table that follows both.

### AD-3: Artifact-store-aware lookup matching the existing routing pattern

**Decision**: The gate uses the same store-mode routing table that
`opencode-sdd-artifact-store-alignment` established for all other artifact lookups.

**Rationale**: The orchestrator already resolves artifact store mode in session preflight
and passes it to all phases. Reusing the same table (`openspec` → file read; `engram` →
`mem_search` + `mem_get_observation`; `hybrid` → both) keeps the gate consistent with
every other phase read and avoids a parallel lookup protocol that could drift.

For `hybrid` mode, the `openspec` file is canonical for file-based state and the Engram
search supplements it. This matches the existing hybrid policy for all other artifacts.

### AD-4: Binary verdict table, no intermediate states

**Decision**: The verdict decision table maps exactly six states; no heuristic or
intermediate path is permitted.

**Rationale**: ORC-RC-004 in the spec defines the table. Allowing the orchestrator
discretion (e.g. inline fix, partial rework) when the verdict is non-approving leads
to invented solutions without re-examination. The binary `full-iteration` / `proceed`
recovery path (ORC-RC-005) is consistent with `RP-002` in the `review-gates` spec.

Verdict table (from spec, included here for apply precision):

| Verdict              | Action                                                           |
|----------------------|------------------------------------------------------------------|
| `approved`           | Continue to next phase (`sdd-verify` or next apply slice)        |
| `proceed`            | Continue to next phase; record verdict as `proceed`              |
| `changes-requested`  | STOP; present binary decision                                    |
| `blocked`            | STOP; present binary decision                                    |
| `pending`            | STOP; present binary decision                                    |
| missing/unreadable   | STOP; report "no review-checkpoint found"; present binary decision|

### AD-5: Hard block on sdd-verify, not just sdd-apply

**Decision**: The gate blocks both `sdd-verify` AND any subsequent `sdd-apply` slice.
`sdd-verify` cannot be launched without a passing or explicitly-proceeded checkpoint.

**Rationale**: A non-approving verdict indicates the approach may be wrong. Allowing
`sdd-verify` to run on a non-approved apply output produces a verify report that
validates the wrong implementation. The block must cover both transitions.

### AD-6: Missing checkpoint is a hard stop, same as blocked

**Decision**: A missing or unreadable checkpoint is treated as a stop condition, not as
a default-proceed.

**Rationale**: Defaulting to continue when no checkpoint is found would make the gate
trivially bypassable by simply not writing a checkpoint. The missing-checkpoint path
still presents the binary decision so the user can explicitly override via `proceed`.

### AD-7: Source file parity via identical section text

**Decision**: The same section text is applied verbatim to both the runtime file
(`~/.config/opencode/sdd-orchestrator.md`) and the source file
(`shared/opencode/assets/opencode/sdd-orchestrator.md`). No templating or divergence.

**Rationale**: The Nix deployment pipeline (`shared/opencode.nix` + activation script)
copies the source to the runtime path on every `nixos-build`. If only the runtime is
updated, the next rebuild removes the gate. The sections must be identical; if they
drift, the behavior after rebuild is undefined.

---

## Data Flow

The following describes the orchestrator's control flow after `sdd-apply` returns.

```
sdd-apply returns (status: success | partial | blocked)
    |
    v
[Review-Checkpoint Gate (MANDATORY)]
    |
    +-- Resolve active artifact store mode (cached from session preflight)
    |       |
    |       +-- openspec / hybrid  -->  Read openspec/changes/{change}/review-checkpoint.md
    |       |                              If file missing: verdict = MISSING
    |       |
    |       +-- engram / hybrid    -->  mem_search("sdd/{change}/review-checkpoint")
    |                                     + mem_get_observation(id)
    |                                     If no hit: verdict = MISSING
    |                                  (hybrid: openspec file is canonical; engram supplements)
    |
    +-- Parse verdict from checkpoint artifact
    |       |
    |       +-- approved            -->  CONTINUE (no user interaction)
    |       +-- proceed             -->  CONTINUE (record as proceed)
    |       +-- changes-requested   -->  STOP
    |       +-- blocked             -->  STOP
    |       +-- pending             -->  STOP
    |       +-- missing/unreadable  -->  STOP
    |
    +-- On CONTINUE:
    |       --> Launch sdd-verify (or next apply slice per delivery strategy)
    |
    +-- On STOP:
            --> Present binary decision via question tool:
                  Option 1: full-iteration  (re-explore -> re-apply)
                  Option 2: proceed         (skip gate; record verdict as proceed)
                --> Do NOT offer third option (inline fix, partial rework)
                --> Do NOT launch sdd-verify until user selects proceed or full-iteration resolves
```

### Relationship to Apply-Progress Continuity

`Apply-Progress Continuity` fires **before** `sdd-apply` launches (it injects the prior
progress context). The checkpoint gate fires **after** `sdd-apply` returns. They are
sequential, non-overlapping:

```
[Apply-Progress Continuity]          -- fires at launch time, injects progress context
    -> sdd-apply executes
[Review-Checkpoint Gate]             -- fires after sdd-apply returns, evaluates verdict
    -> sdd-verify or next slice or STOP
```

### Relationship to Automatic Mode Gatekeeper

The Automatic Mode Gatekeeper validates result contracts and artifact existence.
The Review-Checkpoint Gate evaluates review verdict. They are complementary:

- Gatekeeper fires first (checks that sdd-apply produced a valid, non-hallucinated result).
- Checkpoint gate fires second (checks that the review verdict permits continuing).
- Both must pass before the next phase launches.
- The checkpoint gate applies in both `auto` and `interactive` modes.

---

## File Changes

### Primary: `~/.config/opencode/sdd-orchestrator.md` (runtime)

**Change**: Insert `Review-Checkpoint Gate (MANDATORY)` section after
`Apply-Progress Continuity (MANDATORY)`.

**Insertion point**: After the closing line of the `Apply-Progress Continuity` block
(line beginning `3. If not found, no extra instruction is needed`) and before the
`Engram Topic Key Format` heading.

**Exact section text** (this is the canonical text — apply verbatim to both files):

```markdown
#### Review-Checkpoint Gate (MANDATORY)

After every `sdd-apply` slice returns and before launching any subsequent `sdd-apply`
or `sdd-verify`, the orchestrator MUST locate and read the `review-checkpoint` artifact
for the active change. This lookup MUST NOT be skipped regardless of apply outcome.

**Step 1: Resolve artifact store and locate checkpoint**

Use the active artifact store mode cached from session preflight:

| Mode | Lookup method |
| --- | --- |
| `openspec` or `hybrid` | Read `openspec/changes/{change-name}/review-checkpoint.md` |
| `engram` or `hybrid` | `mem_search("sdd/{change-name}/review-checkpoint")` then `mem_get_observation` |

For `hybrid`, perform BOTH lookups. The `openspec` file is canonical for file-based
state; the Engram result supplements it. If the store mode is unrecognized or absent,
STOP and report the unrecognized mode — do NOT default to proceed.

**Step 2: Parse verdict and apply decision table**

After reading the checkpoint, apply the verdict decision table without discretion:

| Verdict | Action |
| --- | --- |
| `approved` | Continue to next phase without user interaction |
| `proceed` | Continue to next phase; record verdict as `proceed` |
| `changes-requested` | STOP; present binary decision |
| `blocked` | STOP; present binary decision |
| `pending` | STOP; present binary decision |
| missing / unreadable | STOP; report "no review-checkpoint found"; present binary decision |

No intermediate action (inline fix, partial rework, silent continue) is permitted
outside this table.

**Step 3: Binary decision on stop**

When the gate requires a stop, present exactly two options via the `question` tool:

1. **full-iteration** — re-explore → re-apply (reads all previous artifacts as context;
   each phase overwrites its artifact)
2. **proceed** — skip the gate; record verdict as `proceed` and continue to next phase

Do NOT offer a third option. Do NOT auto-advance. Do NOT launch `sdd-verify` until the
user selects `proceed` or a completed `full-iteration` resolves with an approved
checkpoint.

**Verify gate hard block**

The orchestrator MUST NOT launch `sdd-verify` unless the latest `review-checkpoint` for
the active change has verdict `approved` or `proceed`. This applies even when the user
has not explicitly asked for a review check.
```

**Size estimate**: ~35 lines added.

### Source counterpart: `shared/opencode/assets/opencode/sdd-orchestrator.md`

**Change**: Apply the identical section text at the identical position.

**Why required**: Nix rebuild re-deploys source to runtime. If source is not updated,
the next `nixos-build` removes the gate from the runtime file.

---

## Interfaces

No new tools, commands, or APIs are introduced. The gate uses existing tool calls:

| Tool call | Purpose | Already used elsewhere |
|-----------|---------|----------------------|
| `mem_search("sdd/{change}/review-checkpoint")` | Locate checkpoint in Engram | Yes — same pattern as apply-progress |
| `mem_get_observation(id)` | Read full checkpoint content | Yes — standard Engram retrieval |
| File read (`openspec/changes/{change}/review-checkpoint.md`) | Locate checkpoint in OpenSpec | Yes — standard openspec file read |
| `question` tool (binary decision) | Present full-iteration / proceed | Yes — used by Preflight and Review Workload Guard |

The `review-checkpoint` artifact format is defined by the prior `2026-07-01-review-policy`
change. The gate consumes the existing verdict field and guard lines:

```
Rework level: explore|design|tasks|none
Iteration decision needed: Yes|No
```

No changes to the artifact format are needed.

---

## Testing Strategy

No automated test runner exists for this project (NixOS config; `nix flake check --no-build`
is the only automated check). Verification is behavioral.

**Automated check**:

```
nix flake check --no-build
```

The orchestrator file is a Markdown/text asset, not a Nix expression. `nix flake check`
validates that the deployment pipeline still compiles. No additional automated check is
available.

**Manual smoke tests** (from proposal success criteria):

1. After an apply slice, the orchestrator stops and presents `full-iteration`/`proceed`
   without requiring explicit user instruction — gate behavior is automatic.
2. With `verdict: approved` in the checkpoint file, the orchestrator continues to
   `sdd-verify` without asking.
3. With `verdict: changes-requested`, the orchestrator stops and presents the binary
   decision.
4. With no checkpoint file present (openspec mode), the orchestrator reports
   "no review-checkpoint found" and presents the binary decision.
5. After `nixos-build`, the runtime file still contains the section (source parity
   confirmed).

**Verify phase scope**: `sdd-verify` will confirm the section exists at the correct
position in both files and that the section text matches the canonical text defined here.

---

## Migration

No data migration. No secrets. No schema changes.

The `review-checkpoint.md` artifact format is unchanged — the gate reads the existing
format from the prior change.

Existing `openspec/changes/` artifacts are unaffected.

Existing `sdd-orchestrator.md` sections are not modified or removed.

---

## Open Questions

None. All design questions were resolved by the proposal and spec:

- Store-mode routing table: resolved by AD-3 (reuse existing pattern).
- Missing-checkpoint default: resolved by AD-6 (hard stop, not default-proceed).
- Verify block scope: resolved by AD-5 (blocks sdd-verify, not just sdd-apply).
- Source parity: resolved by AD-7 (identical verbatim section in both files).

---

## Alignment Checklist

| Requirement | Met by |
|-------------|--------|
| ORC-RC-001: Section present and mandatory | Section named `Review-Checkpoint Gate (MANDATORY)`, inserted after `Apply-Progress Continuity (MANDATORY)` |
| ORC-RC-002: Lookup after every apply slice | "This lookup MUST NOT be skipped regardless of apply outcome" |
| ORC-RC-003: Artifact-store-aware lookup | Step 1 routing table; hybrid: both lookups, openspec canonical |
| ORC-RC-004: Deterministic verdict routing | Step 2 decision table; "without discretion", no intermediate actions |
| ORC-RC-005: Binary decision only | Step 3; exactly two options via question tool; third option explicitly forbidden |
| ORC-RC-006: Verify gate hard block | "Verify gate hard block" subsection; verify blocked without approved/proceed |
| ORC-RC-007: Source file parity | "Source counterpart" file change; identical text at identical position |
| RP-005 (MODIFIED): Orchestrator-asset enforcement | Design surface is `sdd-orchestrator.md` (runtime asset), not instruction text |
