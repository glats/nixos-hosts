# P0 Restoration Specification

## Purpose

Define requirements for restoring critical (P0) customizations to the vanilla production environment after cutover.

## Requirements

### Requirement: Engram Plugin Restoration

The system MUST restore the Engram plugin as the first P0 item after cutover.

#### Scenario: Engram plugin restored

- GIVEN the production is running on vanilla
- WHEN the Engram plugin restoration is executed
- THEN the Engram plugin is installed and configured
- AND memory operations (save, search, retrieve) function correctly

#### Scenario: Engram plugin tested

- GIVEN the Engram plugin is restored
- WHEN a memory save operation is performed
- THEN the observation is stored successfully
- AND subsequent search operations return the saved observation

### Requirement: Sops-Nix Secrets Restoration

The system MUST restore sops-nix secrets integration after cutover.

#### Scenario: Secrets restored

- GIVEN the production is running on vanilla
- WHEN the sops-nix secrets restoration is executed
- THEN encrypted secrets are accessible to OpenCode
- AND secret decryption works without errors

#### Scenario: Secrets tested

- GIVEN the sops-nix secrets are restored
- WHEN a secret is accessed by OpenCode
- THEN the secret value is returned correctly
- AND no plaintext secrets are exposed

### Requirement: Permission Rules Restoration

The system MUST restore permission rules that govern access and behavior.

#### Scenario: Permission rules restored

- GIVEN the production is running on vanilla
- WHEN permission rules are restored
- THEN all permission rules are active
- AND rules are enforced during OpenCode operations

#### Scenario: Permission rules tested

- GIVEN permission rules are restored
- WHEN an operation that requires specific permissions is attempted
- THEN the operation is allowed or denied according to the rules
- AND violations are logged

### Requirement: Model Assignments Restoration

The system MUST restore model assignments that map tasks to specific models.

#### Scenario: Model assignments restored

- GIVEN the production is running on vanilla
- WHEN model assignments are restored
- THEN all model mappings are active
- AND tasks are routed to the correct models

#### Scenario: Model assignments tested

- GIVEN model assignments are restored
- WHEN a task requiring a specific model is executed
- THEN the task is handled by the assigned model
- AND the model responds correctly

### Requirement: MCP Servers Restoration

The system MUST restore MCP server configurations after cutover.

#### Scenario: MCP servers restored

- GIVEN the production is running on vanilla
- WHEN MCP server configurations are restored
- THEN all MCP servers are connected and operational
- AND server health checks pass

#### Scenario: MCP servers tested

- GIVEN MCP servers are restored
- WHEN an MCP tool is invoked
- THEN the tool executes successfully
- AND the response is returned to OpenCode

### Requirement: Individual Restoration Testing

The system MUST test each P0 restoration item independently before proceeding to the next.

#### Scenario: Sequential restoration with testing

- GIVEN a P0 item is restored
- WHEN the item's tests are executed
- THEN all tests must pass before the next P0 item is restored
- AND any failure halts the restoration process
