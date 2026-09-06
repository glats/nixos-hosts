# Gentle AI Declarative Runtime Specification

## Purpose

Define the v2.5.0-aligned Gentle AI source, assets, plugins, agent permissions, command retirement, and update verification while Home Manager remains the sole deployment authority for every host.

## Requirements

### 1. Requirement: Tagged Source and Reproducible Build

`gentle-ai-src` MUST reference `github:Gentleman-Programming/gentle-ai/v2.5.0`; the lock entry MUST resolve that tag, and `pkgs/gentle-ai` MUST carry a valid `vendorHash`. Both derivations MUST consume this source.

#### Scenario: Pin and derivations agree [hosts: rog, thinkcentre, t14, mact2]
- GIVEN the updated flake and package definitions
- WHEN the lock entry and derivation inputs are inspected and built
- THEN the source resolves v2.5.0 and the vendor hash is accepted
- AND `gentle-ai-assets` exposes the v2.5.0 asset tree

### 2. Requirement: Managed Plugin Lifecycle

The module MUST expose `home.opencode.plugins.{modelVariants,opencodeReviewTransport,sddTaskResultArtifacts,skillRegistry}.enable`. Each option MUST default to false at declaration; shared configuration MUST enable `sddTaskResultArtifacts` and `skillRegistry`, while leaving the other two disabled. Each option MUST control its matching upstream asset.

`backgroundAgents`, its managed entry, and the `agent-teams-lite#58` warning MUST be absent. Activation MUST remove any existing `background-agents.ts`, including installations predating this option removal.

#### Scenario: Enabled plugin deploys [hosts: rog, thinkcentre, t14, mact2]
- GIVEN one managed plugin option is enabled
- WHEN Home Manager activation runs
- THEN its matching plugin file is deployed from `gentle-ai-assets`

#### Scenario: Disabled and legacy plugins are removed [hosts: rog, thinkcentre, t14, mact2]
- GIVEN a managed plugin is disabled or `background-agents.ts` already exists
- WHEN activation runs
- THEN the disabled or legacy file is absent

### 3. Requirement: Permission-Shaped Agent Grants

Generated agents MUST express grants through `permission`, MUST NOT emit agent `tools`, and MUST preserve each applicable write, edit, task, shell, read, delegation, and Engram grant. Local overlays MUST use permission-shaped data.

Completion MUST be gated on empirical inspection of generated `opencode.json` for `explore`, `general`, every `sdd-*`, `review-*`, and `jd-*` agent, plus `neutral` and `gentle-orchestrator`. A missing expected grant or any agent `tools` field MUST fail the change.

#### Scenario: Generated grants survive migration [hosts: t14]
- GIVEN t14's evaluated or built Home Manager configuration
- WHEN every named agent in generated `opencode.json` is inspected
- THEN all applicable prior grants are represented under `permission`
- AND no agent contains `tools`

### 4. Requirement: Obsolete Claude Commands Retire Declaratively

The v2.5.0 deployment MUST retain upstream `gentle-sdd-*` Claude commands and OpenCode's bare `sdd-*` commands. Existing Claude union orphan cleanup MUST retire all 11 unprefixed `~/.claude/commands/sdd-*.md` files without new imperative synchronization.

#### Scenario: Canary activation retires old commands [hosts: t14]
- GIVEN the 11 old files exist before activation
- WHEN the v2.5.0 Home Manager generation activates
- THEN none of those unprefixed Claude command files remain
- AND current upstream command names are deployed

### 5. Requirement: Tagged v2.x Update Runbook

The update guide MUST prescribe: bump the input tag, run `nix flake lock --update-input gentle-ai-src`, recompute `vendorHash`, build `.#gentle-ai-assets`, run `format-nix && nix flake check --no-build`, canary t14, then roll out other hosts. It MUST NOT reference v1.22.0, a `main` pin, or `.last-sync`.

#### Scenario: Runbook is current [hosts: rog, thinkcentre, t14, mact2]
- GIVEN `docs/gentle-ai-update.md` after the change
- WHEN its commands and version references are inspected
- THEN the ordered v2.x tagged workflow is complete and stale references are absent

### 6. Requirement: Shared Evaluation Gate

All changed Nix MUST be formatted, and `nix flake check --no-build` MUST pass for the shared configuration consumed by rog, thinkcentre, t14, and mact2 before rollout.

#### Scenario: Repository checks pass [hosts: rog, thinkcentre, t14, mact2]
- GIVEN all scoped edits are complete
- WHEN `format-nix && nix flake check --no-build` runs
- THEN both commands succeed

## Out of Scope

The theme component, GGA replaced by `providers-base.nix`, other agents' asset directories, `sdd-overlay-multi.json`, declarative-architecture doctor false positives (`state:json`, `engram:reachable`), the pre-existing `sdd-research` model gap, and changes to host consumption are excluded. Hosts MUST NOT run `gentle-ai install` or `gentle-ai sync`.
