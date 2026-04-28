# Cutover Specification

## Purpose

Define requirements for safely switching the production OpenCode configuration to vanilla mode while maintaining the ability to rollback.

## Requirements

### Requirement: Production Swap

The system MUST swap the production OpenCode configuration to use the vanilla runtime.

#### Scenario: Production swapped to vanilla

- GIVEN the vanilla runtime has passed all tests
- WHEN the cutover command is executed
- THEN the production configuration points to the vanilla runtime
- AND the vanilla configuration becomes the active configuration

#### Scenario: Atomic cutover

- GIVEN the cutover process is initiated
- WHEN the swap occurs
- THEN the transition is atomic (no intermediate broken state)
- AND the production runtime is immediately functional

### Requirement: Backup Availability

The system MUST keep the backup configuration available and accessible after cutover.

#### Scenario: Backup accessible post-cutover

- GIVEN the cutover is complete
- WHEN the backup directory is accessed
- THEN all backed up customization categories are present
- AND the restore script is executable and functional

#### Scenario: Rollback possible

- GIVEN the backup is accessible
- WHEN a rollback is initiated
- THEN the restore script can reconstruct the original configuration
- AND the production runtime returns to its pre-migration state

### Requirement: Post-Cutover Verification

The system MUST verify that production works correctly after the cutover.

#### Scenario: Production verification passes

- GIVEN the cutover is complete
- WHEN verification tests are run against production
- THEN all basic functionality tests pass
- AND no errors are reported

#### Scenario: Production verification fails

- GIVEN the cutover is complete
- WHEN verification tests are run against production
- AND a test fails
- THEN the failure is logged with details
- AND a rollback is recommended
