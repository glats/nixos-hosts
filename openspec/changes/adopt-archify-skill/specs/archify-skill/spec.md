# Archify Skill Specification

## Purpose

Provide a reproducible, private, on-demand Archify skill to both managed agents.

## Requirements

### Requirement: Pinned Reproducible Skill Source

The system MUST source `tt-a1i/archify` only at `d673e8300df60a5c8166abe78787fdc78f6b8000`. Source and locked npm closure MUST have reviewed fixed Nix hashes. The package MUST retain its runnable tree and Node dependencies, and MUST NOT use a flake input, runtime `npx`, or an unpinned installer.

#### Scenario: Fixed source and dependency closure [hosts: all managed]

- GIVEN package definitions and the upstream lockfile
- WHEN revision, hashes, and installed tree are inspected
- THEN the revision and both fixed hashes MUST be present
- AND the runnable tree MUST not depend on a network install

### Requirement: Complete Shared Agent Deployment

The system MUST deploy the same packaged Archify tree through the shared skill-source union to `~/.config/opencode/skills/archify` and `~/.claude/skills/archify` on rog, thinkcentre, t14, and mact2.

#### Scenario: Both agents receive identical skill content [hosts: all managed]

- GIVEN Home Manager activation on a supported host
- WHEN the two managed Archify directories are compared with the package tree
- THEN each directory MUST be complete and content-identical to the package tree

### Requirement: Offline Update and Privacy Policy

The managed environment MUST set `ARCHIFY_UPDATE_CHECK_DISABLED=1` for both agents. Inputs and outputs MUST use reviewed public revision-pinned facts and MUST NOT include secrets or sensitive topology. Node MUST rely on existing declarative Linux and Darwin provision.

#### Scenario: Update check is disabled for both launches [hosts: all managed]

- GIVEN either managed agent launches Archify offline
- WHEN its environment and `archify doctor` are inspected
- THEN the disable variable MUST equal `1`
- AND no update-manifest request or runtime installation MUST occur

#### Scenario: Sensitive input is rejected [hosts: all managed]

- GIVEN an Archify request includes a secret or sensitive topology detail
- WHEN output preparation is reviewed
- THEN that detail MUST NOT appear in generated input or artifact

### Requirement: On-Demand Artifact Safeguards

Archify MUST generate output only on explicit request. Reviewed artifacts MAY be written only under ignored `docs/artifacts/archify/`; automatic generation, preview servers, browser opening, and artifact-based runtime or verification proof are prohibited. Diagrams are assistive documentation, not behavior evidence.

#### Scenario: Explicit reviewed artifact generation [hosts: all managed]

- GIVEN an explicit request using approved public facts
- WHEN an artifact is generated and retained
- THEN it MUST be under ignored `docs/artifacts/archify/` and be reviewable

#### Scenario: Implicit or unsafe output is blocked [hosts: all managed]

- GIVEN no explicit request, an unsafe destination, or a request for preview/opening
- WHEN Archify use is proposed
- THEN no artifact, preview server, or browser action MUST occur

### Requirement: Scoped Rollback

Reverting this change MUST remove Archify source, environment, deployment, and artifact policy without changing Node, unrelated skills, px0, secrets, or other host behavior.

#### Scenario: Declarative rollback restores the baseline [hosts: all managed]

- GIVEN Archify has been activated
- WHEN the change is reverted and Home Manager activates
- THEN Archify and its update variable MUST be absent
- AND Node and unrelated agent assets MUST remain unchanged

### Requirement: Cross-Platform Validation

The change MUST pass `format-nix` and `nix flake check --no-build`, evaluate affected Linux and x86_64-darwin configurations, and build Archify where a native executor is available. Missing native builds MUST be recorded as infrastructure limitations, never replaced by diagram output as proof.

#### Scenario: Available platform gates pass [hosts: all managed]

- GIVEN native Linux and x86_64-darwin build executors are available
- WHEN formatting, evaluation, and each platform build run
- THEN every command MUST succeed with the fixed hashes accepted

#### Scenario: Unavailable native executor is reported honestly [hosts: all managed]

- GIVEN one platform has no native package-build executor
- WHEN validation completes
- THEN its configuration evaluation MUST still run
- AND the missing build MUST be recorded without behavior-as-proof substitution
