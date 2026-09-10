# Harness Token Efficiency Specification

## Purpose

Define a measured, private RTK 0.41.0 shell-output pilot for OpenCode and Claude Code.

## Requirements

### Requirement: RTK Installation and Exposure

The system MUST expose pinned `pkgs.rtk` 0.41.0 through `lib/packages.nix` and install it for rog, thinkcentre, t14, and mact2 without adding a flake input.

#### Scenario: RTK is available on every pilot host [hosts: rog, thinkcentre, t14, mact2]
- GIVEN each host's evaluated configuration
- WHEN package exposure and executable availability are inspected
- THEN every host provides RTK 0.41.0 from the shared source

### Requirement: Telemetry and Local Tracking

The system MUST export `RTK_TELEMETRY_DISABLED=1`, keep local gain tracking enabled, and MUST NOT transmit pilot measurements.

#### Scenario: Telemetry is disabled while local gain works [hosts: rog, thinkcentre, t14, mact2]
- GIVEN intercepted commands ran in the managed environment
- WHEN telemetry state and project gain are inspected
- THEN outbound telemetry is disabled and local estimates remain available

### Requirement: Managed OpenCode Plugin

The system MUST vendor RTK 0.41.0's official `rtk.ts`, manage and enable it through the shared plugin lifecycle, and preserve its `tool.execute.before` mutation and fail-open behavior.

#### Scenario: Plugin rewrites or passes through safely [hosts: rog, thinkcentre, t14, mact2]
- GIVEN the managed plugin is enabled
- WHEN OpenCode invokes supported, unsupported, and failed-rewrite shell commands
- THEN supported commands are rewritten and all others execute unchanged

### Requirement: Non-Destructive Claude Hook Merge

The system MUST merge a Bash-only `PreToolUse` entry running `rtk hook claude` into generated Claude settings without replacing other settings or hooks. Built-in Read, Grep, and Glob MUST bypass it.

#### Scenario: Existing Claude settings survive [hosts: rog, thinkcentre, t14, mact2]
- GIVEN generated settings contain other values and hooks
- WHEN the RTK Bash matcher is added
- THEN prior settings remain, the RTK command appears once, and non-Bash tools bypass it

### Requirement: Representative Pilot Measurement

The pilot MUST collect `rtk gain --project` and `rtk gain --project --history` reports for representative Git, `go -C pkgs/nixos-scripts test ./...`, `nix flake check --no-build`, and `nixos-build` sessions while preserving outcomes and exit codes.

#### Scenario: Measurement covers the agreed workload [hosts: rog, thinkcentre, t14, mact2]
- GIVEN representative harness sessions have run
- WHEN both project gain reports are recorded
- THEN every workload, rewrite, passthrough gap, token estimate, and percentage is inspectable

### Requirement: Pilot Runbook

`docs/rtk-pilot.md` MUST document checks, workloads, gain recording, shell-output-only interpretation, Read/Grep/Glob limitations, `RTK_DISABLED=1` raw bypass, failure recall, and disable/revert guidance. It MUST NOT claim total-spend savings.

#### Scenario: Operator can evaluate and disable the pilot [hosts: rog, thinkcentre, t14, mact2]
- GIVEN an operator opens the runbook
- WHEN they follow its measurement or recovery guidance
- THEN recording fields, limitations, raw recovery, and disable steps are complete

### Requirement: Reversible and Fail-Open Rollback

One change revert MUST restore pre-pilot package, OpenCode, and Claude behavior. Interception failures MUST leave original commands executable.

#### Scenario: Single revert restores the baseline [hosts: rog, thinkcentre, t14, mact2]
- GIVEN the pilot is deployed
- WHEN its change is reverted
- THEN all RTK integration is removed and baseline commands retain their outcomes and exit codes

### Requirement: Repository and Host Invariance

The change MUST pass `format-nix` and `nix flake check --no-build`, preserve other host behavior, and MUST NOT add shell scripts, custom filters, secrets, Hermes, or `hardware-configuration.nix` edits.

#### Scenario: Scoped repository gates pass [hosts: rog, thinkcentre, t14, mact2]
- GIVEN all pilot edits are complete
- WHEN formatting, flake evaluation, and scoped-path inspection run
- THEN both commands pass and prohibited or unrelated changes are absent
