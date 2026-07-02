# nix-cli-ux Specification

## Purpose

Specifies the addition of the `nix-output-monitor` package to the system CLI tools for enhanced build progress visualization.

## Requirements

### Requirement: REQ-nix-cli-ux-01

The system SHALL include `nix-output-monitor` in the list of CLI tools to be installed.

#### Scenario: Happy path

- GIVEN the system is configured with the base packages module
- WHEN the system is built and installed
- THEN the `nix-output-monitor` package is present in the system profile
- AND the `nom` command is available in the PATH

# system-editor-defaults Specification

## Purpose

Specifies the system-wide setting of the EDITOR and VISUAL environment variables to `nvim` for consistent editor usage across system services.

## Requirements

### Requirement: REQ-system-editor-defaults-01

The system SHALL set the environment variables EDITOR and VISUAL to `nvim` for all users and system services.

#### Scenario: Happy path

- GIVEN the system is configured with the base users module
- WHEN the system is built and a new login session is started (or a service runs)
- THEN the EDITOR environment variable is set to `nvim`
- AND the VISUAL environment variable is set to `nvim`

# nix-store-optimisation Specification

## Purpose

Specifies the enabling of the Nix store auto-optimisation feature to save disk space by hard-linking identical store paths.

## Requirements

### Requirement: REQ-nix-store-optimisation-01

The system SHALL enable the Nix setting `auto-optimise-store` to automatically hard-link identical store paths.

#### Scenario: Happy path

- GIVEN the system is configured with the base Nix module
- WHEN the system is built and the Nix daemon is running
- THEN the Nix configuration has `auto-optimise-store = true`
- AND subsequent Nix operations that install identical store paths will use hard links to save space