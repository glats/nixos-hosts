# Design: Global SDD Review Policy + Iteration Protocol

## Technical Approach

Deploy `sdd-review-policy.md` as a **global instruction file** via the existing nix pipeline in `shared/opencode.nix`. This mirrors exactly how `SYSTEM_RULES.md` is already deployed — three touch points: (1) `instructions` array in the generated `opencode.json`, (2) `home.file` symlink entry, (3) activation script loop that converts the nix-store symlink into a writable real copy. The orchestrator reads the policy as context (OpenCode injects instruction files into the agent's system prompt). No SDD skill files are modified. Guard lines in the `review-checkpoint` artifact drive the orchestrator's decision point at every apply→review boundary.

## Architecture Decisions

### Decision: File Placement — Global via nix (only option)

**Choice**: `shared/opencode/sdd-review-policy.md` → deployed to `~/.config/opencode/` via `shared/opencode.nix`.
**Rationale**: Matches the proven `SYSTEM_RULES.md` deployment pattern exactly. Single source of truth, survives rebuilds, version-controlled, all hosts inherit. Per-project placement causes drift and bootstrap overhead — not offered. Headless/laptop hosts get harmless instruction text (zero overhead unless SDD active).
**Confirmed**: Placement is global via nix only. Not per-project.

### Decision: Policy as Instruction Text (not code)

**Choice**: Policy is plain markdown injected via OpenCode `instructions` array — no plugin/MCP/skill edits.
**Alternatives**: Plugin that intercepts apply; modify `sdd-orchestrator.md`.
**Rationale**: Spec RP-005 mandates this. Lowest blast radius; iteration protocol lives in context, not runtime.

## Data Flow

```
 shared/opencode/sdd-review-policy.md  (source, version-controlled)
        │
        ├── home.file symlink ──► ~/.config/opencode/sdd-review-policy.md
        │
        ├── activation script ──► converts symlink → real writable copy
        │
        └── opencode.json "instructions" array ──► orchestrator system prompt
                                                    │
                          review-checkpoint artifact (guard lines)
                                                    │
                            ┌───────────────────────┼────────────────────┐
                            ▼                       ▼                    ▼
                       approved            changes-requested         blocked/pending
                            │                       │                    │
                         verify            ⚡ ASK: iteration?            STOP
                                            │
                                  ┌─────────┴─────────┐
                                  ▼                   ▼
                          full-iteration            proceed
                          (re-explore →            (skip gate)
                           → re-apply)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `shared/opencode/sdd-review-policy.md` | Create | Complete policy text (see below) |
| `shared/opencode.nix` | Modify | Line 72: add to `instructions` array; after line 92: add `home.file` entry; line 143: add to activation `for` loop |
| `.opencode/sdd-review-policy.md` (IFT-3501, REF-CREATE) | Delete | Remove stale per-project copies after global deploy (cleanup, not a placement alternative) |

## Exact Nix Edits (global option)

### Edit 1 — Line 72: instructions array

```nix
# Before
instructions = [ "SYSTEM_RULES.md" ];
# After
instructions = [ "SYSTEM_RULES.md" "sdd-review-policy.md" ];
```

### Edit 2 — After line 92 (after SYSTEM_RULES.md home.file block): new home.file entry

```nix
".config/${runtimeCfg.dir}/sdd-review-policy.md" = {
  force = true;
  source = ./opencode/sdd-review-policy.md;
};
```

### Edit 3 — Line 143: activation script file list

```bash
# Before
for file in opencode.json IDENTITY.md SYSTEM_RULES.md AGENTS.md sdd-orchestrator.md package.json .gitignore tui.json; do
# After
for file in opencode.json IDENTITY.md SYSTEM_RULES.md AGENTS.md sdd-orchestrator.md sdd-review-policy.md package.json .gitignore tui.json; do
```

## Complete Policy File Content

`shared/opencode/sdd-review-policy.md`:

```markdown
# SDD Review Policy + Iteration Protocol

This policy applies to **every SDD change in this workspace**, including future
changes that do not restate it in their own specs.

## SDD Workflow

```
explore → propose → spec → design → tasks → apply  [AUTOMATIC]
                                                │
                                      review-checkpoint
                                                │
                            ┌───────────────────┼───────────────────┐
                            ▼                   ▼                   ▼
                        approved          changes-requested    blocked/pending
                            │                   │                   │
                        verify          ⚡ ASK USER:           STOP
                                        full-iteration?
                                            │
                              ┌─────────────┴─────────────┐
                              ▼                           ▼
                        full-iteration                proceed
                        (re-explore →                  (skip gate)
                         → re-apply)
```

## Hard Gate After Every Apply Slice

After any successful `sdd-apply` slice, stop the implementation loop and do
all of the following before any next apply:

1. **Commit and push** every affected repository/branch for that slice.
2. **Ensure the GitHub diff or PR is visible** for every affected repository.
3. **Update `apply-progress`** with repo / branch / commit / PR info for the slice.
4. **Record a `review-checkpoint`** for the current bundle verdict.

Do **not** start the next apply slice until the latest review-checkpoint says
either `approved` or explicit `proceed`.

If the latest checkpoint says `changes-requested`, `blocked`, `pending`, or is
missing / unclear, implementation **must** stop.

## Iteration Protocol

When the review-checkpoint verdict is `changes-requested`, `blocked`, or
`pending`, the orchestrator presents the user with a BINARY decision:

1. **Full iteration**: Re-explore with all previous artifacts + review feedback as
   context. Rebuild proposal, specs, design, tasks, and re-apply. Overwrites
   artifacts via `topic_key` upsert (Engram) or file overwrite (OpenSpec). Old
   approach is context, not discarded.
2. **Proceed**: Override the gate and continue to verify.

Inline-fixes is **not** an option. If an apply slice failed review, the approach
needs re-examination — not partial fixes.

**Decision caching**: once the user chooses for a change, the orchestrator reuses
that decision for subsequent review gates in the same change without re-presenting.

## Re-Explore Protocol

When `full-iteration` is chosen:
- The sub-agent MUST read ALL existing artifacts as context: proposal, specs,
  design, tasks, apply-progress, review-checkpoint.
- Builds on known facts, not from scratch.
- Each phase overwrites its artifact (`topic_key` upsert / file overwrite).
- The review-checkpoint from the failed iteration is preserved separately — NOT
  overwritten by new iterations.
- Old approach preserved in Engram history / git history.
- Re-explore through re-apply is **AUTOMATIC** — no user questions between phases.

## Guard Lines (Review-Checkpoint)

Every `review-checkpoint` artifact MUST include these guard lines, which the
orchestrator reads to drive its decision point:

```
Rework level: explore|design|tasks|none
Iteration decision needed: Yes|No
```

- `Rework level` tells a full-iteration which phase to restart from.
- `Iteration decision needed: Yes` triggers the iteration prompt to the user.
- `Iteration decision needed: No` means the checkpoint is informational only.

## Verify Gate

Do **not** run `sdd-verify` until the latest review-checkpoint says `approved`
or explicit `proceed`.

## Proceed Escape Hatch

The user MAY say `proceed` at any review gate. The orchestrator MUST record
`proceed` as the verdict and continue to the next phase (apply or verify).

## Artifact Expectations

When the active artifact store is OpenSpec or Hybrid:
- `openspec/changes/{change}/apply-progress.md`
- `openspec/changes/{change}/review-checkpoint.md`

When the active artifact store is Engram or Hybrid:
- `sdd/{change}/apply-progress`
- `sdd/{change}/review-checkpoint`

## Orchestrator Expectations

Before any later `sdd-apply` or `sdd-verify`, reread: proposal, specs, design,
tasks, apply-progress, review-checkpoint.

## Priority

This policy is global and transversal. It applies even when a specific SDD
change forgets to restate it.
```

## Guard Lines Format

The review-checkpoint guard lines follow the Workload Guard pattern from
`sdd-phase-common.md`. Two lines, pipe-delimited values, exact keywords:

```
Rework level: explore|design|tasks|none
Iteration decision needed: Yes|No
```

The orchestrator scans the checkpoint for these literal strings. `Yes` on the
second line is the trigger condition for presenting iteration options.

## Integration Points

| Integration | Mechanism | How it reaches orchestrator |
|-------------|-----------|---------------------------|
| Policy text → orchestrator context | OpenCode `instructions` array in `opencode.json` | OpenCode injects listed files into the agent system prompt at session start — same path as `SYSTEM_RULES.md` |
| Writable copy at runtime | Activation script `makeOpencodeConfigMutable` | Symlink → real copy so the file persists across rebuilds and is never read-only |
| Guard lines → orchestrator decision | Orchestrator reads `review-checkpoint` artifact | Scans for `Iteration decision needed: Yes` literal; presents options or proceeds |

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | `nix flake check --no-build` passes | Run after nix edits |
| Deploy | File appears at `~/.config/opencode/sdd-review-policy.md` | `nixos-build switch` then `ls` |
| Instruction injection | `opencode debug config` shows `sdd-review-policy.md` in instructions | Run after rebuild |
| Gate behavior | Orchestrator stops after apply when checkpoint says `changes-requested` | Manual SDD run with a deliberately-failing slice |
| Iteration prompt | Orchestrator presents full-iteration / proceed (binary) | Manual run with `Iteration decision needed: Yes` |

## Migration / Rollout

1. Add `shared/opencode/sdd-review-policy.md` + edit `shared/opencode.nix` (3 edits).
2. Run `nixos-build switch` (ask user first).
3. Verify file deployed + `opencode debug config`.
4. Delete stale `.opencode/sdd-review-policy.md` in IFT-3501 and REF-CREATE + remove their `instructions` entries.
5. Commit nix changes; per-project deletions are separate PRs in those repos.

**Rollback**: Remove the `instructions` entry → rebuild → file becomes inert. Then remove `home.file` entry → rebuild → file gone.

## Open Questions

- [x] ~~User confirms global placement (vs per-project)~~ — ✅ Confirmed: global via nix only.
- [ ] Per-project cleanup (IFT-3501, REF-CREATE) — done in their own repos post-deploy, or skip if those repos no longer have a local copy?