# gentle-ai-declarative-runtime

## MODIFIED Requirements

### 1. Requirement: Tagged Source and Reproducible Build
Binary/assets MUST share v4.0.0 `ff77164d4f56f1665b22fb6fac51c2ccbb769400`, valid vendorHash/native builds; CLI/SDK initially remain 2.0.14.
(Previously: v2.5.0.)
#### Scenario: Pin and derivations agree [hosts:rog,thinkcentre,t14,macm5]
- GIVEN candidate
- WHEN built/inspected
- THEN provenance agrees; coupled upgrades require incompatibility evidence/approval.

### 2. Requirement: Managed Plugin Lifecycle
Home Manager MUST own reconciled V2 plugins, preserving host-config/RTK/Engram; V1 management stays retired, archives untouched.
(Previously: delivered retirement delta.)
#### Scenario: Enabled plugin deploys [hosts:rog,thinkcentre,t14,macm5]
- GIVEN enabled plugin
- WHEN activated
- THEN V2 asset deploys once.
#### Scenario: Disabled and legacy plugins are removed [hosts:rog,thinkcentre,t14,macm5]
- GIVEN disabled/legacy plugin
- WHEN reconciled
- THEN only proven-owned executable files retire; archives survive.

### 3. Requirement: Permission-Shaped Agent Grants
ODD/review/general/neutral/orchestrator grants MUST use permission, never tools; provider-policy/overrides MUST survive without blanket privilege transfer.
(Previously: SDD graph.)
#### Scenario: Generated grants survive migration [hosts:t14]
- GIVEN candidate
- WHEN agents inspected
- THEN grants/denials match; missing grants/tools fail.

### 4. Requirement: Obsolete Claude Commands Retire Declaratively
Executable SDD commands/aliases/skills MUST retire coherently across shared/Claude/OpenFang consumers; registry MUST use canonical V2 project-first roots, never archives.
(Previously: retained prefixed SDD.)
#### Scenario: Canary activation retires old commands [hosts:t14]
- GIVEN stale workflow files
- WHEN ownership/consumers checked
- THEN owned files retire; foreign/user files survive; unowned conflicts refuse.

### 5. Requirement: Tagged v2.x Update Runbook
Runbook MUST specify reproducible tagged updates, candidate-proof, authorized rog-first rollout/rollback; no main/.last-sync/install/sync/v1.22.0.
(Previously: t14-first v2.x.)
#### Scenario: Runbook is current [hosts:rog,thinkcentre,t14,macm5]
- GIVEN guide
- WHEN inspected
- THEN gates/rollback preserve histories/credentials/receipts/generations without V1.

### 6. Requirement: Shared Evaluation Gate
Formatting/flake-check/provider-equivalence/catalog-validity MUST pass.
(Previously: t14-only evaluation.)
#### Scenario: Repository and provider checks pass [hosts:rog,thinkcentre,t14,macm5]
- GIVEN candidate
- WHEN evaluated
- THEN three Linux systems, Darwin/integrated HM, four standalone HM pass; native-platform builds/runtime-readiness remain separate; unavailable evidence UNVERIFIED.

### Requirement: Routing Profiles Remain Independent
Profiles MUST remain full-JSON-equivalent except approved ODD-phase mappings and the explicit 2026-10-09 operator-approved retirement of exactly `opencode-free`, `anthropic-opencode-free`, and `anthropic-opencode-go` (#3979). The 32 retained profiles and their order MUST match the baseline after only the approved ODD transformation; no retained selector, variant, default profile or provider policy may change. Built-in identifiers MUST resolve after native deprecated-entry filtering, and NVIDIA MUST be explicitly declared.

The only additional provider-declaration exception is NVIDIA model key `nemotron-3-ultra-550b-a55b` with name `Nemotron 3 Ultra` and native V2 `modelID = nvidia/nemotron-3-ultra-550b-a55b`. This alias MUST preserve the existing backend model, canonical declaration, endpoint, authentication templates, headers and every unrelated provider field. Retirement MUST NOT introduce a replacement model, paid fallback or model-fit policy waiver. Selecting a retired profile MUST fail configuration rather than silently select another profile. Deprecated built-in selection MUST NOT be repaired by paid fallback or an undeclared substitute.
(Previously: byte-identical phase mappings.)
#### Scenario: Pruned and baseline routing are equivalent [hosts:rog,thinkcentre,t14,macm5]
- GIVEN baseline/candidate/catalog
- WHEN compared
- THEN unrelated profiles match; zero missing identifiers.
#### Scenario: Approved profile retirement preserves remaining routing [hosts:rog,thinkcentre,t14,macm5]
- GIVEN the 35-profile baseline and approved three-profile retirement
- WHEN full profile objects and order are compared after the existing ODD mappings
- THEN exactly the three approved names are absent, all 32 retained objects match, and all eight integrated/standalone host selections and override maps remain unchanged.
#### Scenario: Retired profile selection refuses fallback [hosts:rog,thinkcentre,t14,macm5]
- GIVEN an explicit selection of any retired profile name
- WHEN the declarative profile lookup is evaluated
- THEN configuration fails with an unknown-profile error; no paid/default profile is substituted.
#### Scenario: Native NVIDIA alias preserves the backend model [hosts:rog,thinkcentre,t14,macm5]
- GIVEN the existing canonical NVIDIA declaration and approved alias record
- WHEN the native 2.0.14 schema, first-slash selector parser and model resolver are inspected or tested without a model request
- THEN the short selector resolves to backend model ID `nvidia/nemotron-3-ultra-550b-a55b`; all other provider fields remain equal, and catalog membership is not presented as remote availability or uptime certification.
