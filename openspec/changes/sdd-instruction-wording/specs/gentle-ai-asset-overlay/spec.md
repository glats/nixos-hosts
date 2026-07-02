# Delta for gentle-ai-asset-overlay

## MODIFIED Requirements

### Requirement: Self-Explanatory Override Files

The `shared/opencode/assets/` directory MUST contain override files for all 9 SDD skill entry points: `sdd-orchestrator.md` and `skills/sdd-{explore,init,propose,design,spec,tasks,apply,archive}/SKILL.md`. Each override MUST replace ambiguous instruction lines with self-explanatory wording following this pattern:

1. Lead with the Engram tool name (`mem_search`, `mem_get_observation`, `mem_save`)
2. Explicitly qualify each `sdd/...` reference as an "Engram topic" or `topic_key=...`
3. When directing away from `sdd/` for filesystem operations, state "use `openspec/`" as the positive alternative

(Previously: 3 override files with guardrail notes distinguishing Engram topic keys from filesystem paths)

#### Scenario: All 9 overrides use self-explanatory wording

- GIVEN the overlay assets directory exists
- WHEN each of the 9 override files is inspected
- THEN every instruction line referencing `sdd/...` SHALL lead with an Engram tool name
- AND each `sdd/...` reference SHALL be qualified as "Engram topic" or `topic_key=...`
- AND no bare `sdd/` glob SHALL appear without tool-name context

#### Scenario: Filesystem operations direct to openspec/

- GIVEN an override file contains a filesystem operation instruction
- WHEN the instruction directs away from `sdd/` paths
- THEN it SHALL state "use `openspec/`" as the positive alternative
- AND it SHALL NOT rely solely on "don't use `sdd/`" without the `openspec/` redirect
