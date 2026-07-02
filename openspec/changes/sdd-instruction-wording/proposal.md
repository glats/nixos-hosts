# Proposal: sdd-instruction-wording

## Intent

SDD skill files contain ambiguous `sdd/...` references in instruction prose (e.g. "Search for `sdd/`", "Save artifact as `sdd/...`"). Models pattern-match these as filesystem globs despite the guardrail notes added by `anti-hallucination-sdd-paths`. The guardrails come AFTER the ambiguous instructions — the trigger fires before the correction is read. Fix the root cause: reword instructions to be self-explanatory.

## Scope

### In Scope
- Rewrite 9 ambiguous lines across 9 SDD skill files to lead with Engram tool names (`mem_search`, `mem_get_observation`, `mem_save`) and explicitly say "Do NOT grep/glob filesystem"
- Create 6 new override files in `shared/opencode/assets/skills/sdd-{propose,design,spec,tasks,apply,archive}/SKILL.md` (full copies with reworded lines)
- Update 2 existing override files (`sdd-explore`, `sdd-init`) with same rewording
- Update upstream PR #988 (`Gentleman-Programming/gentle-ai`) to replace guardrail-only approach with self-explanatory rewording

### Out of Scope
- Tier 2 files (already explicit with `topic_key:` prefix) — optional follow-up
- No code changes, no Engram schema changes, no new capabilities
- No changes to `_shared/sdd-phase-common.md` (already uses explicit `mem_save(topic_key=...)` in code blocks)

## Capabilities

### New Capabilities
None

### Modified Capabilities
- `gentle-ai-asset-overlay`: 6 new override files added to `shared/opencode/assets/skills/`; existing overlay mechanism unchanged, just more files layered via `extraAssets`

## Approach

**Self-explanatory wording** (Approach 1 from exploration). Each ambiguous line is rewritten to:
1. Lead with the Engram tool name (`mem_search`, `mem_get_observation`, `mem_save`)
2. Explicitly name "Engram topic" or `topic_key=...`
3. End with "Do NOT grep/glob the filesystem" or "Do NOT read/write filesystem paths under `sdd/`"

Example transformation:
- Before: `Read `sdd/{change-name}/explore`. Save artifact as `sdd/{change-name}/proposal`.`
- After: `` `mem_get_observation` the Engram topic `sdd/{change-name}/explore`. Save with `mem_save(topic_key="sdd/{change-name}/proposal", ...)`. Do NOT read or write filesystem paths under `sdd/`. ``

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/opencode/assets/skills/sdd-explore/SKILL.md` | Modified | Lines 46, 55 reworded |
| `shared/opencode/assets/skills/sdd-init/SKILL.md` | Modified | Line 41 reworded |
| `shared/opencode/assets/skills/sdd-propose/SKILL.md` | New | Full copy with line 47 reworded |
| `shared/opencode/assets/skills/sdd-design/SKILL.md` | New | Full copy with line 46 reworded |
| `shared/opencode/assets/skills/sdd-spec/SKILL.md` | New | Full copy with line 46 reworded |
| `shared/opencode/assets/skills/sdd-tasks/SKILL.md` | New | Full copy with line 47 reworded |
| `shared/opencode/assets/skills/sdd-apply/SKILL.md` | New | Full copy with line 49 reworded |
| `shared/opencode/assets/skills/sdd-archive/SKILL.md` | New | Full copy with line 48 reworded |
| Upstream PR #988 (`Gentleman-Programming/gentle-ai`) | Modified | Push new commits replacing guardrail-only with reworded instructions |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Vanilla drift on `nix flake update` | Medium | Override files are full copies; diff against vanilla and re-apply rewording |
| Verbose instructions reduce readability | Low | Each replacement is 1-2 sentences; verbosity is the price of correctness |
| Upstream PR #988 scope creep | Low | PR already open by glats; force-push updated commits with rewording replacing guardrails |
| Inconsistency during rollout | Low | All 9 files updated in single PR; no partial state |

## Rollback Plan

1. Delete 6 new override directories from `shared/opencode/assets/skills/`
2. Revert 2 existing override files (`sdd-explore`, `sdd-init`) to their `anti-hallucination-sdd-paths` versions
3. Revert upstream PR #988 to guardrail-only commits (force-push previous HEAD)
4. `nixos-build switch` restores previous state

## Dependencies

- Upstream PR #988 must be updated (force-push) with reworded instructions
- `gentle-ai-assets` derivation's `extraAssets` mechanism (already deployed by `anti-hallucination-sdd-paths`)

## Success Criteria

- [ ] All 9 Tier 1 ambiguous lines reworded in local override files
- [ ] `nix flake check --no-build` passes
- [ ] `format-nix` clean
- [ ] Upstream PR #988 updated with reworded instructions (force-pushed)
- [ ] Runtime test: SDD sub-agent no longer generates `**/sdd/**` or `**/.sdd/**` globs during exploration
