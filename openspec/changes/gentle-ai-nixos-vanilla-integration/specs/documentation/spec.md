# Documentation Specification

## Purpose

Document the backup contents, update procedure, and rollback process for the vanilla integration change.

## Requirements

### Requirement: Backup Documentation

The system MUST document what was backed up, where, and how to verify it.

#### Scenario: Backup inventory documented

- GIVEN a completed backup
- WHEN documentation is generated
- THEN a list of all 14 backed-up categories is included
- AND the backup directory path and timestamp are recorded

#### Scenario: Verification instructions included

- GIVEN backup documentation
- WHEN a user reads it
- THEN instructions for running integrity verification are clear
- AND the MANIFEST.md location is specified

### Requirement: Update Procedure Documentation

The system MUST document the step-by-step update procedure for future reference.

#### Scenario: Procedure steps documented

- GIVEN the change is complete
- WHEN procedure documentation is written
- THEN each phase (0-4) is described in order
- AND commands for each step are included

#### Scenario: Prerequisites documented

- GIVEN procedure documentation
- WHEN a user reads it
- THEN prerequisites (clean git tree, nix available) are listed
- AND estimated time for each phase is noted

### Requirement: Rollback Procedure Documentation

The system MUST document how to rollback to the pre-migration state.

#### Scenario: Rollback steps documented

- GIVEN the change is complete
- WHEN rollback documentation is written
- THEN steps to restore from backup are included
- AND the `restore.sh` script usage is documented

#### Scenario: Git rollback documented

- GIVEN rollback documentation
- WHEN a user reads it
- THEN instructions to `git reset --hard pre-vanilla-migration` are included
- AND warnings about uncommitted work are noted
