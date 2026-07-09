# Delta for Agent Configuration

This is a new domain spec. No existing main spec exists.

## ADDED Requirements

### REQ-INJECT-1: SDD Sub-Agent Skill Fallback Path

All SDD phase sub-agents defined in `opencode.json` (sdd-apply, sdd-archive,
sdd-design, sdd-explore, sdd-init, sdd-propose, sdd-spec, sdd-tasks, sdd-verify)
MUST include an explicit "Read your skill file at..." fallback instruction in
their agent prompt. This instruction SHALL appear after the Global Rules section
and MUST reference the agent's specific skill file path. The fallback ensures
the agent can load its skill even when the orchestrator's path injection
mechanism fails or is omitted.

#### Scenario: sdd-apply has fallback read instruction

- GIVEN `~/.config/opencode/opencode.json` defines the sdd-apply agent
- WHEN the agent prompt is examined
- THEN it SHALL contain the instruction:
  "Read your skill file at `~/.config/opencode/skills/sdd-apply/SKILL.md`
   and follow it exactly."
- AND the instruction SHALL appear after the Global Rules section

#### Scenario: All 9 SDD phase agents have fallback read instructions

- GIVEN `~/.config/opencode/opencode.json` defines 9 SDD phase sub-agents:
  sdd-apply, sdd-archive, sdd-design, sdd-explore, sdd-init, sdd-propose,
  sdd-spec, sdd-tasks, sdd-verify
- WHEN each agent prompt is examined
- THEN each SHALL contain a "Read your skill file at..." instruction pointing
  to its corresponding skill file path
- AND the path SHALL match the skill directory under `~/.config/opencode/skills/`

#### Scenario: Fallback fires when orchestrator injection fails

- GIVEN the orchestrator launches an sdd-apply sub-agent
- AND the orchestrator's skill injection mechanism fails (no `## Skills to load
  before work` block in prompt)
- WHEN the sub-agent initializes
- THEN it reads its skill file via the fallback instruction
- AND proceeds with correct skill instructions loaded

### REQ-INJECT-2: Review Lens Agent Skill Fallback Path

All review lens agents defined in `opencode.json` (review-readability,
review-reliability, review-resilience, review-risk) MUST include an explicit
"Read your skill file at..." fallback instruction in their agent prompt. This
instruction SHALL appear after the Global Rules section and MUST reference
`~/.config/opencode/skills/judgment-day/SKILL.md`, which is the skill that
defines the review lenses' behavior.

#### Scenario: review-readability has fallback

- GIVEN `~/.config/opencode/opencode.json` defines the review-readability agent
- WHEN the agent prompt is examined
- THEN it SHALL contain the instruction:
  "Read your skill file at `~/.config/opencode/skills/judgment-day/SKILL.md`
   and follow it exactly."

#### Scenario: All 4 review lens agents have judgment-day fallback

- GIVEN `~/.config/opencode/opencode.json` defines 4 review lens agents:
  review-readability, review-reliability, review-resilience, review-risk
- WHEN each agent prompt is examined
- THEN each SHALL contain a "Read your skill file at..." instruction pointing
  to `~/.config/opencode/skills/judgment-day/SKILL.md`
- AND the instruction SHALL appear after the Global Rules section

#### Scenario: Review lens agent runs blind without fallback

- GIVEN the orchestrator launches a review-readability sub-agent
- AND the orchestrator forgets to inject the judgment-day skill path
- AND the review-readability agent has NO fallback (pre-change state)
- WHEN the agent initializes
- THEN it runs without judgment-day skill instructions
- AND its review output MAY be incomplete or off-protocol
- AND (post-change) with the fallback, the agent SHALL read judgment-day/SKILL.md
  and produce protocol-compliant review output

### REQ-INJECT-3: Judgment-Day Agent Skill Fallback Path

All judgment-day agents defined in `opencode.json` (jd-fix-agent, jd-judge-a,
jd-judge-b) MUST include an explicit "Read your skill file at..." fallback
instruction in their agent prompt. This instruction SHALL appear after the
Global Rules section and MUST reference
`~/.config/opencode/skills/judgment-day/SKILL.md`. The jd-fix-agent is the
agent that applies fixes after a blind dual review; jd-judge-a and jd-judge-b
are the paired blind review judges.

#### Scenario: jd-fix-agent has fallback

- GIVEN `~/.config/opencode/opencode.json` defines the jd-fix-agent
- WHEN the agent prompt is examined
- THEN it SHALL contain the instruction:
  "Read your skill file at `~/.config/opencode/skills/judgment-day/SKILL.md`
   and follow it exactly."

#### Scenario: Both judge agents have fallback

- GIVEN `~/.config/opencode/opencode.json` defines jd-judge-a and jd-judge-b
- WHEN each agent prompt is examined
- THEN each SHALL contain a "Read your skill file at..." instruction pointing
  to `~/.config/opencode/skills/judgment-day/SKILL.md`

#### Scenario: Neutral agent has fallback

- GIVEN `~/.config/opencode/opencode.json` defines the `neutral` agent
  (if present)
- WHEN the agent prompt is examined
- THEN it SHALL contain a fallback read instruction pointing to
  `~/.config/opencode/skills/judgment-day/SKILL.md` if it participates in
  the review workflow
- OR if the neutral agent does not exist, no change is needed

## ADDED Requirements (Guardrails)

### REQ-GUARD-3: opencode.json Validation After Changes

After any modification to `~/.config/opencode/opencode.json`, the file MUST be
validated to ensure:

1. The JSON is syntactically valid (parseable by a JSON parser).
2. All agent entries remain intact (no agent definition lost or truncated).
3. All required top-level keys are present (`agents`, `mcpServers`, etc. as
   applicable per the opencode schema).
4. Each modified agent's `prompt` field contains the expected fallback instruction.

#### Scenario: Valid JSON after edit

- GIVEN `opencode.json` is modified with fallback instruction additions
- WHEN the file is parsed as JSON
- THEN no parse errors SHALL be produced
- AND all agent definitions SHALL be present and structurally intact

#### Scenario: Fallback text present in all target agents

- GIVEN `opencode.json` is modified
- WHEN the prompt field of each review lens and judgment-day agent is inspected
- THEN the "Read your skill file at..." text SHALL be present
- AND the path SHALL reference `~/.config/opencode/skills/judgment-day/SKILL.md`
- AND the instruction SHALL appear after the Global Rules section

#### Scenario: Non-target agents unchanged

- GIVEN `opencode.json` is modified
- WHEN the prompt fields of agents NOT in the target list are inspected
  (e.g., orchestrator, custom agents, any non-review/jd/sdd agents)
- THEN their prompt content SHALL be unchanged from before the modification
- AND no fallback instruction SHALL have been added to them
