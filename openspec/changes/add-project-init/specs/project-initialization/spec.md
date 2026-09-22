# Project Initialization Specification

## Purpose

Define `opencode-harness-init`, a Go operational CLI that bootstraps a directory into an Engram/OpenSpec project. It derives a project name, writes an explicit Engram marker, detects Git context, and optionally triggers OpenSpec initialization — safely, idempotently, and reversibly. `ohi` MUST be its shared shell alias.

## Requirements

### Requirement: Project Identification and Engram Marker

`opencode-harness-init` MUST derive the project name from `--name` when supplied, otherwise from the target directory's basename. It MUST write `.engram/config.json` containing that `project_name` as the explicit Engram marker. The write MUST use a temp-file + rename so an existing config's mode and content survive a failed write.

#### Scenario: Name from --name (Hosts: All NixOS and Darwin hosts)

- GIVEN a directory without `.engram/config.json`
- WHEN the user runs `opencode-harness-init --name demo DIR`
- THEN `.engram/config.json` is written with `project_name` = `demo`

#### Scenario: Name from directory basename (Hosts: All NixOS and Darwin hosts)

- GIVEN a directory named `myproject` without `.engram/config.json`
- WHEN the user runs `opencode-harness-init DIR` without `--name`
- THEN `.engram/config.json` is written with `project_name` = `myproject`

### Requirement: Target Directory Selection

`opencode-harness-init` MUST default to the current directory when `DIRECTORY` is omitted. When `DIRECTORY` is supplied it MUST be the initialization root and MUST exist.

#### Scenario: Defaults to current directory (Hosts: All NixOS and Darwin hosts)

- GIVEN the current directory contains no Engram marker
- WHEN the user runs `opencode-harness-init` with no positional argument
- THEN the current directory is initialized

#### Scenario: Missing directory rejected (Hosts: All NixOS and Darwin hosts)

- GIVEN a `DIRECTORY` path that does not exist
- WHEN the user runs `opencode-harness-init DIR`
- THEN the command reports an error, exits non-zero, and writes nothing

### Requirement: Git Context Detection

`opencode-harness-init` MUST classify the target as a Git repository, a Git worktree, or non-Git by walking ancestors for a `.git` directory or `.git` file (worktree marker). Detection MUST NOT alter Git state.

#### Scenario: Git repository detected (Hosts: All NixOS and Darwin hosts)

- GIVEN a directory whose ancestor contains a `.git` directory
- WHEN `opencode-harness-init` runs on that directory
- THEN the directory is classified as a Git repository

#### Scenario: Worktree detected via .git file (Hosts: All NixOS and Darwin hosts)

- GIVEN a worktree whose ancestor contains a `.git` file pointing elsewhere
- WHEN `opencode-harness-init` runs on that directory
- THEN the directory is classified as a Git worktree

#### Scenario: Non-Git directory detected (Hosts: All NixOS and Darwin hosts)

- GIVEN a directory whose ancestors contain neither a `.git` directory nor a `.git` file
- WHEN `opencode-harness-init` runs on that directory
- THEN the directory is classified as non-Git

### Requirement: Safe Idempotence

When an existing `.engram/config.json` already carries the derived name, `opencode-harness-init` MUST report `current` and make no changes.

#### Scenario: Matching existing name is a no-op (Hosts: All NixOS and Darwin hosts)

- GIVEN `.engram/config.json` with `project_name` equal to the derived name
- WHEN the user runs `opencode-harness-init`
- THEN the command reports `current` and writes nothing

### Requirement: Conflicting Marker Rejection

When an existing `.engram/config.json` carries a differing name, `opencode-harness-init` MUST report `conflict` and exit non-zero without overwriting, unless `--force` is supplied.

#### Scenario: Differing name rejected without --force (Hosts: All NixOS and Darwin hosts)

- GIVEN `.engram/config.json` with a differing `project_name`
- WHEN the user runs `opencode-harness-init` without `--force`
- THEN the command reports `conflict`, exits non-zero, and leaves the marker unchanged

#### Scenario: --force overwrites conflicting name (Hosts: All NixOS and Darwin hosts)

- GIVEN `.engram/config.json` with a differing `project_name`
- WHEN the user runs `opencode-harness-init --force`
- THEN the marker is overwritten with the derived name

### Requirement: Dry Run

With `--dry-run`, `opencode-harness-init` MUST report intended actions and write nothing.

#### Scenario: Dry run writes nothing (Hosts: All NixOS and Darwin hosts)

- GIVEN any target directory
- WHEN the user runs `opencode-harness-init --dry-run`
- THEN the command reports the planned classification and writes
- AND no `.engram/config.json` or OpenSpec files are created

### Requirement: OpenSpec Initialization Control

`opencode-harness-init` MUST trigger `openspec init` only when `openspec/config.yaml` is absent. With `--no-openspec`, it MUST skip OpenSpec initialization entirely.

#### Scenario: OpenSpec init skipped when config exists (Hosts: All NixOS and Darwin hosts)

- GIVEN `openspec/config.yaml` already exists
- WHEN the user runs `opencode-harness-init` without `--no-openspec`
- THEN no `openspec init` runs

#### Scenario: --no-openspec skips initialization (Hosts: All NixOS and Darwin hosts)

- GIVEN a directory with no `openspec/config.yaml`
- WHEN the user runs `opencode-harness-init --no-openspec`
- THEN the Engram marker is written and no OpenSpec files are created

### Requirement: Package Wrapper Supplies Openspec

The `nixos-scripts` derivation MUST wrap the Nixpkgs `openspec` binary onto `PATH` so `opencode-harness-init` can invoke it.

#### Scenario: openspec resolvable at runtime (Hosts: All NixOS and Darwin hosts)

- GIVEN `opencode-harness-init` installed via the `nixos-scripts` derivation
- WHEN `opencode-harness-init` triggers `openspec init`
- THEN the wrapped `openspec` binary is resolvable on `PATH`

### Requirement: Short Shell Alias

The shared zsh aliases MUST expose `ohi` as `opencode-harness-init` on all Home Manager hosts.

#### Scenario: Alias resolves to the long command (Hosts: All NixOS and Darwin hosts)

- GIVEN the shared shell aliases are activated
- WHEN the user runs `ohi`
- THEN zsh invokes `opencode-harness-init`
