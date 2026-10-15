# odd-managed-workflow Specification
## Purpose
History-safe ODD.
## Requirements
### Requirement: Authorized execution
Canonical source-default TDD MUST govern, not retired strict flags; runnable deterministic tests require RED/GREEN/refactor, exceptions disclose checks. Bounded delegation/executor limits MUST apply; repository/user mutation/publishing/instruction limits override defaults.
#### Scenario: Respect authorization [hosts:rog,thinkcentre,t14,macm5]
- GIVEN preparation-only consent
- WHEN planning completes
- THEN STOP before apply/pins/builds/models/activation/commits; no autonomous commit grant.

### Requirement: Durable recovery
Substantial work MUST persist full `odd/tasks/<feature>.md` and project Engram `odd/<feature>/tasks`, readback/reconcile stable identity before source writes; small/read-only work needs no artifact.
#### Scenario: Resume safely [hosts:rog,thinkcentre,t14,macm5]
- GIVEN interruption/conflict/Engram outage
- WHEN resumed
- THEN reconcile full documents/evidence; local progress retains pending mirror; never overwrite history automatically.

### Requirement: Selected cutover
SDD MUST remain until candidate proof; unfinished work requires explicit selection/handshake/history links, never bulk conversion.
#### Scenario: Preserve unfinished work [hosts:rog,thinkcentre,t14,macm5]
- GIVEN unfinished changes
- WHEN switching
- THEN only selected work reconciles; archives remain intact.
