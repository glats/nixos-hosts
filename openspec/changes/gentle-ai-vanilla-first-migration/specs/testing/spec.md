# Testing Specification

## Purpose

Define requirements for validating vanilla OpenCode functionality before and during the migration process.

## Requirements

### Requirement: Basic Functionality Testing

The system MUST test all basic OpenCode features in vanilla mode to confirm upstream functionality.

#### Scenario: Core features work

- GIVEN the vanilla runtime is running
- WHEN basic operations are performed (chat, file editing, terminal commands)
- THEN all operations complete successfully
- AND no errors related to missing customizations occur

#### Scenario: Model interaction works

- GIVEN the vanilla runtime is running
- WHEN a model is selected and a conversation is started
- THEN the model responds correctly
- AND conversation history is maintained

### Requirement: SDD Workflow Testing

The system MUST test the complete SDD workflow (explore → propose → spec → design → tasks → apply → verify) in vanilla mode.

#### Scenario: Explore phase works

- GIVEN the vanilla runtime is running
- WHEN the explore command is executed with a feature request
- THEN the explore agent runs successfully
- AND produces an exploration artifact

#### Scenario: Propose phase works

- GIVEN an exploration artifact exists
- WHEN the propose command is executed
- THEN a change proposal is created
- AND the proposal follows the expected format

#### Scenario: Full SDD cycle completes

- GIVEN the vanilla runtime is running
- WHEN a complete SDD cycle is executed (explore → propose)
- THEN all phases complete without errors
- AND artifacts are created in the expected locations

### Requirement: Vanilla Feature Verification

The system MUST verify all vanilla features work as expected without customizations.

#### Scenario: Built-in skills work

- GIVEN the vanilla runtime is running
- WHEN built-in skills are invoked
- THEN each skill executes correctly
- AND skill outputs match expected behavior

#### Scenario: MCP servers work

- GIVEN the vanilla runtime is running with default MCP configuration
- WHEN MCP tools are invoked
- THEN MCP servers respond correctly
- AND tool outputs are returned as expected

### Requirement: Gap Documentation

The system MUST document any functionality gaps discovered during vanilla testing.

#### Scenario: Gap identified

- GIVEN a vanilla feature is being tested
- WHEN the feature does not work as expected
- THEN the gap is documented with description, impact, and severity
- AND the gap is categorized (P0, P1, P2, P3)

#### Scenario: No gaps found

- GIVEN all vanilla features are tested
- WHEN no gaps are discovered
- THEN a report confirming full vanilla functionality is generated
