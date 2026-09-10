# opencode-omo-pilot Specification

## Purpose

Define a reversible rog-only OmO pilot.

## Requirements

### Requirement: OpenCode 1.18.22 Compatibility

OpenCode MUST pin exactly 1.18.22 with four platform hashes, consistent with npm constraint `^1.18.22`. It MUST load `engram.ts`, `rtk.ts`, `secret-guard.ts`, `skill-registry.ts`, and `sdd-task-result-artifacts.ts`; failure MUST block acceptance.

#### Scenario: Binary and plugins pass [hosts: rog, thinkcentre, t14, mact2]
- GIVEN four platform artifacts and five live plugins
- WHEN package metadata and plugin load checks run on OpenCode 1.18.22
- THEN every hash is valid and every plugin loads successfully

#### Scenario: Plugin failure rolls back [hosts: rog]
- GIVEN any managed plugin fails on 1.18.22
- WHEN the binary rollback is applied
- THEN 1.18.18 and its matching hashes restore the prior working state

### Requirement: Host-Scoped Declarative Opt-In

`home.opencode.omo.enable` MUST default false and be true only for rog. Enabled hosts MUST receive the `oh-my-openagent` plugin, pinned npm dependency, `~/.omo/omo.jsonc`, and `OMO_DISABLE_POSTHOG=1`; disabled hosts MUST receive none. The workflow MUST NOT invoke `bunx oh-my-openagent install`.

#### Scenario: Rog enables the complete pilot [hosts: rog]
- GIVEN rog opts into OmO
- WHEN its Home Manager configuration is evaluated
- THEN the plugin, dependency, config file, and environment variable are present
- AND no imperative installer is required

#### Scenario: Default-off hosts remain clean [hosts: thinkcentre, t14, mact2]
- GIVEN each host keeps the default option value
- WHEN its generated OpenCode configuration, files, and environment are evaluated
- THEN no OmO plugin entry, `omo.jsonc`, or OmO environment variable exists

### Requirement: OmO Safety and Category Policy

The deployed OmO configuration MUST disable telemetry, Team Mode, AGENTS.md injection, rules injection, and MCPs `websearch`, `context7`, and `grep_app`; it MUST retain LSP. Categories `quick` MUST target the light tier, while `deep` and `ultrabrain` MUST target the reasoning tier.

#### Scenario: Rog configuration enforces pilot policy [hosts: rog]
- GIVEN the generated `~/.omo/omo.jsonc`
- WHEN safety, MCP, hook, Team Mode, and category settings are inspected
- THEN every required disablement and category mapping matches policy
- AND LSP remains enabled

### Requirement: Centralized OpenCode Ownership

OmO generation MUST remain centralized in `shared/opencode/runtime-config.nix`, `plugins.nix`, and `shared/opencode.nix`; its host flag MUST follow the `activeProviderName` option pattern. `shared/claude-code.nix` MUST remain unchanged.

#### Scenario: Pilot remains isolated from Claude Code [hosts: rog]
- GIVEN the completed pilot diff
- WHEN ownership and touched files are inspected
- THEN OmO generation is confined to shared OpenCode modules and rog's opt-in
- AND the Claude Code module has no changes
