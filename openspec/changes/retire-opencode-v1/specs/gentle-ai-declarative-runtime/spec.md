# gentle-ai-declarative-runtime

## MODIFIED Requirements

### 2. Requirement: Managed Plugin Lifecycle

V1 plugin options/emission/cleanup MUST retire; Home Manager MUST retain current V2 assets, grants and plugin ownership.

(Previously: V1 deployment/cleanup options.)

#### Scenario: Enabled plugin deploys [hosts:rog,thinkcentre,t14,macm5]
- GIVEN enabled V2 plugins
- WHEN activation runs
- THEN matching V2 assets deploy

#### Scenario: Disabled and legacy plugins are removed [hosts:rog,thinkcentre,t14,macm5]
- GIVEN disabled/legacy V1 files
- WHEN retirement activates
- THEN V1 management retires without deleting archival files
