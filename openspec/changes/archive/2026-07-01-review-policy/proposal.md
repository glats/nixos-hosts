# Proposal: Global SDD Review Policy + Iteration Protocol

## Intent

Replace the duplicated per-project `sdd-review-policy.md` (IFT-3501, REF-CREATE) with a single global policy that all projects inherit. Add an **iteration protocol** so when an apply slice fails review, the orchestrator knows what to do next (currently the policy says STOP but not what after).

## Scope

### In Scope
- Draft `sdd-review-policy.md` with hard gate + iteration protocol
- Add policy as global instruction via nix (`shared/opencode.nix` → `instructions` array + `home.file` + activation script)
- Orchestrator reads policy as context; no changes to SDD skills (layer 2)
- Guard-line pattern: `Rework level: explore|design|tasks|none`, `Iteration decision needed: Yes|No`

### Out of Scope
- Plugin/MCP implementation
- Modifying Gentle AI skills or sdd-orchestrator.md
- Per-project opt-out mechanism
- Host-differentiated policy content

## Capabilities

### New Capabilities
- `sdd-iteration-protocol`: orchestrator-level workflow for rework after failed apply review

### Modified Capabilities
- None — existing SDD phases (explore, apply, verify) keep their current contracts. The policy is instruction text the orchestrator reads as context.

## Approach

Deploy `sdd-review-policy.md` as a global instruction file via the existing nix mechanism. The orchestrator reads it as context and enforces the gate. No code changes to SDD skills.

The policy uses the "Workload Guard" pattern from `sdd-phase-common.md`: guard lines in review-checkpoint drive the orchestrator's decision point.

### Placement: Global via nix (Location 2)

**File**: `shared/opencode/sdd-review-policy.md` (sits alongside `SYSTEM_RULES.md`, `IDENTITY.md`)

**3 changes in `shared/opencode.nix`**:

1. **Line 72** — add to instructions array:
   ```nix
   instructions = [ "SYSTEM_RULES.md" "sdd-review-policy.md" ];
   ```

2. **After line 92** — add `home.file` entry:
   ```nix
   ".config/${runtimeCfg.dir}/sdd-review-policy.md" = {
     force = true;
     source = ./opencode/sdd-review-policy.md;
   };
   ```

3. **Line 143** — add to activation script file list:
   ```bash
   for file in opencode.json IDENTITY.md SYSTEM_RULES.md AGENTS.md sdd-orchestrator.md sdd-review-policy.md package.json .gitignore tui.json
   ```

**Tradeoffs**:
- ✅ Survives nix rebuilds fully (file deployed + referenced + made writable)
- ✅ All hosts get it automatically (consistency)
- ✅ Version-controlled in nixos-hosts repo
- ✅ Single source of truth (no per-project drift)
- ❌ All hosts get it — thinkcentre (headless) and t14 (laptop) also inherit SDD review gates they may not need
- ❌ Projects cannot opt out (arrays merge, cannot block global instructions)
- ❌ Requires nix rebuild to update policy text

### Alternative: Per-project copy (Location 3)
Each project keeps its own `.opencode/sdd-review-policy.md`. No nix changes needed. Risk: drift, bootstrap overhead for new projects.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/opencode/sdd-review-policy.md` | New | Policy file (see below) |
| `shared/opencode.nix` | Modified | Lines 72, ~93, 143 — 3 additions |
| IFT-3501, REF-CREATE `.opencode/` | Removed | Delete local `sdd-review-policy.md` + its `instructions` entry after global deploy |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Headless hosts get SDD policy unnecessarily | Med | Policy is instruction text only — no overhead unless SDD is active. Acceptable noise. |
| Policy text changes require nix rebuild | High | Trade accepted — version control benefit outweighs rebuild cost for a rarely-changing policy doc. |
| Orchestrator misinterprets guard lines | Low | Use exact guard-line format from existing Workload Guard pattern. Test with manual run. |

## Rollback Plan

1. Remove `sdd-review-policy.md` from instructions array (line 72) → rebuild
2. Remove `home.file` entry → rebuild
3. Restore per-project copies in IFT-3501/REF-CREATE if needed

## Dependencies

- None external. The nix mechanism already deploys `SYSTEM_RULES.md` via the same pipeline; this mirrors it exactly.

## Success Criteria

- [ ] `sdd-review-policy.md` appears in `~/.config/opencode/` after nix rebuild
- [ ] OpenCode `instructions` array includes `sdd-review-policy.md` (verify: `opencode debug config`)
- [ ] Orchestrator stops after apply slice when review-checkpoint says `changes-requested`
- [ ] Orchestrator presents iteration decision: full iteration vs. inline fixes vs. proceed
- [ ] Full iteration re-reads all artifacts as context and overwrites them

---

# Policy: sdd-review-policy.md

> This is the complete policy text to be placed at `shared/opencode/sdd-review-policy.md`.

```markdown
# SDD Review Policy + Iteration Protocol

This policy applies to **every SDD change in this workspace**, including future changes that do not restate it in their own specs.

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
                            ┌───────────────┼───────────────┐
                            ▼               ▼               ▼
                      full-iteration   inline-fixes      proceed
                      (re-explore →    (fix → re-apply)  (skip gate)
                       → re-apply)
```

## Hard Gate After Every Apply Slice

After any successful `sdd-apply` slice, stop the implementation loop and do all of the following before any next apply:

1. **Commit and push** every affected repository/branch for that slice.
2. **Ensure the GitHub diff or PR is visible** for every affected repository.
3. **Update `apply-progress`** with repo / branch / commit / PR information for the slice.
4. **Record a `review-checkpoint`** for the current bundle verdict.

Do **not** start the next apply slice until the latest `review-checkpoint` says either:
- `approved`, or
- explicit `proceed`

If the latest checkpoint says any of the following, implementation must stop:
- `changes-requested`
- `blocked`
- `pending`
- missing / unclear verdict

## Iteration Protocol

When the review-checkpoint verdict is `changes-requested`, `blocked`, or `pending`, the orchestrator presents the user with a decision:

1. **Full iteration**: Re-explore with all previous artifacts + review feedback as context. Rebuild proposal, specs, design, tasks, and re-apply. Overwrites artifacts via topic_key upsert (Engram) or file overwrite (OpenSpec). Old approach is context, not discarded.
2. **Inline fixes**: Fix only what the review flagged. Re-apply from the current state.
3. **Proceed**: Override the gate and continue to verify.

**Default heuristics** (user always has final word):
- Small changes (1–2 files, trivial fix) → default to inline fixes
- Complex changes (multi-file, approach change) → default to full iteration

**Guard lines** in review-checkpoint:
```
Rework level: explore|design|tasks|none
Iteration decision needed: Yes|No
```

The orchestrator checks these guard lines and asks the user when `Iteration decision needed: Yes`.

## Re-Explore Protocol

When full iteration is chosen:
- The sub-agent MUST read ALL existing artifacts as context: proposal, specs, design, tasks, apply-progress, review-checkpoint
- Builds on known facts, not from scratch
- Each phase overwrites its artifact (topic_key upsert / file overwrite)
- Old approach preserved in Engram history / git history

## Verify Gate

Do **not** run `sdd-verify` until the latest `review-checkpoint` says `approved` or explicit `proceed`.

## Artifact Expectations

When the active artifact store is OpenSpec or Hybrid:
- `openspec/changes/{change}/apply-progress.md`
- `openspec/changes/{change}/review-checkpoint.md`

When the active artifact store is Engram or Hybrid:
- `sdd/{change}/apply-progress`
- `sdd/{change}/review-checkpoint`

## Orchestrator Expectations

Before any later `sdd-apply` or `sdd-verify`, reread: proposal, specs, design, tasks, apply-progress, review-checkpoint.

## Priority

This policy is global and transversal. It applies even when a specific SDD change forgets to restate it.
```
