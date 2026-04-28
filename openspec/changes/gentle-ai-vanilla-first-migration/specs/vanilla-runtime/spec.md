# Vanilla Runtime Specification

## Purpose

Define requirements for creating a parallel vanilla OpenCode runtime that contains no customizations, using only upstream defaults.

## Requirements

### Requirement: Parallel Vanilla Runtime

The system MUST create a separate vanilla runtime that operates independently from the current customized configuration.

#### Scenario: Vanilla runtime created

- GIVEN the vanilla mode command is executed
- WHEN the runtime is initialized
- THEN a separate configuration directory is created (e.g., `~/.config/opencode-vanilla/`)
- AND the vanilla runtime uses only upstream default assets
- AND the current customized configuration remains untouched

#### Scenario: Side-by-side operation

- GIVEN both vanilla and customized configurations exist
- WHEN either configuration is launched
- THEN each runtime operates independently
- AND changes to one do not affect the other

### Requirement: Exclusion of Customizations

The vanilla runtime MUST NOT include any customizations from the current configuration.

#### Scenario: Extra skills excluded

- GIVEN the vanilla runtime is initialized
- WHEN the runtime loads
- THEN no extraSkills are loaded
- AND only built-in skills are available

#### Scenario: Local persona rules excluded

- GIVEN the vanilla runtime is initialized
- WHEN the runtime loads
- THEN no localPersonaRules are loaded
- AND only default persona behavior is active

#### Scenario: Custom plugins excluded

- GIVEN the vanilla runtime is initialized
- WHEN the runtime loads
- THEN no custom plugins are loaded
- AND only upstream plugins are available

### Requirement: Upstream Assets Only

The vanilla runtime MUST use only upstream-provided assets and configurations.

#### Scenario: Default assets used

- GIVEN the vanilla runtime is running
- WHEN any asset is loaded (skills, themes, rules)
- THEN only assets from the upstream OpenCode distribution are used
- AND no local overrides are applied

### Requirement: Testable Alongside Current Config

The vanilla runtime MUST be testable without disrupting the current production configuration.

#### Scenario: Non-destructive testing

- GIVEN the vanilla runtime is initialized
- WHEN tests are run against the vanilla runtime
- THEN the current production configuration is not modified
- AND test results are isolated to the vanilla runtime
