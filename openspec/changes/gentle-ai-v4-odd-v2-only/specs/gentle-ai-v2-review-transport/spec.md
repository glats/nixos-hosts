# gentle-ai-v2-review-transport Specification
## Purpose
Native authority preservation.
## Requirements
### Requirement: Truthful transport
Private Gentle/relay PATH MUST discover actual native V2 with `gentle-ai.opencode-relay/v2-staged`; declaration/SDK-contract identity alone MUST NOT prove compatibility.
#### Scenario: Admit proven roles [hosts:rog,thinkcentre,t14,macm5]
- GIVEN source/runtime proof and authorized delegation/lens/refuter/validator
- WHEN receipts validated
- THEN existing authority admits only correctly bound results.
#### Scenario: Refuse invalid transport [hosts:rog,thinkcentre,t14,macm5]
- GIVEN missing/wrong runtime/declaration/role, replay/stale/background/session-reuse
- WHEN admission attempted
- THEN refuse without authority mutation; loopback/rog proof never certifies fleet.
