# Delta for Orchestrator Runtime

## ADDED Requirements

### REQ-INJECT-4: Skill Injection Verification Gate

The orchestrator MUST verify that skill paths have been correctly injected into a
sub-agent's launch prompt before delegating work. After the orchestrator constructs
a sub-agent prompt with a `## Skills to load before work` block, the orchestrator
MUST:

1. Verify every path in the injected block resolves to an existing file.
2. Verify the count of injected skill paths matches the expected count for that phase.
3. If verification fails, retry injection exactly once.
4. If the retry also fails, the orchestrator MUST abort with a clear error message
   identifying which skill paths are missing or invalid.

The verification step MUST be documented in `sdd-orchestrator.md` as a mandatory
step in the sub-agent launch protocol.

#### Scenario: All injected paths resolve correctly

- GIVEN the orchestrator injects 3 skill paths for an sdd-apply sub-agent:
  `~/.config/opencode/skills/sdd-apply/SKILL.md`,
  `~/.config/opencode/skills/_shared/sdd-phase-common.md`,
  `~/.config/opencode/skills/nix-verify/SKILL.md`
- WHEN the orchestrator runs the verification step
- THEN all 3 files are confirmed to exist
- AND the orchestrator proceeds to launch the sub-agent

#### Scenario: Missing injected path triggers retry

- GIVEN the orchestrator injects a path that does not exist on disk
- WHEN the orchestrator runs the verification step
- THEN it detects the missing path
- AND it retries injection exactly once
- AND if the retry also fails, it aborts with error:
  "Skill injection failed: path {path} does not exist"

#### Scenario: Count mismatch triggers abort

- GIVEN the orchestrator expected to inject 3 skill paths
- BUT only 2 paths were injected
- WHEN the orchestrator runs the verification step
- THEN it detects the count mismatch
- AND it aborts with error: "Skill injection failed: expected 3 skills, injected 2"

#### Scenario: Verification step is documented in orchestrator asset

- GIVEN this change is applied
- WHEN reading `~/.config/opencode/sdd-orchestrator.md`
- THEN a verification subsection under the skill delegation/injection section
  SHALL describe the verification protocol
- AND the subsection SHALL be marked as mandatory

### REQ-INJECT-5: Skill-Registry Pre-Load at Orchestrator Startup

The orchestrator MUST read the skill-registry at startup, before launching any
SDD phase sub-agents. This ensures the orchestrator can fall back to registry-based
skill path resolution if the primary injection mechanism fails. The orchestrator
SHALL search for the registry in this order:

1. `mem_search(query: "skill-registry", project: "{current-project}")` -- if found,
   retrieve full content via `mem_get_observation`.
2. `~/.config/opencode/.atl/skill-registry.md` or `.atl/skill-registry.md` -- if
   the file exists, read it.
3. If neither is found, the orchestrator SHALL log a warning but proceed.

The registry SHALL be cached in session memory for the duration of the session.

#### Scenario: Registry found in Engram

- GIVEN a skill-registry observation exists in Engram for the current project
- WHEN the orchestrator starts up
- THEN it calls `mem_search` with query "skill-registry"
- AND retrieves the full content via `mem_get_observation`
- AND caches the result for the session

#### Scenario: Registry found on filesystem

- GIVEN no Engram registry exists
- BUT `.atl/skill-registry.md` exists in the project root
- WHEN the orchestrator starts up
- THEN it reads the file
- AND caches the result for the session

#### Scenario: No registry found -- warning only

- GIVEN no registry exists in Engram or on the filesystem
- WHEN the orchestrator starts up
- THEN it logs a warning: "No skill-registry found. Skill path resolution limited to
  direct injection."
- AND proceeds normally (does not abort)

#### Scenario: Registry is available as fallback for injection

- GIVEN the primary injection mechanism fails
- AND the registry was cached at startup
- WHEN the orchestrator needs to resolve a skill path
- THEN it uses the registry to derive the correct skill file path
- AND includes the path in its retry injection attempt

## MODIFIED Requirements

### ORC-RC-004: Deterministic Verdict Routing

After reading the checkpoint, the orchestrator MUST apply the following
verdict decision table without discretion. No additional heuristics or
intermediate states are permitted.

| Verdict | Action |
|---|---|
| `done` | Continue to next phase (`sdd-verify` or next apply slice) |
| `redo` | Continue to next phase (escape hatch; record verdict as `redo`) |
| `amend` | STOP; present binary decision |
| `reiterate` | (not a checkpoint verdict; selected at binary decision) |
| missing / unreadable | STOP; report "no review-checkpoint found" |

The orchestrator MUST NOT invent an intermediate action (e.g. inline fix,
partial rework, silent continue) that is not in this table.

NOTE: The previous verdicts `blocked` and `pending` are removed. They had no
distinct codepath and behaved identically to `amend`. For backward compatibility,
any existing checkpoint with `blocked` or `pending` SHALL be treated as `amend`.

#### Scenario: Done continues

- GIVEN review-checkpoint verdict is `done`
- WHEN the orchestrator reads the checkpoint
- THEN it launches `sdd-verify` without asking the user

#### Scenario: Amend halts

- GIVEN review-checkpoint verdict is `amend`
- WHEN the orchestrator reads the checkpoint
- THEN it STOPS, MUST NOT auto-advance, and presents the binary decision

#### Scenario: Legacy blocked treated as amend

- GIVEN review-checkpoint verdict is `blocked` (legacy artifact)
- WHEN the orchestrator reads the checkpoint
- THEN it STOPS and presents the binary decision; behavior identical to `amend`

#### Scenario: Legacy pending treated as amend

- GIVEN review-checkpoint verdict is `pending` (legacy artifact)
- WHEN the orchestrator reads the checkpoint
- THEN it STOPS and presents the binary decision; does not assume the review
  will resolve in the affirmative

### ORC-RC-005: Binary Decision Presentation

When the gate requires a stop (verdict: `amend`, or missing checkpoint), the
orchestrator MUST present exactly two options to the user via the `question`
tool or equivalent interactive prompt:

1. **reiterate** -- re-explore -> re-apply (reads all previous artifacts as
   context; each phase overwrites its artifact)
2. **redo** -- skip the gate; record verdict as `redo` and continue to
   the next phase

The orchestrator MUST NOT offer a third option (e.g. inline fixes, partial
rework) at this gate. Rationale: a failed review indicates the approach needs
re-examination; partial fixes without re-exploration lead to invented solutions.
This rule is consistent with `RP-002` in the `review-gates` spec.

#### Scenario: Binary decision presented -- amend

- GIVEN review-checkpoint verdict is `amend`
- WHEN the orchestrator reads the checkpoint
- THEN it presents exactly two options: `reiterate` and `redo`
- AND no third option (inline fix, partial rework) is offered

#### Scenario: Binary decision presented -- missing checkpoint

- GIVEN no `review-checkpoint` artifact found
- WHEN the orchestrator runs the gate
- THEN it reports "no review-checkpoint found" and presents `reiterate`
  or `redo` as recovery options

### ORC-RC-006: Verify Gate Hard Block

The orchestrator MUST NOT launch `sdd-verify` unless the latest
`review-checkpoint` for the active change has verdict `done` or `redo`.
This constraint applies even when the user has not explicitly asked for a
review check.

#### Scenario: Verify blocked without checkpoint

- GIVEN no passing review-checkpoint exists
- WHEN the orchestrator is about to launch `sdd-verify`
- THEN it MUST run the gate first and MUST NOT bypass it
- AND if the gate returns a stop condition, verify is not launched

#### Scenario: Verify allowed after done

- GIVEN review-checkpoint verdict is `done`
- WHEN the orchestrator evaluates the gate before `sdd-verify`
- THEN it launches `sdd-verify` immediately

### ORC-RC-001: Review-Checkpoint Gate Section

(NOTE: Section heading and structure remain the same as in main spec.
Terminology within the section is updated per the RENAMED mapping: approved->done,
changes-requested->amend, full-iteration->reiterate, proceed->redo, blocked->removed,
pending->removed. Scenarios unchanged except for verdict names.)
