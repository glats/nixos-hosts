# Delta for Gentle AI Declarative Runtime

## MODIFIED Requirements

### 1. Requirement: Tagged Source and Reproducible Build

The binary and rendered assets MUST consume v4.1.1 source `898d3976e8049a7238eaa7de60bff325c30d2b3d`; the lock entry MUST match and the vendor hash MUST be valid.
(Previously: both derivations consumed v2.5.0.)

#### Scenario: Pin and derivations agree [hosts: rog, thinkcentre, t14, macm5]
- GIVEN the updated source and derivations
- WHEN their inputs are inspected and packages built
- THEN both use the exact v4.1.1 revision and builds accept the vendor hash
- AND the binary reports `4.1.1`

### 2. Requirement: Managed Plugin Lifecycle

OpenCode V2 MUST use the v4 managed ODD asset set, including `gentle-ai-explore`, `gentle-ai-worker`, `gentle-ai-verify`, the ODD orchestrator, skill registry, and upstream V2 review transport. Managed SDD runtime assets, `sdd-task-result.ts`, and legacy `background-agents.ts` MUST retire.
(Previously: shared configuration enabled SDD task-result and skill-registry plugins.)

#### Scenario: Enabled plugin deploys [hosts: rog]
- GIVEN the v4 managed configuration
- WHEN Home Manager activates
- THEN the v4 agents and enabled upstream plugins are available in opencode-v2

#### Scenario: Disabled and legacy plugins are removed [hosts: rog]
- GIVEN unchanged owned legacy assets exist
- WHEN reconciliation activates the v4 generation
- THEN retired or disabled managed assets are absent and upstream V2 review transport remains

### 6. Requirement: Shared Evaluation Gate

rog toplevel and Home Manager builds, focused existing checks, `nix flake check --no-build`, all Linux host evaluations, and macm5 Darwin and standalone Home Manager evaluations MUST pass. Non-rog deployment is NOT required.
(Previously: acceptance required baseline-profile equality, live catalog checks, and t14-first evaluation.)

#### Scenario: Repository and provider checks pass [hosts: rog, thinkcentre, t14, macm5]
- GIVEN scoped edits are complete
- WHEN the required builds, checks, and evaluations run
- THEN all succeed without deploying other hosts

### Requirement: Routing Profiles Remain Independent

rog MUST select `anthropic-openai-opencode`. Profiles `opencode-free`, `anthropic-opencode-free`, and `anthropic-opencode-go` MUST be absent. The NVIDIA nemotron alias and native V2 provider projection MUST remain. Existing `sdd-*` phase mappings MUST target the applicable v4 explore, worker, or verify agent.
(Previously: every baseline profile and mapping had to remain byte-identical.)

#### Scenario: Approved routing replaces baseline equality [hosts: rog, thinkcentre, t14, macm5]
- GIVEN evaluated provider and agent configuration
- WHEN routing is inspected
- THEN the approved selection, removals, NVIDIA retention, and v4 phase remapping are present

## ADDED Requirements

### Requirement: Ownership-Safe Asset Reconciliation

`ai-assets-reconcile` MUST be available and reconcile Home Manager-managed assets with the pinned revision as provenance. It MUST fail closed on edited assets, symlinks, or incompatible pending journals; upstream install/sync MUST NOT replace Home Manager authority.

#### Scenario: Clean reconciliation [hosts: rog]
- GIVEN conflict-free managed assets
- WHEN reconciliation runs
- THEN it succeeds with provenance matching the pinned revision

#### Scenario: Ownership conflict [hosts: rog]
- GIVEN an edited owned asset, symlink conflict, or incompatible pending journal
- WHEN reconciliation runs
- THEN it refuses activation without overwriting conflicting content

### Requirement: Authorized rog Activation

A separately authorized `nixos-build switch` MUST leave `home-manager-glats.service` green and expose the accepted binary and assets.

#### Scenario: Switch succeeds [hosts: rog]
- GIVEN explicit switch authorization and passing build gates
- WHEN rog switches
- THEN the service is active and successful, `gentle-ai --version` reports `4.1.1`, and reconciled v4 assets are present

### Requirement: User ODD Acceptance

The user MUST complete one real ODD session in opencode2. Private paid model cycles, threat matrices, receipts, and non-rog deployment MUST NOT be acceptance gates.

#### Scenario: User completes ODD [hosts: rog]
- GIVEN the activated v4 environment
- WHEN the user runs one real ODD session in opencode2
- THEN user-confirmed completion satisfies the session gate; version/help output alone does not
