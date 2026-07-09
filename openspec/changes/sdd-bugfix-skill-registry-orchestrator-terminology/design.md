# SDD Design: Fix Skill-Registry, Skill Injection, and Review Terminology

**Change Name**: sdd-bugfix-skill-registry-orchestrator-terminology
**Artifact Type**: design
**Date**: 2026-07-07
**Delivery Strategy**: single-pr
**Review Budget**: 800 lines

---

## 1. Technical Approach

### WI1: Upstream Skill Replacement

#### Source of Truth

Upstream canonical skill files live at `Gentleman-Programming/gentle-ai` repo, path `internal/assets/skills/{skill-name}/SKILL.md`. The upstream uses a dual-section format (`<!-- section:model-capable -->` and `<!-- section:model-small -->`) in at least `sdd-apply` (confirmed ~300+ lines upstream vs 37 lines local). Other skills are similarly larger.

#### Fetch Method

Use `github-personal_get_file_contents` with download_url or `github-personal_create_or_update_file` read path to fetch raw SKILL.md content and any `references/` subdirectory files. Write them to local paths at `~/.config/opencode/skills/{skill-name}/SKILL.md`.

#### Replacement Matrix

| Skill | Local Lines | Expected Upstream | Change |
|-------|-------------|-------------------|--------|
| `sdd-apply` | 37 | ~300 (dual-section) | Replace |
| `sdd-archive` | 41 | ~153 (from proposal) | Replace |
| `sdd-design` | 53 | ~172 (from proposal) | Replace |
| `sdd-explore` | 58 | ~136 (from proposal) | Replace |
| `sdd-init` | 47 | ~76 (from upstream) | Replace + `references/` |
| `sdd-propose` | 61 | ~177 (from proposal) | Replace |
| `sdd-spec` | 41 | ~232 (from proposal) | Replace |
| `sdd-tasks` | 41 | ~173 (from proposal) | Replace |
| `sdd-verify` | 140 | ~351 (from proposal) | Replace |

**Excluded from replacement** (already match upstream or local-only):

| Skill | Reason |
|-------|--------|
| `sdd-onboard` | Already matches upstream (231 local vs ~220 upstream) |
| `_shared/sdd-phase-common.md` | Already matches upstream (112 lines both) |
| `_shared/openspec-convention.md` | Already matches upstream (119 lines both) |
| `_shared/skill-resolver.md` | Already matches upstream (shared file) |
| `caveman`, `caveman-*` (6 variants) | Local-only skills |
| `cavecrew` | Local-only skill |
| `nix-verify` | Local-only skill |
| `customize-opencode` | Built-in local skill |
| `opencode-session-recovery` | Local-only skill |
| `hermes-ephemeral-delegation` | Upstream has counterpart but proposal says verify only |

**Non-SDD workflow skills to verify (no replacement unless different)**:

| Skill | Action |
|-------|--------|
| `branch-pr` | Verify, replace only if SHA differs |
| `issue-creation` | Verify, replace only if SHA differs |
| `go-testing` | Verify, replace only if SHA differs |
| `skill-creator` | Verify, replace only if SHA differs |
| `judgment-day` | Verify, replace only if SHA differs |
| `chained-pr` | Verify, replace only if SHA differs |
| `comment-writer` | Verify, replace only if SHA differs |
| `cognitive-doc-design` | Verify, replace only if SHA differs |
| `skill-improver` | Verify, replace only if SHA differs |
| `work-unit-commits` | Verify, replace only if SHA differs |
| `skill-registry` | Verify, replace only if SHA differs |

#### Backup Strategy

Before any file is overwritten:
1. Check if `~/.config/opencode/skills.backup/` directory exists; if not, create it.
2. Create timestamp directory: `skills.backup/YYYY-MM-DD_HHMMSS/`
3. Copy ALL current skill directories (not just SDD) into the timestamped backup to preserve complete state.
4. Each file copied maintains relative path within the backup.

#### Replacement Procedure (per skill)

```
For each of the 9 SDD skills:
1. Fetch upstream SKILL.md via GitHub API
2. If upstream has references/ subdirectory, fetch all files from it
3. Write SKILL.md to local path (overwrite)
4. For each references/ file, write to local path (overwrite or create)
5. Verify: file exists, has >30 lines, frontmatter has valid --- delimiters
```

#### Post-Replacement Audit

After all replacements:
1. Confirm all 9 replaced files exist and have >30 lines
2. Confirm local-only skills (caveman-*, nix-verify, customize-opencode, cavecrew, opencode-session-recovery) still exist and have not been modified
3. Confirm _shared/ files unchanged
4. Run skill-registry regeneration to update index

---

### WI2: Orchestrator Injection Hard Gate + Agent Fallback Paths

#### Codebase Verification Finding

**SDD agents already have fallback read instructions.** Every `sdd-*` agent in `opencode.json` already contains a line like:

```
You are an SDD executor for the apply phase, not the orchestrator. Do this phase's work yourself. Do NOT delegate, Do NOT call task, and Do NOT launch sub-agents. Read your skill file at ~/.config/opencode/skills/sdd-apply/SKILL.md and follow it exactly.
```

Therefore WI2 scope is REDUCED from "add fallback to SDD + review + JD agents" to "add fallback to review + JD + neutral agents only."

#### opencode.json Changes (8 agents)

Each of the following agents needs a fallback line added after their "Global Rules (ALWAYS FOLLOW)" section:

| Agent | Skill File Fallback | Injection Point |
|-------|-------------------|-----------------|
| `review-readability` | `~/.config/opencode/skills/judgment-day/SKILL.md` | After `**NEVER use emojis.**` block, before `## Operating Protocol` |
| `review-reliability` | `~/.config/opencode/skills/judgment-day/SKILL.md` | Same position |
| `review-resilience` | `~/.config/opencode/skills/judgment-day/SKILL.md` | Same position |
| `review-risk` | `~/.config/opencode/skills/judgment-day/SKILL.md` | Same position |
| `jd-fix-agent` | `~/.config/opencode/skills/judgment-day/SKILL.md` | After `**NEVER use emojis.**` block, before `## Operating Protocol` |
| `jd-judge-a` | `~/.config/opencode/skills/judgment-day/SKILL.md` | Same position |
| `jd-judge-b` | `~/.config/opencode/skills/judgment-day/SKILL.md` | Same position |
| `neutral` | `~/.config/opencode/skills/judgment-day/SKILL.md` | After `## Response Protocol` `DO NOT:` block, before `## Global Rules` (different structure -- see exact injection below) |

**Exact fallback text to inject** (same pattern as SDD agents):

```
Read your skill file at ~/.config/opencode/skills/judgment-day/SKILL.md and follow it exactly. If the orchestrator did not inject skill paths, use this fallback.
```

**Injection mechanism**: Use `python3` with `json.load()` / `json.dump()` to modify the `agent.{name}.prompt` strings. The string replacement must be precise -- insert the fallback text at the boundary between the Global Rules section and the next section heading. For review/jd agents, the insertion point is between the "No Emojis Policy" block end and the next `## ` heading. For `neutral`, it's after the Response Protocol DO NOT block and before the Global Rules heading.

#### sdd-orchestrator.md Changes (Injection Verification)

**Insertion point**: After the Sub-Agent Launch Pattern's step 3 (line ~343: "Instruct the sub-agent to read those exact files BEFORE task-specific work"), add a new verification step:

```markdown
#### Injection Verification (HARD GATE)

After constructing the sub-agent prompt but BEFORE calling `task(...)`:

1. **Verify paths exist**: For every `SKILL.md` path in the `## Skills to load before work` block, confirm the file exists on disk.
   - `engram`-backed paths: verify via `mem_search` + `mem_get_observation`
   - Filesystem paths: verify via file existence check
2. **Verify count matches**: Confirm the number of injected skill paths matches the expected count for the phase. If the registry says SDD phase X requires N skills, confirm N paths are present.
3. **On failure**: Retry injection ONCE by re-resolving from the cached skill registry. If still failing, ABORT with a clear error message: `"Skill injection failed for {phase}: expected {N} skills, only {M} verified. Missing: {list}. Check skill-registry or skill paths."`
4. **Log the result**: Include `injection_verified: true` and the verified path list in the orchestrator's session log (not sent to sub-agent).

This verification is MANDATORY -- not a recommendation, not optional. Do NOT launch the sub-agent unless all injected skill paths resolve to existing files.
```

This adds approximately 15-20 lines to `sdd-orchestrator.md` at the skill delegation section (currently lines 326-345).

**Additional change**: The orchestrator's `SDD Init Guard` (lines 178-192) already searches Engram for `skill-registry`. The existing `Sub-Agent Launch Pattern` (lines 326-345) already resolves skills from the registry. These are sufficient for REQ-INJECT-5 (registry caching). The new verification step makes the resolver HARD instead of soft.

---

### WI3: Terminology Unification

#### Current State (Three-Way Conflict)

| Concept | `sdd-review-policy.md` (active) | `sdd-orchestrator.md` (active) | `instructions/orchestrator.md` (stale) |
|---------|-------------------------------|-------------------------------|--------------------------------------|
| Approve / Done | `approved` | `approved` | `done` |
| Changes needed | `changes-requested` | `changes-requested` | `amend` |
| Full rework | `full-iteration` | `full-iteration` | `reiterate` |
| Bypass gate | `proceed` | `proceed` | `redo` |
| Stuck verdicts | `blocked`, `pending` | `blocked`, `pending` | (absent) |
| Artifact name | `review-checkpoint` (line 14) | `review-checkpoint` (line 397) | `review` (line 12) |
| Guard lines label | `Iteration decision needed` | (in table) | `Iteration decision` |

#### Target State (Unified)

| Concept | Unified Term | Rationale |
|---------|-------------|-----------|
| Approve | `done` | User preference from Engram #1682. Shorter, clearer. |
| Changes needed | `amend` | User preference. Active voice, 5 chars. |
| Full rework | `reiterate` | User preference. Describes the action precisely. |
| Bypass gate | `redo` | User preference. Matches what agents and users naturally say. |
| Stuck verdicts | REMOVED (map to `amend`) | Never had distinct codepath. Consolidate. |
| Artifact name | `review` | Shorter. `review-checkpoint` is verbose. Already used in stale file. |
| Guard lines label | `Iteration decision` | Shorter. "Needed" is implied by `Yes|No`. |

#### Mapping Table (Find-and-Replace)

| Old | New | Where |
|-----|-----|-------|
| `approved` | `done` | verdict context only (not in "The user MAY say `proceed`") |
| `changes-requested` | `amend` | everywhere |
| `full-iteration` | `reiterate` | everywhere |
| `proceed` | `redo` | verdict context (not in "Do not proceed" or "before proceeding") |
| `blocked` | `amend` (with legacy compat note) | everywhere |
| `pending` | `amend` (with legacy compat note) | everywhere |
| `review-checkpoint` | `review` | artifact name references |
| `Iteration decision needed` | `Iteration decision` | guard lines format |

#### Files to Modify

**`sdd-review-policy.md`** (lines 1-114):
- Line 17: Diagram labels `approved` → `done`, `changes-requested` → `amend`, `blocked/pending` → `amend`, `full-iteration` → `reiterate`, `proceed` → `redo`
- Line 38: `approved` or explicit `proceed` → `done` or explicit `redo`
- Line 40-41: `changes-requested`, `blocked`, `pending` → `amend` (with legacy note)
- Lines 45-46: `changes-requested`, `blocked`, `pending` → `amend`
- Line 49: `Full iteration` → `Reiterate`
- Line 52: `Proceed` → `Redo`
- Line 62: `full-iteration` → `reiterate`
- Line 78: `Iteration decision needed` → `Iteration decision`
- Line 88: `approved` or explicit `proceed` → `done` or explicit `redo`
- Line 93-94: `proceed` → `redo` (in "Proceed Escape Hatch" section)
- Lines 99, 100, 104: `review-checkpoint.md` → `review.md`
- Line 109: `review-checkpoint` → `review`

**`sdd-orchestrator.md`** (lines 395-460):
- Line 407: `review-checkpoint.md` → `review.md` (in lookup table)
- Line 409: `review-checkpoint` → `review` (in topic key)
- Lines 418-425: Decision table entries:
  - `approved` → `done`
  - `proceed` → `redo`
  - `changes-requested` → `amend`
  - `blocked` → `amend`
  - `pending` → `amend`
- Line 427: Add note: "Legacy `blocked` and `pending` verdicts are treated as `amend`."
- Lines 434-440: Binary decision text:
  - `full-iteration` → `reiterate`
  - `proceed` → `redo`
- Line 445: `approved` or `proceed` → `done` or `redo`
- Also update the diagram line (around line 101-102) if present

**`instructions/orchestrator.md`** (lines 1-128):
- Option A (preferred): **Deprecate** with a notice at top: 
  ```
  # DEPRECATED
  This file has been replaced by `sdd-review-policy.md` (review policy) and `sdd-orchestrator.md` (orchestrator instructions). This copy is kept for reference only. Do not use it as authoritative.
  ```
- Option B: Delete entirely. The file is a duplicate of the review policy that was already merged into `sdd-review-policy.md`. Since it already uses the correct terminology (`done`/`amend`/`reiterate`/`redo`), it does not need terminology changes -- it just needs removal or deprecation.
- **Decision**: Deprecate (Option A). Risk of breaking references is low (it is stale), but deprecation is safer than deletion for a configuration file that might be loaded by legacy tooling.

#### Artifact Renaming Note

The `review-checkpoint` → `review` rename means:
- Filesystem: `openspec/changes/{change}/review-checkpoint.md` → `openspec/changes/{change}/review.md`
- Engram topic: `sdd/{change}/review-checkpoint` → `sdd/{change}/review`
- Existing artifacts with old names are not renamed (historical record).
- New artifacts use the shorter name.

---

### WI4: Guardrails

#### Pre-Replacement Backup

Implemented as part of WI1. The backup captures ALL current skill directories before any replacement. Timestamped directory: `~/.config/opencode/skills.backup/YYYY-MM-DD_HHMMSS/`.

#### Post-Replacement Verification Script

After WI1 skill replacement completes:
1. List all directories in `~/.config/opencode/skills/` and compare against expected set
2. Verify local-only skills exist and have unchanged content (compare with backup)
3. Verify replaced skills have >30 lines each
4. Verify opencode.json is valid JSON
5. Run `skill-registry` regeneration to rebuild `.atl/skill-registry.md`

#### Atomic Commit

All changes (WI1-WI3) committed in a single commit:
```
fix(sdd): replace truncated skills with upstream, add injection gates, unify review terminology

- WI1: Replace 9 SDD phase skills with upstream canonical versions from Gentleman-Programming/gentle-ai
- WI2: Add skill injection verification to orchestrator + fallback paths to 8 review/JD/neutral agents in opencode.json
- WI3: Unify review terminology to done/amend/reiterate/redo; deprecate stale instructions/orchestrator.md
```

---

## 2. File Manifest

### WI1: Skill Replacement

| File | Operation | Est. Delta | Risk |
|------|-----------|------------|------|
| `~/.config/opencode/skills.backup/YYYY-MM-DD_HHMMSS/` | Create (backup dir) | +N (all skills) | LOW |
| `~/.config/opencode/skills/sdd-apply/SKILL.md` | Replace | +263 | MEDIUM |
| `~/.config/opencode/skills/sdd-archive/SKILL.md` | Replace | +112 | MEDIUM |
| `~/.config/opencode/skills/sdd-design/SKILL.md` | Replace | +119 | MEDIUM |
| `~/.config/opencode/skills/sdd-explore/SKILL.md` | Replace | +78 | MEDIUM |
| `~/.config/opencode/skills/sdd-init/SKILL.md` | Replace | +29 | MEDIUM |
| `~/.config/opencode/skills/sdd-init/references/init-details.md` | Replace | (upstream content) | LOW |
| `~/.config/opencode/skills/sdd-propose/SKILL.md` | Replace | +116 | MEDIUM |
| `~/.config/opencode/skills/sdd-spec/SKILL.md` | Replace | +191 | MEDIUM |
| `~/.config/opencode/skills/sdd-tasks/SKILL.md` | Replace | +132 | MEDIUM |
| `~/.config/opencode/skills/sdd-verify/SKILL.md` | Replace | +211 | MEDIUM |

### WI2: Injection Hard Gate + Fallbacks

| File | Operation | Est. Delta | Risk |
|------|-----------|------------|------|
| `~/.config/opencode/sdd-orchestrator.md` | Edit (add verification section at line 343) | +17 | LOW |
| `~/.config/opencode/opencode.json` | Edit (8 agent prompts, one fallback line each) | +8 | LOW |

### WI3: Terminology Unification

| File | Operation | Est. Delta | Risk |
|------|-----------|------------|------|
| `~/.config/opencode/sdd-review-policy.md` | Edit (~18 find-and-replace points) | ~0 (inline changes) | MEDIUM |
| `~/.config/opencode/sdd-orchestrator.md` | Edit (~10 find-and-replace points in lines 395-446) | ~0 (inline changes) | MEDIUM |
| `~/.config/opencode/instructions/orchestrator.md` | Edit (add deprecation header) | +4 | LOW |

### Files NOT Changed (Verified)

| File | Reason |
|------|--------|
| `skills/_shared/*` | Already matches upstream (confirmed: 112 and 119 lines) |
| `skills/sdd-onboard/SKILL.md` | Already matches upstream (231 lines) |
| `skills/caveman/`, `caveman-*/` | Local-only, preserved |
| `skills/cavecrew/` | Local-only, preserved |
| `skills/nix-verify/` | Local-only, preserved |
| `skills/customize-opencode/` | Built-in, preserved |
| `skills/opencode-session-recovery/` | Local-only, preserved |
| `skills/hermes-ephemeral-delegation/` | Local-only, preserved |
| Non-SDD workflow skills | Verified but not replaced (SHA match) |
| SDD agent prompts in opencode.json | Already have fallback lines (10 agents verified) |

---

## 3. Dependency Graph

```
Precondition: Create skills.backup/ (capture complete current state)

    ┌─────────────────────────────────┐
    │ WI1: Skill Replacement          │
    │ (9 SDD skills + references)     │
    └──────────────┬──────────────────┘
                   │
                   ▼
    ┌─────────────────────────────────┐
    │ WI4: Verification Guardrails    │
    │ (post-replacement audit)        │
    └─────────────────────────────────┘
    
    [Independent -- can run in parallel with WI1]
    
    ┌─────────────────────────────────┐     ┌─────────────────────────────────┐
    │ WI2: Injection Hard Gate        │     │ WI3: Terminology Unification    │
    │ (orchestrator + opencode.json)  │     │ (3 policy files)                │
    └─────────────────────────────────┘     └─────────────────────────────────┘
```

**Execution order**: WI1 → WI4 (audit WI1 results) → WI2 + WI3 (parallel or sequential, independent) → atomic commit.

---

## 4. Verification Strategy

### WI1 Verification

| # | Check | Method | Pass Condition |
|---|-------|--------|---------------|
| 1 | Backup exists | `ls ~/.config/opencode/skills.backup/` | Timestamped directory present with all skill files |
| 2 | Replaced files exist | `wc -l` on each of 9 files | All > 30 lines |
| 3 | Frontmatter valid | Check each file has opening/closing `---` | All 9 have valid frontmatter |
| 4 | sdd-init references | `ls skills/sdd-init/references/init-details.md` | File exists |
| 5 | Local-only skills untouched | Compare with backup | All local-only skills match backup SHA |
| 6 | _shared/ untouched | Compare with backup | All _shared/ files match backup SHA |
| 7 | sdd-onboard untouched | Compare 231 lines | Unchanged |

### WI2 Verification

| # | Check | Method | Pass Condition |
|---|-------|--------|---------------|
| 1 | Orchestrator has verification section | Grep for "Injection Verification" in sdd-orchestrator.md | Found on exactly one line |
| 2 | opencode.json is valid JSON | `python3 -c "import json; json.load(open('...'))"` | No parse error |
| 3 | All 8 target agents have fallback | Python: check `"Read your skill file at" in prompt` | 8/8 = YES |
| 4 | Non-target agents unchanged | Python: compare fallback presence before/after | SDD agents: 10 YES (unchanged), orchestrator: unchanged |

### WI3 Verification

| # | Check | Method | Pass Condition |
|---|-------|--------|---------------|
| 1 | No old verdicts in active files | Grep for `approved`, `changes-requested`, `full-iteration`, `blocked`, `pending` in sdd-review-policy.md and sdd-orchestrator.md | 0 occurrences in verdict/decision context |
| 2 | New verdicts present | Grep for `done`, `amend`, `reiterate`, `redo` | Present in both files |
| 3 | instructions/orchestrator.md deprecated | Read first line | Contains "DEPRECATED" |
| 4 | Binary decision uses 2 options | Read sdd-orchestrator.md lines 430-440 | Exactly `reiterate` and `redo` (no third option) |

### WI4 Guardrail Checks

| # | Check | Method | Pass Condition |
|---|-------|--------|---------------|
| 1 | Atomic commit | `git log -1 --stat` | All changed files in one commit |
| 2 | Post-replacement audit | Run WI4 audit checklist | All checks pass |
| 3 | opencode.json valid | JSON parse | No errors |
| 4 | Skills directory complete | `ls -d ~/.config/opencode/skills/*/ | wc -l` | 32 directories (original count) |

---

## 5. Architecture Decisions

### AD1: Use upstream as canonical for SDD skills (not local backup)
**Rationale**: The `skills.backup/2026-05-03_142254/` is useful for diff comparison but the upstream `Gentleman-Programming/gentle-ai` repo is the maintained source of truth. Restoring from backup would re-introduce the truncation bug. Upstream also has model-section splitting (model-capable/model-small) that the truncated versions lost.

### AD2: Keep instructions/orchestrator.md as deprecated, not deleted
**Rationale**: The file is referenced by potentially unknown tooling or scripts. Deletion risks breakage. Deprecation with a clear pointer to the active files is safer and provides an audit trail.

### AD3: Add fallback only to agents missing it, not to SDD agents
**Rationale**: Codebase verification showed all 10 SDD agents already have fallback read lines. The initial proposal assumed they were needed. Adding redundant lines creates maintenance debt without benefit.

### AD4: Inject fallback at the boundary between Global Rules and the next section
**Rationale**: This is the same position where SDD agents have their fallback lines. Placing it here ensures it is visible immediately after global policies (language, emojis) but before task-specific instructions. For `neutral`, the injection point is different because its prompt structure starts with "Response Protocol" rather than "Global Rules".

### AD5: Map blocked/pending to amend with legacy compat, not delete
**Rationale**: Existing review-checkpoint artifacts may use these verdicts. The orchestrator must still parse them. Mapping to `amend` ensures the orchestrator stops and presents the binary decision rather than silently failing on unrecognized verdicts.

---

## 6. Data Flow

### Skill Replacement Flow

```
GitHub API (Gentleman-Programming/gentle-ai)
    │
    ├── fetch: internal/assets/skills/{name}/SKILL.md
    ├── fetch: internal/assets/skills/{name}/references/* (if exists)
    │
    ▼
Write to local filesystem:
    ~/.config/opencode/skills/{name}/SKILL.md
    ~/.config/opencode/skills/{name}/references/*
```

### Agent Prompt Flow (Before vs After)

**Before (current)**:
```
Sub-agent prompt:
  ┌─────────────────────────┐
  │ Global Rules            │
  │ (language, emojis)      │
  │ ─────────────────────── │
  │ Operating Protocol      │  ← NO fallback to skill file
  │ ...                     │
  └─────────────────────────┘
```

**After (WI2)**:
```
Sub-agent prompt:
  ┌─────────────────────────┐
  │ Global Rules            │
  │ (language, emojis)      │
  │ ─────────────────────── │
  │ Read your skill file    │  ← FALLBACK: if orchestrator injection fails,
  │ at ~/.config/opencode/  │    agent still finds its instructions
  │ skills/judgment-day/    │
  │ SKILL.md ...            │
  │ ─────────────────────── │
  │ Operating Protocol      │
  │ ...                     │
  └─────────────────────────┘
```

### Orchestrator Injection Flow (Before vs After)

**Before (current)**:
```
Orchestrator resolves skills → injects paths into prompt → calls task(sub-agent)
                                            ↑
                                     NO verification
```

**After (WI2)**:
```
Orchestrator resolves skills → injects paths into prompt
                                    │
                                    ▼
                              VERIFY: each path exists + count matches
                                    │
                              ┌─────┴─────┐
                              │ PASS?     │
                              ├───────────┤
                              │ YES → call task(sub-agent)
                              │ NO  → retry ONCE
                              │        ├── PASS → call task(sub-agent)
                              │        └── FAIL → ABORT with error
                              └──────────────────
```

---

## 7. Open Questions

| # | Question | Status |
|---|----------|--------|
| Q1 | Should `sdd-apply` keep the model-small section? | DECIDED: Yes, upstream includes both sections. The orchestrator selects the appropriate section based on the model assigned to `sdd-apply`. |
| Q2 | Should non-SDD workflow skills be replaced if SHA differs? | DECIDED: Yes, but only if upstream has meaningful improvements. Trivial diffs (whitespace, formatting) keep local copy. |
| Q3 | Should `instructions/orchestrator.md` be deleted or deprecated? | DECIDED: Deprecated (add header, keep file). |
| Q4 | What happens to existing review-checkpoint artifacts with old terminology? | DECIDED: They remain as historical records. The orchestrator reads them and maps old verdicts to new (see AD5). |
| Q5 | Should the orchestrator also regenerate skill-registry after replacement? | DECIDED: Yes, this is part of WI4 post-replacement audit. Run `skill-registry` regeneration to update `.atl/skill-registry.md`. |

---

## 8. Rollback Plan

If the unified commit causes issues:
1. **Restore skills from backup**: Copy all files from `skills.backup/YYYY-MM-DD_HHMMSS/` back to `skills/`
2. **Revert opencode.json**: Restore from git (`git checkout HEAD~1 -- opencode.json`)
3. **Revert policy files**: Restore sdd-orchestrator.md, sdd-review-policy.md, instructions/orchestrator.md from git
4. **Undeprecate instructions/orchestrator.md**: Remove deprecation header

The backup is the safety net for WI1. Git history is the safety net for WI2 and WI3.
