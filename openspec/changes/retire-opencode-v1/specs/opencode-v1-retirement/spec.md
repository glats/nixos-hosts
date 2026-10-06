# opencode-v1-retirement Specification

## Purpose

Retire V1 safely.

## Requirements

### Requirement: V2-only delivery

V1 packages/exports/consumption/config-emission/activation/options/exclusive-plugins MUST retire; bare `opencode` MUST NOT alias V2.

#### Scenario: Inspect delivery [hosts:rog,thinkcentre,t14,macm5]
- GIVEN retirement
- WHEN wiring is inspected
- THEN V1/alias are absent

### Requirement: Archival safety

V1 config/auth/sessions, generations, overlapping dirty work and historical docs/spec-archives MUST remain untouched; destructive migration/GC MUST NOT occur.

#### Scenario: Preserve archives [hosts:rog,thinkcentre,t14,macm5]
- GIVEN V1 data
- WHEN retirement activates
- THEN data remains unchanged

### Requirement: V2 continuity

`opencode2`/`opencode2-home`, isolation/server-identity/standalone-behavior/pins/credentials/MCP/Engram/providers/shared-modules/packages/API-key-exports MUST survive. Gentle AI MUST remain v2.5.0; namespace-cutover/v3/v4/ODD MUST NOT occur.

#### Scenario: Compare V2 [hosts:rog,thinkcentre,t14,macm5]
- GIVEN baseline V2
- WHEN retirement is compared
- THEN runtime contracts remain equivalent

### Requirement: Safe helpers and skills

Go helper defaults MUST target isolated V2 without shell-alias/raw-native bypass; OpenFang MUST sync V2 skills.

#### Scenario: Exercise helpers [hosts:rog,thinkcentre,t14,macm5]
- GIVEN V1 absent
- WHEN launch/auth-seed/remote-sync defaults execute
- THEN they use V2 and OpenFang receives V2 skills

#### Scenario: Unavailable target [hosts:rog,thinkcentre,t14,macm5]
- GIVEN V2 unavailable
- WHEN helpers execute
- THEN failure causes no V1 fallback/data-writes

### Requirement: Acceptance evidence

All-host evaluation/regressions/reachable-smoke MUST pass; unavailable remote evidence MUST be UNVERIFIED.

#### Scenario: Collect evidence [hosts:rog,thinkcentre,t14,macm5]
- GIVEN retirement candidate
- WHEN flake-check, Linux/Darwin toplevel drvPaths, separate four-host standalone-HM activation drvPaths, Go tests, home-launcher.test.py and config/isolation/helper/auth/proxy/OpenFang regressions run
- THEN successes and reachable smoke are recorded; unavailable remote smoke is UNVERIFIED
