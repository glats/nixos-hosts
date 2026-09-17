# Portable Nix Formatting Specification

## Purpose

Define portable project selection and Nix formatting behavior for `format-nix` on all supported NixOS and Darwin hosts.

## Requirements

### Requirement: Explicit Project Directory Selection

`format-nix` MUST accept one optional positional directory. When provided, that directory MUST take precedence over caller-context discovery, MUST be an existing directory containing `flake.nix`, and MUST be the formatting project root. The command MUST NOT use environment variables as an implicit project root.

#### Scenario: Explicit directory selects its project (Hosts: All NixOS and Darwin hosts)

- GIVEN an existing directory containing `flake.nix`
- WHEN the user runs `format-nix <directory>`
- THEN the command selects that directory as the project root
- AND it does not select a flake containing the caller's working directory

#### Scenario: Invalid explicit directory is rejected (Hosts: All NixOS and Darwin hosts)

- GIVEN a supplied path that is missing, not a directory, or lacks `flake.nix`
- WHEN the user runs `format-nix <directory>`
- THEN the command reports a clear error and exits non-zero
- AND it does not format any files

### Requirement: Caller-Context Project Discovery

When no directory is supplied, `format-nix` MUST search upward from the caller's current working directory and select the nearest ancestor containing `flake.nix` as the project root.

#### Scenario: Nested directory resolves the containing flake (Hosts: All NixOS and Darwin hosts)

- GIVEN the caller is in a nested directory of a flake project
- WHEN the user runs `format-nix` without a directory
- THEN the command selects the nearest containing flake root
- AND formats only files under that root

#### Scenario: No containing flake is found (Hosts: All NixOS and Darwin hosts)

- GIVEN the caller's directory and all of its ancestors lack `flake.nix`
- WHEN the user runs `format-nix` without a directory
- THEN the command reports a clear error and exits non-zero
- AND it does not format any files

### Requirement: Eligible Nix File Formatting

For the selected project, `format-nix` MUST recursively process every eligible `.nix` file with that project's flake formatter. It MUST NOT traverse `.git` or `.worktrees`, and MUST NOT process transient `.format-nix-*` files. Formatter failures MUST produce a non-zero exit status after applicable files have been attempted.

#### Scenario: All eligible Nix files are processed (Hosts: All NixOS and Darwin hosts)

- GIVEN a selected project with `.nix` files at multiple directory depths
- WHEN the user runs `format-nix`
- THEN every eligible `.nix` file under the project is formatted
- AND files in excluded paths or with transient names are not processed

### Requirement: Check-Only Formatting

With `--check`, `format-nix` MUST evaluate the same eligible file set without modifying project files. It MUST exit successfully when every file is already formatted and non-zero when a file would change or its formatter check fails.

#### Scenario: Check mode detects required formatting (Hosts: All NixOS and Darwin hosts)

- GIVEN an eligible Nix file that the formatter would change
- WHEN the user runs `format-nix [directory] --check`
- THEN the command reports that file as requiring formatting and exits non-zero
- AND the original project file remains unchanged

#### Scenario: Check mode accepts formatted files (Hosts: All NixOS and Darwin hosts)

- GIVEN every eligible Nix file is already formatted
- WHEN the user runs `format-nix --check`
- THEN the command exits successfully
- AND no project file is modified
