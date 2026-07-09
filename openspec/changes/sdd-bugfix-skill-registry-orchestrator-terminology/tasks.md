# SDD Tasks: Fix Skill-Registry, Orchestrator Skill Injection, and Review Terminology

**Change Name**: sdd-bugfix-skill-registry-orchestrator-terminology

**Date**: 2026-07-07

**Delivery Strategy**: single-pr

**Review Budget**: 800 lines

---

## Review Workload Forecast

| Metric | Value |
|--------|-------|
| Estimated git diff (additions + deletions) | ~2,400 lines |
| 800-line budget risk | HIGH |
| Chained PRs recommended | YES (split WI1 into 3 slices) |
| Decision needed before apply | YES |

**Analysis**: WI1 alone (9 skill file replacements) produces ~2,300 lines of diff because each replacement removes the truncated file and adds the full upstream version. WI2-WI4 add ~100 lines. Total is ~3x the 800-line budget.

**Recommendation**: Split WI1 across 3 chained PRs, then cluster WI2+WI3+small validation into a final PR. See delivery notes below.

---

## Task List

### Phase 0: Preparation (WI4 guardrails)

#### T1: Create Timestamped Full Backup of All Skills

| Field | Value |
|-------|-------|
| **Work Item** | WI4 (Guardrails) |
| **Description** | Create `~/.config/opencode/skills.backup/2026-07-07_{HHMMSS}/` containing a recursive copy of every directory under `~/.config/opencode/skills/`. Use `cp -a` to preserve permissions and symlinks. The backup MUST include ALL 32 skill directories, not just the 9 being replaced. |
| **File(s)** | `~/.config/opencode/skills.backup/2026-07-07_HHMMSS/` |
| **Operation** | create |
| **Verification** | `diff -r ~/.config/opencode/skills/ ~/.config/opencode/skills.backup/2026-07-07_HHMMSS/` exits 0. Count matches: `ls ~/.config/opencode/skills.backup/2026-07-07_HHMMSS/ | wc -l` == 32. |
| **Dependencies** | None |
| **Estimate** | Low |
| **Ask Gate** | YES — confirm before overwriting skills |
| **Execution mode note** | "ask" — user must confirm before proceeding past this task |

---

### Phase 1: Skill Replacement — WI1

#### T2: Fetch Upstream SDD Skill Files (via GitHub API)

| Field | Value |
|-------|-------|
| **Work Item** | WI1 (Skill Replacement) |
| **Description** | For each of the 9 SDD skills (sdd-apply, sdd-archive, sdd-design, sdd-explore, sdd-init, sdd-propose, sdd-spec, sdd-tasks, sdd-verify), call `github-personal_get_file_contents` to fetch SKILL.md from `Gentleman-Programming/gentle-ai`, path `internal/assets/skills/{name}/SKILL.md`, ref `heads/main`. For sdd-init, also fetch `internal/assets/skills/sdd-init/references/init-details.md`. Store each fetched file in memory for T3-T4 writes. |
| **File(s)** | (remote) `Gentleman-Programming/gentle-ai` at `internal/assets/skills/{name}/SKILL.md` |
| **Operation** | read (no local file change) |
| **Verification** | Each fetch returns HTTP 200 with content. Each SKILL.md has >= 76 lines (minimum upstream is sdd-init at ~76). |
| **Dependencies** | T1 (backup must exist before fetch, even though fetch is read-only) |
| **Estimate** | Low |
| **Ask Gate** | No |

#### T3: Replace 9 SDD Skill Files with Upstream Versions

| Field | Value |
|-------|-------|
| **Work Item** | WI1 (Skill Replacement) |
| **Description** | Write the upstream content fetched in T2 to each local skill path under `~/.config/opencode/skills/{name}/SKILL.md`. Overwrite existing files. Do this for ALL 9 skills in sequence: sdd-apply, sdd-archive, sdd-design, sdd-explore, sdd-init, sdd-propose, sdd-spec, sdd-tasks, sdd-verify. Each file MUST be verified immediately after write (exists, >30 lines, contains valid frontmatter `---`). |
| **File(s)** | `~/.config/opencode/skills/sdd-apply/SKILL.md` (overwrite) |
| | `~/.config/opencode/skills/sdd-archive/SKILL.md` (overwrite) |
| | `~/.config/opencode/skills/sdd-design/SKILL.md` (overwrite) |
| | `~/.config/opencode/skills/sdd-explore/SKILL.md` (overwrite) |
| | `~/.config/opencode/skills/sdd-init/SKILL.md` (overwrite) |
| | `~/.config/opencode/skills/sdd-propose/SKILL.md` (overwrite) |
| | `~/.config/opencode/skills/sdd-spec/SKILL.md` (overwrite) |
| | `~/.config/opencode/skills/sdd-tasks/SKILL.md` (overwrite) |
| | `~/.config/opencode/skills/sdd-verify/SKILL.md` (overwrite) |
| **Operation** | update (overwrite) |
| **Verification** | Each file: exists, `wc -l` > 30, first 3 lines contain `---`. At least sdd-apply > 200 lines. |
| **Dependencies** | T2 (fetch upstream content) |
| **Estimate** | Medium |
| **Ask Gate** | No |

#### T4: Create sdd-init references/init-details.md

| Field | Value |
|-------|-------|
| **Work Item** | WI1 (Skill Replacement) |
| **Description** | Write upstream `references/init-details.md` to `~/.config/opencode/skills/sdd-init/references/init-details.md`. This file contains the skill directory scanning rules that fix the `.atl/skill-registry.md` generation bug for workspace-style directories. |
| **File(s)** | `~/.config/opencode/skills/sdd-init/references/init-details.md` |
| **Operation** | update (overwrite) |
| **Verification** | File exists, contains skill scanning rules (grep for "skill" or "registry" in content). |
| **Dependencies** | T2 (fetch includes references/), T3 (sdd-init replaced first) |
| **Estimate** | Low |
| **Ask Gate** | No |

#### T5: Verify Local-Only Skills Are Untouched

| Field | Value |
|-------|-------|
| **Work Item** | WI1 (Post-Replacement Verification) |
| **Description** | Compare current local-only skill directories against their backup copies from T1 using `diff -r`. Skills to verify: caveman, caveman-commit, caveman-compress, caveman-help, caveman-review, caveman-stats, cavecrew, nix-verify, customize-opencode, opencode-session-recovery, hermes-ephemeral-delegation. Each MUST match its backup exactly. |
| **File(s)** | `~/.config/opencode/skills/caveman/{SKILL.md,references/*}` |
| | `~/.config/opencode/skills/caveman-commit/SKILL.md` |
| | `~/.config/opencode/skills/caveman-compress/SKILL.md` |
| | `~/.config/opencode/skills/caveman-help/SKILL.md` |
| | `~/.config/opencode/skills/caveman-review/SKILL.md` |
| | `~/.config/opencode/skills/caveman-stats/SKILL.md` |
| | `~/.config/opencode/skills/cavecrew/SKILL.md` |
| | `~/.config/opencode/skills/nix-verify/SKILL.md` |
| | `~/.config/opencode/skills/customize-opencode/SKILL.md` |
| | `~/.config/opencode/skills/opencode-session-recovery/SKILL.md` |
| | `~/.config/opencode/skills/hermes-ephemeral-delegation/SKILL.md` |
| **Operation** | verify (read-only) |
| **Verification** | `diff -r` between local and backup exits 0 for all listed directories. |
| **Dependencies** | T3, T4 (replacements done) |
| **Estimate** | Low |
| **Ask Gate** | No |

#### T6: Verify Non-SDD Workflow Skills Against Upstream

| Field | Value |
|-------|-------|
| **Work Item** | WI1 (Non-SDD Parity Check) |
| **Description** | For each non-SDD workflow skill that has an upstream counterpart (branch-pr, issue-creation, go-testing, skill-creator, judgment-day, chained-pr, comment-writer, cognitive-doc-design, hermes-ephemeral-delegation, skill-improver, work-unit-commits, skill-registry, _shared), fetch the upstream SKILL.md from `Gentleman-Programming/gentle-ai`. Compare against local. If identical (SHA or content match), skip. If upstream has meaningful improvements (beyond whitespace/formatting), update local. Log each decision. |
| **File(s)** | `~/.config/opencode/skills/{branch-pr,issue-creation,go-testing,skill-creator,judgment-day,chained-pr,comment-writer,cognitive-doc-design,hermes-ephemeral-delegation,skill-improver,work-unit-commits,skill-registry, _shared}/SKILL.md` |
| **Operation** | verify; update if divergent |
| **Verification** | Log file contains per-skill decision (skip/update). If updated, file matches upstream. |
| **Dependencies** | T3, T4 (replacements done so we have baseline) |
| **Estimate** | Medium |
| **Ask Gate** | YES — any upstream divergence should be confirmed before overwriting |

#### T7: Post-Replacement Skill Audit

| Field | Value |
|-------|-------|
| **Work Item** | WI4 (Guardrails) |
| **Description** | Full post-replacement audit: (1) Count total skill directories — must be 32. (2) Confirm all 9 replaced files have >30 lines and valid frontmatter. (3) Confirm local-only skills match T1 backup. (4) Confirm `_shared/` files unchanged. (5) Run `diff -r` summary comparing current skills/ directory against backup. Generate a short audit report. |
| **File(s)** | (read-only audit across `~/.config/opencode/skills/`) |
| **Operation** | verify |
| **Verification** | Audit report shows: 32 directories, 9 replaced files OK, local-only intact, _shared intact. |
| **Dependencies** | T5, T6 (all replacement and verification done) |
| **Estimate** | Low |
| **Ask Gate** | No |

---

### Phase 2: Orchestrator Updates — WI2

#### T8: Add Fallback Instructions to 8 Agents in opencode.json

| Field | Value |
|-------|-------|
| **Work Item** | WI2 (Agent Fallback Paths) |
| **Description** | Edit `~/.config/opencode/opencode.json` (minified JSON, ~1MB) using `python3 -c 'json.load()' + json.dump()'. Add "Read your skill file at ~/.config/opencode/skills/judgment-day/SKILL.md and follow it exactly. If the orchestrator did not inject skill paths, use this fallback." after the Global Rules section (after "No Emojis Policy" block, before the next heading) in 8 agent prompts: review-readability, review-reliability, review-resilience, review-risk, jd-fix-agent, jd-judge-a, jd-judge-b, neutral. |
| **File(s)** | `~/.config/opencode/opencode.json` |
| **Operation** | update |
| **Verification** | `python3 -c 'import json; json.load(open(...))'` exits 0. For each of the 8 agents, grep for "Read your skill file at" in the prompt field. Count matched == 8. SDD agents (10) must NOT have changed fallback text. Non-target agents unchanged. |
| **Dependencies** | T7 (post-replacement audit, ensures skill files exist at referenced paths) |
| **Estimate** | Medium |
| **Ask Gate** | YES — modifying opencode.json is a critical operation. Confirm before proceeding. |

#### T9: Add Injection Verification Gate to sdd-orchestrator.md

| Field | Value |
|-------|-------|
| **Work Item** | WI2 (Injection Verification) |
| **Description** | Insert a new subsection "#### Injection Verification (HARD GATE)" after the Sub-Agent Launch Pattern's step 3 (find the exact anchor in the document, around line ~343). The new section MUST document the 4-step verification protocol: (1) verify every injected SKILL.md path exists on disk, (2) verify count matches expected, (3) retry once on failure, (4) abort on second failure. Each step uses a `1. 2. 3. 4.` numbered list. |
| **File(s)** | `~/.config/opencode/sdd-orchestrator.md` |
| **Operation** | update |
| **Verification** | File contains "#### Injection Verification (HARD GATE)" section. Section describes all 4 steps. |
| **Dependencies** | None (independent of WI1/WI3) |
| **Estimate** | Low |
| **Ask Gate** | No |

#### T10: Add Registry Pre-Load Step to sdd-orchestrator.md

| Field | Value |
|-------|-------|
| **Work Item** | WI2 (Registry Pre-Load) |
| **Description** | Add a "Read .atl/skill-registry.md at session start" explicit startup step to the orchestrator's initialization sequence in `sdd-orchestrator.md`. Insert as: search Engram first (`mem_search`), then filesystem (`.atl/skill-registry.md`), fallback to warning. Cache for session. Insert in the orchestrator init section (near the top, before sub-agent launch pattern). |
| **File(s)** | `~/.config/opencode/sdd-orchestrator.md` |
| **Operation** | update |
| **Verification** | File contains search order: Engram -> filesystem -> warning. |
| **Dependencies** | T9 (same file, order matters — T9 first to avoid editing same section twice) |
| **Estimate** | Low |
| **Ask Gate** | No |

---

### Phase 3: Terminology Unification — WI3

#### T11: Update terminology in sdd-review-policy.md

| Field | Value |
|-------|-------|
| **Work Item** | WI3 (Terminology) |
| **Description** | Apply find-and-replace in `sdd-review-policy.md` (~18 points): |
| | `approved` -> `done` (in verdict contexts) |
| | `changes-requested` -> `amend` |
| | `full-iteration` -> `reiterate` |
| | `proceed` -> `redo` |
| | `blocked` -> `amend` (with legacy compat note added to decision table) |
| | `pending` -> `amend` (with legacy compat note) |
| | `review-checkpoint` -> `review` (artifact path references) |
| | `Iteration decision needed` -> `Iteration decision` (guard line) |
| | Also update the verdict diagram labels, gate condition headers, guard lines format, and section headers referencing old terms. |
| **File(s)** | `~/.config/opencode/sdd-review-policy.md` |
| **Operation** | update |
| **Verification** | `grep -E '(approved|changes-requested|full-iteration|proceed|blocked|pending)' ~/.config/opencode/sdd-review-policy.md` returns 0 matches in verdict/decision contexts (excluding changelog or historical notes if present). |
| **Dependencies** | None |
| **Estimate** | Medium |
| **Ask Gate** | No |

#### T12: Update terminology in sdd-orchestrator.md review section

| Field | Value |
|-------|-------|
| **Work Item** | WI3 (Terminology) |
| **Description** | Apply the same find-and-replace mapping as T11 to the review gate section of `sdd-orchestrator.md` (lines ~395-446). Update the deterministic verdict routing table (ORC-RC-004 replacement) and binary decision text (ORC-RC-005 replacement). About 10 replacement points total. |
| **File(s)** | `~/.config/opencode/sdd-orchestrator.md` |
| **Operation** | update |
| **Verification** | Decision table uses `done`/`amend`/`reiterate`/`redo`. Binary decision offers `reiterate` and `redo` only. No `approved`, `proceed`, `changes-requested`, `full-iteration`, `blocked`, `pending` in verdict context. |
| **Dependencies** | T9, T10 (same file — T11/T12 should be done together to avoid conflicts, but can also be after T9/T10 since they're different sections) |
| **Estimate** | Low |
| **Ask Gate** | No |

#### T13: Delete instructions/orchestrator.md

| Field | Value |
|-------|-------|
| **Work Item** | WI3 (Terminology) |
| **Description** | Delete `~/.config/opencode/instructions/orchestrator.md` entirely. User confirmed DELETE (not deprecate) — this is a stale duplicate that conflicts with active `sdd-review-policy.md` and `sdd-orchestrator.md`. Before deleting, verify that all essential content from this file is already present in `sdd-review-policy.md` or `sdd-orchestrator.md`. If any content is unique, migrate it first. |
| **File(s)** | `~/.config/opencode/instructions/orchestrator.md` |
| **Operation** | delete |
| **Verification** | File no longer exists. Content audit confirms no unique content was lost. |
| **Dependencies** | T11, T12 (terminology aligned first, so the deletion doesn't leave stale terminology references) |
| **Estimate** | Low |
| **Ask Gate** | YES — destructive operation. Confirm deletion intent and content audit. |

#### T14: Align Artifact Naming (review-checkpoint -> review)

| Field | Value |
|-------|-------|
| **Work Item** | WI3 (Terminology) |
| **Description** | In all active policy files (`sdd-orchestrator.md`, `sdd-review-policy.md`), replace artifact path references from `review-checkpoint` to `review`. This means: file paths in artifact lookup rules, guard line examples, and section headers. Do NOT rename existing files on disk — only the references in the policy files. Engram topics: add note that topic `review-checkpoint` maps to `review`. |
| **File(s)** | `~/.config/opencode/sdd-review-policy.md`, `~/.config/opencode/sdd-orchestrator.md` |
| **Operation** | update |
| **Verification** | No occurrences of `review-checkpoint` remain in either file. Only `review` references exist. |
| **Dependencies** | T11, T12 (text already updated, now fix remaining path references) |
| **Estimate** | Low |
| **Ask Gate** | No |

---

### Phase 4: Final Validation — WI4 Guardrails

#### T15: Grep for Stale Terminology in Active Files

| Field | Value |
|-------|-------|
| **Work Item** | WI4 (Guardrails) |
| **Description** | Run a comprehensive grep across ALL active files in `~/.config/opencode/` for stale terminology. Search for: `approved`, `changes-requested`, `full-iteration`, `proceed` (as verdict terms, not coincidental prose). Also search for `blocked` and `pending` in verdict context. List any false positives (terms that appear in non-verdict contexts like "pending changes in git"). |
| **File(s)** | `~/.config/opencode/sdd-review-policy.md`, `~/.config/opencode/sdd-orchestrator.md`, `~/.config/opencode/instructions/orchestrator.md` (if not yet deleted), `~/.config/opencode/opencode.json` |
| **Operation** | verify |
| **Verification** | Grep returns 0 matches in verdict/decision contexts. Any matches are listed as false positives with explanation. |
| **Dependencies** | T11, T12, T13, T14 (all terminology changes done) |
| **Estimate** | Low |
| **Ask Gate** | No |

#### T16: Validate opencode.json

| Field | Value |
|-------|-------|
| **Work Item** | WI4 (Guardrails) |
| **Description** | Validate `~/.config/opencode/opencode.json` parses as valid JSON. Run `python3 -c 'import sys, json; data = json.load(open(sys.argv[1])); print("OK: %d top-level keys, %d agents" % (len(data), len(data.get("agents", {}))))'` on the file. Confirm all 19 agents (or actual count) exist. Confirm all 8 modified agents contain the fallback text. |
| **File(s)** | `~/.config/opencode/opencode.json` |
| **Operation** | verify |
| **Verification** | `python3 -c "import json; json.load(open(...))"` exits 0. All agent names present. |
| **Dependencies** | T8 (opencode.json modifications done) |
| **Estimate** | Low |
| **Ask Gate** | No |

#### T17: Validate no upstream references from deleted orchestrator.md

| Field | Value |
|-------|-------|
| **Work Item** | WI4 (Guardrails) |
| **Description** | Check if any other file references the now-deleted `instructions/orchestrator.md`. Search `~/.config/opencode/` for any mention of `instructions/orchestrator.md` or `orchestrator.md` in remaining policy files, agent prompts, or skill files. If references exist, update them to point to `sdd-orchestrator.md` or `sdd-review-policy.md`. |
| **File(s)** | `~/.config/opencode/**/*.md`, `~/.config/opencode/opencode.json` |
| **Operation** | verify; update if references found |
| **Verification** | No file references `instructions/orchestrator.md`. If any found, they are redirected. |
| **Dependencies** | T13 (deletion done) |
| **Estimate** | Low |
| **Ask Gate** | No |

#### T18: Final Sanity Check

| Field | Value |
|-------|-------|
| **Work Item** | WI4 (Guardrails) |
| **Description** | Final cross-cutting verification: (1) All 9 SDD skill replacements confirmed. (2) Local-only skills intact. (3) opencode.json valid JSON with 8 fallback instructions. (4) sdd-orchestrator.md has injection verification + registry startup. (5) sdd-review-policy.md uses new terminology throughout. (6) instructions/orchestrator.md deleted. (7) No stale terminology grep hits. (8) All checks pass. Generate a single-line pass/fail for each. |
| **File(s)** | (cross-cutting read-only) |
| **Operation** | verify |
| **Verification** | All 8 checks pass (PASS/FAIL matrix). |
| **Dependencies** | T1-T17 |
| **Estimate** | Low |
| **Ask Gate** | YES — final confirmation before commit. Show user the PASS/FAIL matrix. |

#### T19: Atomic Commit

| Field | Value |
|-------|-------|
| **Work Item** | WI4 (Guardrails) |
| **Description** | Stage ALL changes from WI1-WI4 in a single git commit. The NixOS repo at `/home/glats/.nixos` only tracks the openspec/ changes (tasks file). The actual opencode config changes live at `~/.config/opencode/` which is outside the NixOS repo. So TWO commits may be needed: one for the NixOS repo (openspec/ artifacts) and one for the opencode config (if it has its own git tracking). |
| | If `~/.config/opencode/` is tracked in its own repo: commit there first with message: `fix(sdd): replace truncated skills, add injection gates, unify review terminology` |
| | If `~/.config/opencode/` is NOT tracked: create a manual changelog entry documenting the change. |
| | For the NixOS repo: commit openspec/ changes with message: | 
| | `docs(sdd): add tasks for skill-registry, injection, and terminology fix` |
| **File(s)** | `openspec/changes/sdd-bugfix-skill-registry-orchestrator-terminology/tasks.md` (NixOS repo) |
| | `~/.config/opencode/` changes (opencode config) |
| **Operation** | commit |
| **Verification** | `git log --oneline -3` shows both commits (or single commit if one repo). Working tree is clean. |
| **Dependencies** | T18 (final sanity passes) |
| **Estimate** | Low |
| **Ask Gate** | YES — "ready to commit? [y/N]" |

---

## Execution Order

```
T1  [ASK]   Backup all skills
 │
 ├──► T2          Fetch upstream SDD skills
 │    │
 │    └──► T3     Replace 9 SDD skills
 │         │
 │         ├──► T4     Create references/init-details.md
 │         │
 │         ├──► T5     Verify local-only skills untouched
 │         │
 │         ├──► T6 [ASK]  Verify non-SDD skills parity
 │         │
 │         └──► T7     Post-replacement audit
 │
 ├──► T8  [ASK]   Add fallbacks to opencode.json (8 agents)
 │    │
 │    └──► T16    Validate opencode.json
 │
 ├──► T9          Add injection verification to sdd-orchestrator.md
 │    │
 │    └──► T10    Add registry pre-load to sdd-orchestrator.md
 │
 ├──► T11         Update terminology in sdd-review-policy.md
 │    │
 │    ├──► T12    Update terminology in sdd-orchestrator.md
 │    │
 │    ├──► T13 [ASK] Delete instructions/orchestrator.md
 │    │
 │    ├──► T14    Align artifact naming
 │    │
 │    └──► T15    Grep for stale terminology
 │
 └──► T17         Validate no orphaned references
      │
      └──► T18 [ASK] Final sanity check
           │
           └──► T19 [ASK] Atomic commit
```

**Key dependency paths**:
- T1 must complete before anything else (backup is the safety net)
- T2 -> T3 -> T4 -> T5 -> T6 -> T7 (WI1 linear chain)
- T8 -> T16 (opencode.json chain)
- T9 -> T10 (orchestrator.md insertion order)
- T11 -> T12 -> T13 -> T14 -> T15 (terminology chain)
- T18 aggregates all previous tasks

**Parallelizable groups**:
- Group A: T5, T9 (independent — can run while other WI1 verification runs)
- Group B: T8, T11 (independent — opencode.json and policy can be edited in parallel with T9)

---

## Ask Gates Summary

| Task | Reason |
|------|--------|
| **T1** | Backup is the first destructive-adjacent action. Confirm we're ready to write to skills. |
| **T6** | Non-SDD skill updates need user approval since they touch skills outside the 9-target scope. |
| **T8** | opencode.json is critical infrastructure. Changes need explicit confirmation. |
| **T13** | File deletion is destructive. Confirm user wants delete (not deprecate). |
| **T18** | Final sanity check. All changes reviewed before commit. |
| **T19** | Ready to commit? Last chance to abort. |

---

## Traceability Matrix

| Task | Requirements Fulfilled |
|------|------------------------|
| T1 | REQ-SKILLS-4 (backup) |
| T2, T3 | REQ-SKILLS-1 (upstream replacement) |
| T4 | REQ-SKILLS-5 (references subdirectory) |
| T5 | REQ-SKILLS-2 (local-only preservation), REQ-GUARD-2 |
| T6 | REQ-SKILLS-3 (non-SDD parity) |
| T7 | REQ-SKILLS-1 (post-replacement audit) |
| T8 | REQ-INJECT-1, REQ-INJECT-2, REQ-INJECT-3 |
| T9 | REQ-INJECT-4 (injection verification) |
| T10 | REQ-INJECT-5 (registry pre-load) |
| T11 | REQ-TERM-1, REQ-TERM-3, REQ-TERM-5 |
| T12 | REQ-TERM-2, REQ-TERM-4, REQ-TERM-5 |
| T13 | REQ-TERM-3 (remove stale file) |
| T14 | REQ-TERM-5 (artifact naming) |
| T15 | REQ-TERM-5 (terminology audit) |
| T16 | REQ-GUARD-3 (JSON validation) |
| T17 | REQ-TERM-3 (orphaned reference check) |
| T18 | REQ-GUARD-1 (atomicity verification) |
| T19 | REQ-GUARD-1 (atomic commit) |

---

## Delivery Notes

### Single-PR Viability

The 800-line review budget will be exceeded by WI1 alone (~2,300 lines of diff for 9 skill file replacements). Options:

1. **Accept as-is**: Flag the budget risk. User explicitly set `single-pr` and `800-line budget`. If they accept the overage, proceed with single PR.
2. **Chain PRs**: Split WI1 into 3 slices:
   - PR #1: sdd-apply + sdd-verify + sdd-spec (3 largest files ~1,100 diff lines)
   - PR #2: sdd-archive + sdd-design + sdd-propose + sdd-tasks (4 medium files ~770 diff lines)
   - PR #3: sdd-init + sdd-explore + references + WI2 + WI3 + WI4 (~530 diff lines)
3. **WI2+WI3 after WI1**: WI2 and WI3 are independent and could be separate PRs entirely.

**Recommendation for apply**: If the orchestrator decides to proceed with single-PR, ensure the commit message documents the size exception. If chain-PR is preferred, the first 3 PRs cover WI1 in a Feature Branch Chain, and the 4th covers WI2+WI3.

### Files Outside This Repo

All skill files (`~/.config/opencode/skills/`), opencode.json, orchestrator assets (`sdd-orchestrator.md`, `sdd-review-policy.md`), and `instructions/orchestrator.md` live outside the NixOS repo (`/home/glats/.nixos`). Only the openspec/ directory at `openspec/changes/sdd-bugfix-skill-registry-orchestrator-terminology/tasks.md` is tracked in this repo.

Commit strategy for the opencode config files depends on whether `~/.config/opencode/` has its own git tracking. If not, a manual changelog entry should be added to the openspec/ artifacts documenting what was changed outside the repo.
