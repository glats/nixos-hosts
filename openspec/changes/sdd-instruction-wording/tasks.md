# Tasks: sdd-instruction-wording

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1430 raw (6 full copies = 1421 vanilla LOC + 9 reworded lines) |
| Effective reviewable diff | 9 line edits (rest is identical-to-upstream copy/paste) |
| 400-line budget risk | High raw, Low effective |
| Chained PRs recommended | No (splitting creates model inconsistency during rollout) |
| Suggested split | Single PR — 2 repos: nixos-hosts + gentle-ai PR #988 |
| Delivery strategy | single-pr-default |
| size:exception | Accepted via fast-forward override |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | 8 override files in `shared/opencode/assets/skills/` | PR 1 (nixos-hosts) | atomic: 6 copies + 9 rewrites land together |
| 2 | Upstream PR #988 force-push | PR 2 (gentle-ai) | requires ASK before push |

## Phase 1: Copy Vanilla Files

Source: `${pkgs.gentle-ai-assets-vanilla}/share/gentle-ai/skills/`

- [ ] 1.1 `sdd-propose/SKILL.md` → `shared/opencode/assets/skills/sdd-propose/SKILL.md`
- [ ] 1.2 `sdd-design/SKILL.md` → `shared/opencode/assets/skills/sdd-design/SKILL.md`
- [ ] 1.3 `sdd-spec/SKILL.md` → `shared/opencode/assets/skills/sdd-spec/SKILL.md`
- [ ] 1.4 `sdd-tasks/SKILL.md` → `shared/opencode/assets/skills/sdd-tasks/SKILL.md`
- [ ] 1.5 `sdd-apply/SKILL.md` → `shared/opencode/assets/skills/sdd-apply/SKILL.md`
- [ ] 1.6 `sdd-archive/SKILL.md` → `shared/opencode/assets/skills/sdd-archive/SKILL.md`

## Phase 2: Rewording (8 files, 9 lines)

> Wording rule per spec: lead with Engram tool name; state "use `openspec/`" as positive alternative.

- [ ] 2.1 `sdd-propose/SKILL.md:47` — lead `mem_get_observation` + `mem_save(topic_key=...)`; "use `openspec/`"
- [ ] 2.2 `sdd-design/SKILL.md:46` — same pattern
- [ ] 2.3 `sdd-spec/SKILL.md:46` — same pattern
- [ ] 2.4 `sdd-tasks/SKILL.md:47` — same pattern
- [ ] 2.5 `sdd-apply/SKILL.md:49` — same pattern
- [ ] 2.6 `sdd-archive/SKILL.md:48` — same pattern
- [ ] 2.7 `sdd-explore/SKILL.md:46` — lead `mem_get_observation` + `mem_save(topic_key=...)`; "use `openspec/`"
- [ ] 2.8 `sdd-explore/SKILL.md:55` — lead `mem_search`; "use `openspec/`"
- [ ] 2.9 `sdd-init/SKILL.md:41` — lead `mem_save(topic_key=...)`; "use `openspec/`"

## Phase 3: Validation

- [ ] 3.1 `nix flake check --no-build` (must pass)
- [ ] 3.2 `nix build .#gentle-ai-assets` (no switch, verify derivation)
- [ ] 3.3 `rg -n 'save artifact as `sdd/|read `sdd/|search for `sdd/' shared/opencode/assets/skills/` returns zero

## Phase 4: Deploy

- [ ] 4.1 `nixos-build dry` to verify build closure
- [ ] 4.2 **ASK user** before `nixos-build switch`

## Phase 5: Commit

- [ ] 5.1 Git commit: `fix(sdd-assets): reword ambiguous sdd/ instructions to lead with engram tool names`
- [ ] 5.2 `git diff --stat` (expect: 8 files, ~1430 insertions)

## Phase 6: Upstream

- [ ] 6.1 **ASK user** before force-pushing PR #988 (`Gentleman-Programming/gentle-ai`)
- [ ] 6.2 On approval: force-push replacement commits removing guardrail-only approach from upstream

## Verification (per spec)

- [ ] V.1 GIVEN overlay assets dir, WHEN each of 9 overrides inspected, THEN every `sdd/...` ref leads with Engram tool name and is qualified as "Engram topic" or `topic_key=...`
- [ ] V.2 GIVEN a filesystem op, WHEN it directs away from `sdd/`, THEN it states "use `openspec/`" as positive alt
- [ ] V.3 Runtime smoke: launch `sdd-explore` for fresh change; confirm no `**/sdd/**` or `**/.sdd/**` globs in tool calls
