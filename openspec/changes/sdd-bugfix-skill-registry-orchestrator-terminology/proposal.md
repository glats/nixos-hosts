# SDD Proposal: Fix Skill-Registry Generation, Orchestrator Skill Injection, and Review Terminology

**Change Name**: sdd-bugfix-skill-registry-orchestrator-terminology

**Date**: 2026-07-07

**Status**: proposed

---

## 1. Intent

Fix three bugs in the OpenCode SDD workflow that collectively degrade reliability: (1) `sdd init` in workspace-style directories generates incorrect `.atl/skill-registry.md` filled with build/test/e2e examples from inner projects instead of skill paths; (2) SDD phase sub-agents and review lens agents silently fail when the orchestrator forgets to inject skill paths into their launch prompts; (3) review checkpoint documents use conflicting terminology across three policy files, confusing agents and users. Additionally, restore all truncated SDD phase skills to their upstream canonical versions from `Gentleman-Programming/gentle-ai`.

## 2. Scope

### Work Item 1: Replace truncated SDD skills with upstream canonical versions

- **What**: Replace all SDD phase skills (`sdd-apply`, `sdd-archive`, `sdd-design`, `sdd-explore`, `sdd-init`, `sdd-propose`, `sdd-spec`, `sdd-tasks`, `sdd-verify`) with the canonical versions from `Gentleman-Programming/gentle-ai` at `internal/assets/skills/`. These skills are currently 2x-7x smaller than upstream (e.g., sdd-init: 47 lines vs 76 upstream, sdd-apply: 37 vs ~200 upstream).

- **Where**:
  - `~/.config/opencode/skills/sdd-apply/SKILL.md` -- replace
  - `~/.config/opencode/skills/sdd-archive/SKILL.md` -- replace
  - `~/.config/opencode/skills/sdd-design/SKILL.md` -- replace
  - `~/.config/opencode/skills/sdd-explore/SKILL.md` -- replace
  - `~/.config/opencode/skills/sdd-init/SKILL.md` -- replace (loses Language Domain Contract, Activation Contract, Decision Gates table, Output Contract; gains references/init-details.md)
  - `~/.config/opencode/skills/sdd-init/references/init-details.md` -- replace (upstream version required for skill-registry scan rules)
  - `~/.config/opencode/skills/sdd-propose/SKILL.md` -- replace
  - `~/.config/opencode/skills/sdd-spec/SKILL.md` -- replace
  - `~/.config/opencode/skills/sdd-tasks/SKILL.md` -- replace
  - `~/.config/opencode/skills/sdd-verify/SKILL.md` -- replace

- **Why**: The current local SDD skill files were truncated during a previous update. They are missing Language Domain Contracts, detailed Execution Steps, Decision Gates, Output Contracts, and referenced detail files. This causes sub-agents to work with incomplete instructions, producing wrong output (like the skill-registry bug where `sdd-init` doesn't instruct proper skill directory scanning).

- **How**: Fetch each skill's `SKILL.md` and `references/` directory from the upstream repo at `Gentleman-Programming/gentle-ai`, path `internal/assets/skills/{skill-name}/`. Write them to the corresponding local paths. Preserve the existing `references/init-details.md` content as baseline but replace with upstream when upstream version is more complete. Run `skill-registry` regeneration to update the index after replacement.

- **Risk**: MEDIUM. Multiple files changed (10 skills). If skills have local customizations, they could be lost. Mitigation: backup exists at `skills.backup/2026-05-03_142254/`. Also, `_shared/` files are NOT being replaced (they already match upstream). The `sdd-onboard` skill already matches upstream (231 lines vs 220 upstream) and is excluded.

- **Dependencies**: None. This is the foundational work item.

---

### Work Item 2: Add skill path injection verification to orchestrator, plus fallback paths to review lenses

- **What**: Strengthen the orchestrator's skill injection protocol with mandatory verification. Add fallback "Read your skill file at..." messages to all review lens and judgment-day agent prompts in `opencode.json`.

- **Where**:
  - `~/.config/opencode/sdd-orchestrator.md` -- add mandatory injection verification step at the skill delegation section
  - `~/.config/opencode/opencode.json` -- add fallback read instructions to `review-readability`, `review-reliability`, `review-resilience`, `review-risk`, `jd-fix-agent`, `jd-judge-a`, `jd-judge-b` agent prompts

- **Why**: SDD phase agents already have fallback paths (e.g., "Read your skill file at ~/.config/opencode/skills/sdd-apply/SKILL.md and follow it exactly") but these are last-resort. The review lens agents and judgment-day agents have NO fallback at all -- if the orchestrator forgets to inject skill paths, they run without their review/judge instructions. The orchestrator also has no mechanism to verify that injection succeeded.

- **How**:
  1. In `sdd-orchestrator.md`, at the skill delegation section: add a verification step after constructing the sub-agent prompt. The orchestrator MUST check that the injected `## Skills to load before work` block resolves to existing files, and that the count of injected skills matches the expected count. If verification fails, retry injection once; if still fails, abort with a clear error.
  2. In `opencode.json`, add to each review lens and jd agent's prompt (after the Global Rules section): `"Read your skill file at ~/.config/opencode/skills/{skill-name}/SKILL.md and follow it exactly."` This mirrors the existing fallback pattern already present in sdd-* agents.
     - `review-readability` -> `~/.config/opencode/skills/judgment-day/SKILL.md` (readability is a judgment-day lens)
     - `review-reliability` -> `~/.config/opencode/skills/judgment-day/SKILL.md`
     - `review-resilience` -> `~/.config/opencode/skills/judgment-day/SKILL.md`
     - `review-risk` -> `~/.config/opencode/skills/judgment-day/SKILL.md`
     - `jd-fix-agent` -> `~/.config/opencode/skills/judgment-day/SKILL.md`
     - `jd-judge-a` -> `~/.config/opencode/skills/judgment-day/SKILL.md`
     - `jd-judge-b` -> `~/.config/opencode/skills/judgment-day/SKILL.md`
     - Also add fallback for `neutral` agent if it exists and lacks the fallback.

- **Risk**: LOW. Fallback additions are mechanical -- one line per agent. The orchestrator verification adds a small check but no behavior change unless injection fails. The `opencode.json` agent prompts are long (~10K chars each) but the change is surgical.

- **Dependencies**: None. Independent of other work items.

---

### Work Item 3: Unify review terminology to done/amend/reiterate/redo

- **What**: Update all review checkpoint documents to consistently use the terminology `done`/`amend`/`reiterate`/`redo` (user preference from Engram #1682). Remove or align the stale `instructions/orchestrator.md` which conflicts with the active `sdd-review-policy.md` and `sdd-orchestrator.md`.

- **Where**:
  - `~/.config/opencode/sdd-review-policy.md` -- update verdicts and decision table from `approved`/`changes-requested`/`full-iteration`/`proceed` to `done`/`amend`/`reiterate`/`redo`
  - `~/.config/opencode/sdd-orchestrator.md` (lines 395-446) -- update Review-Checkpoint Gate verdict table and binary decision text
  - `~/.config/opencode/instructions/orchestrator.md` -- either DELETE (stale duplicate of sdd-review-policy.md) or ALIGN to match

- **Why**: Three files currently use conflicting terminology for the same workflow:
  - `instructions/orchestrator.md` (stale) uses `done`/`amend`/`reiterate`/`redo`
  - `sdd-review-policy.md` (active) uses `approved`/`changes-requested`/`full-iteration`/`proceed`
  - `sdd-orchestrator.md` (active, lines 418-446) uses same as review policy but internal consistency breaks when sub-agents see "amend" in old instructions but "changes-requested" in active policy.

  This three-way conflict causes agents to use "redo" (from the stale file or from guessing) when the documented term is "full-iteration" or "reiterate", confusing users and breaking the review loop.

- **How**:
  1. **Keep `instructions/orchestrator.md` as the canonical review policy** since it already uses the user's preferred terminology (`done`/`amend`/`reiterate`/`redo`). Update it to include the improvements from `sdd-review-policy.md` (hard gate after every apply slice, binary decision caching, reiterate protocol, guard lines format, verify gate hard block).
  2. **Update `sdd-review-policy.md`** to match the new canonical terminology. Specifically:
     - `approved` -> `done`
     - `changes-requested` -> `amend`
     - `full-iteration` -> `reiterate`
     - `proceed` -> `redo`
     - Rename all section headers accordingly
  3. **Update `sdd-orchestrator.md`** decision table (lines 418-446) to use the new verdict names.
  4. **DELETE `instructions/orchestrator.md`** if it becomes fully redundant after the alignment (to be decided during implementation). Minimum: ensure `sdd-orchestrator.md` is the single orchestrator reference and `sdd-review-policy.md` is the single review policy reference, both using consistent terminology.

- **Risk**: MEDIUM. Terminology changes require matching updates in three files. If any file is missed, agents may still use old verdict names. Also, Engram observations, existing apply-progress artifacts, and review-checkpoint artifacts may reference old terminology. Mitigation: update all three files atomically in one commit. Existing artifacts with old verdicts remain readable (the underlying workflow is identical, only labels differ).

- **Dependencies**: None. Independent of other work items.

---

### Work Item 4: Preserve local-only skills and verify non-SDD skills match upstream

- **What**: Ensure local-only skills (caveman-*, nix-verify, customize-opencode) are NOT overwritten. Verify that non-SDD workflow skills (branch-pr, issue-creation, go-testing, skill-creator, judgment-day, chained-pr, comment-writer, cognitive-doc-design, hermes-ephemeral-delegation, skill-improver, work-unit-commits) already match their upstream versions.

- **Where**:
  - `~/.config/opencode/skills/caveman/`, `caveman-commit/`, `caveman-compress/`, `caveman-help/`, `caveman-review/`, `caveman-stats/` -- local-only, preserve
  - `~/.config/opencode/skills/nix-verify/` -- local-only, preserve
  - `~/.config/opencode/skills/customize-opencode/` -- local-only (this is a local skill for NixOS opencode config), preserve
  - `~/.config/opencode/skills/branch-pr/`, `issue-creation/`, `go-testing/`, `skill-creator/`, `judgment-day/`, `chained-pr/`, `comment-writer/`, `cognitive-doc-design/`, `hermes-ephemeral-delegation/`, `skill-improver/`, `work-unit-commits/` -- verify match upstream, update if not
  - `~/.config/opencode/skills/_shared/` -- verify match upstream (already confirmed matching)
  - `~/.config/opencode/skills/skill-registry/` -- verify match upstream

- **Why**: The scope explicitly says non-SDD skills that match upstream stay as-is, and local-only skills must be preserved. This is the guardrail to prevent accidentally overwriting locally-developed skills during Work Item 1.

- **How**: Compare each local skill with its upstream counterpart at `internal/assets/skills/{name}/SKILL.md`. If SHA matches, skip. If SHA differs, review the diff and decide: if trivial (formatting, whitespace), keep local; if upstream has meaningful improvements, update. Log all decisions. Local-only skills are excluded from replacement by definition (they have no upstream counterpart).

- **Risk**: LOW. This is verification work, not modification work. The main risk is accidentally updating a local-only skill, caught by the guardrail check.

- **Dependencies**: Must run AFTER Work Item 1 (skill replacement) and BEFORE regeneration of skill-registry.

## 3. Out of Scope

- **Restoring skills from local backup** (`skills.backup/2026-05-03_142254/`): The backup is useful for diff comparison but the source of truth is the upstream canonical versions from `Gentleman-Programming/gentle-ai`.
- **Changing agent tool lists** in `opencode.json`: The sub-agents intentionally lack the `skill()` tool (by design in the opencode architecture). This is NOT a bug.
- **Adding skill-registry generation rules to `sdd-init/SKILL.md` directly**: The upstream canonical version delegates to `references/init-details.md` which has the rules. Replacing with upstream is sufficient.
- **Updating the `_shared/` directory**: Already matches upstream (confirmed: `sdd-phase-common.md` 112 lines in both local and upstream).
- **Changing the review protocol itself**: Only the terminology changes. The review workflow (explore -> propose -> spec -> design -> tasks -> apply -> review gate -> verify) stays the same.
- **Fixing Engram artifacts** with old terminology: Existing artifacts are historical records. Only new artifacts will use the unified terminology.
- **Non-SDD workflow skills** already matching upstream are preserved as-is, not re-fetched.
- **sdd-onboard** skill: Already matches upstream (231 local vs 220 upstream), no change needed.

## 4. Risk Assessment

### Dependency Chain

```
Work Item 1 (skills replacement)
    |
    +--> Work Item 4 (verification guardrail) [must run AFTER WI1]
    |
    [independent]
Work Item 2 (orchestrator + agent fallback)
Work Item 3 (terminology unification)
```

Work Items 2 and 3 are independent of each other and of Work Items 1/4. They can be done in parallel or in any order.

### Rollback Strategy

1. **Skills replacement (WI1)**: Replacements are file overwrites. Backup already exists at `skills.backup/2026-05-03_142254/`. Rollback: restore files from backup.
2. **Orchestrator/fallback (WI2)**: `opencode.json` changes are additive (one line per agent). `sdd-orchestrator.md` changes are a new subsection. Rollback: remove added lines, revert to previous commit.
3. **Terminology (WI3)**: Terminology changes are find-and-replace across three files. Rollback: revert commit.
4. **Verification (WI4)**: Read-only work. No rollback needed.

### Risk Matrix

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Skill replacement breaks a local customization | HIGH | LOW | Backup exists. Compare diffs before replacing. |
| Terminology change misses a file | MEDIUM | MEDIUM | Audit all files referencing review verdicts before commit. |
| Orchestrator verification breaks on edge case | LOW | LOW | Verification is additive -- only errors when injection genuinely fails. |
| Review lens fallback path loads wrong skill | LOW | LOW | Each fallback points to its own skill path, verified before commit. |
| Skill-registry regeneration picks up stale paths | MEDIUM | LOW | Run `skill-registry` regeneration AFTER all replacements. |

## 5. Delivery Strategy

- **Strategy**: Single PR (per session parameter `single-pr`)
- **Estimated lines of change**: ~600-700 lines (targeting under the 800-line review budget)
  - Work Item 1: ~300-400 lines (10 skill files replaced, net change ~300 lines since replacements are larger)
  - Work Item 2: ~150 lines (orchestrator verification ~30 lines, fallback lines ~15 lines x 7 agents = ~105 lines, plus neutral agent ~15 lines)
  - Work Item 3: ~100-150 lines (terminology changes across 3 files)
  - Work Item 4: ~50 lines (verification report/comments only)
- **Commit strategy**: Single commit with all changes since they form a cohesive fix:
  ```
  fix(sdd): replace truncated skills with upstream, add skill injection gates, unify review terminology
  ```

### Files Changed (estimated)

| File | Change Type | Est. Lines |
|------|------------|------------|
| `skills/sdd-apply/SKILL.md` | Replace | +155 |
| `skills/sdd-archive/SKILL.md` | Replace | +112 |
| `skills/sdd-design/SKILL.md` | Replace | +119 |
| `skills/sdd-explore/SKILL.md` | Replace | +78 |
| `skills/sdd-init/SKILL.md` | Replace | +29 |
| `skills/sdd-init/references/init-details.md` | Replace | varies |
| `skills/sdd-propose/SKILL.md` | Replace | +116 |
| `skills/sdd-spec/SKILL.md` | Replace | +191 |
| `skills/sdd-tasks/SKILL.md` | Replace | +132 |
| `skills/sdd-verify/SKILL.md` | Replace | +211 |
| `sdd-orchestrator.md` | Edit (injection verification + terminology) | ~60 |
| `sdd-review-policy.md` | Edit (terminology) | ~60 |
| `instructions/orchestrator.md` | Edit or Delete | ~20 |
| `opencode.json` | Edit (fallback lines) | ~105 |

### Verification Steps

1. `format-nix && nix flake check --no-build` -- confirm no Nix errors
2. Run `skill-registry` regeneration to update `.atl/skill-registry.md`
3. Manual check: verify all agent prompts in `opencode.json` contain fallback read lines
4. Manual check: verify terminology is consistent across all three policy files
5. Manual check: verify `.atl/skill-registry.md` contains skill paths, not project command examples

## 6. Success Criteria

1. `sdd init` in a workspace directory produces `.atl/skill-registry.md` with skill paths only, no build/test/e2e examples from inner projects
2. All 10 SDD phase skills match their upstream canonical versions (verified by line count and SHA)
3. Review lens agents (`review-*`) and judgment-day agents (`jd-*`) have fallback skill read instructions in their prompts
4. The orchestrator verifies skill injection before launching sub-agents, with error messages on failure
5. All three policy files (`sdd-review-policy.md`, `sdd-orchestrator.md`, `instructions/orchestrator.md`) use consistent terminology: `done`/`amend`/`reiterate`/`redo`
6. Local-only skills (caveman-*, nix-verify, customize-opencode) are untouched
7. `nix flake check --no-build` passes after all changes
