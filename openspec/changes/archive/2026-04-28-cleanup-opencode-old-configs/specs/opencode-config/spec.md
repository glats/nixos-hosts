# Delta for OpenCode Config Module

## Purpose

Simplify the `home.opencode` module by removing the completed migration artifact (`legacyFallback`) and its associated warning system.

## MODIFIED Requirements

### Requirement: OpenCode Module Options

The `modules/home/opencode.nix` module MUST define the following options:

- `home.opencode.enable` — Enable the declarative OpenCode configuration
- `home.opencode.runtime` — Select runtime target: `"stable"`, `"lab"`, or `"both"`
- `home.opencode.agentOverrides` — Override agent settings per runtime
- `home.opencode.plugins` — Toggle individual plugin activation
- `home.opencode.tuiPlugins` — Toggle TUI plugin installation
- `home.opencode.mcps` — MCP server toggles (github, nixos, context7, engram, exa)
- `home.opencode.permissions` — Permission configuration
- `home.opencode.agents` — Agent definitions
(Previously: Included `legacyFallback` option and migration warning block)

#### Scenario: Module loads without legacyFallback option

- GIVEN `modules/home/opencode.nix` is evaluated
- WHEN accessing `config.home.opencode` options
- THEN `legacyFallback` is NOT a valid option
- AND no warning is emitted about migration state

#### Scenario: Runtime option description has no legacy references

- GIVEN the `runtime` option is inspected
- WHEN reading its description
- THEN it does NOT mention `legacyFallback` or migration steps
- AND it describes only the three valid modes: stable, lab, both

#### Scenario: Lab runtime remains functional

- GIVEN `home.opencode.enable = true` and `runtime = "lab"`
- WHEN home-manager is activated
- THEN `~/.config/opencode-lab/opencode.json` is generated
- AND all persona, skills, commands, and plugin files are symlinked

#### Scenario: Stable runtime remains functional

- GIVEN `home.opencode.enable = true` and `runtime = "stable"`
- WHEN home-manager is activated
- THEN `~/.config/opencode/opencode.json` is generated
- AND all persona, skills, commands, and plugin files are symlinked

### Requirement: OpenCode Profile Configuration

The `modules/home/opencode-profile.nix` profile MUST set only active options without migration-related settings.
(Previously: Included `legacyFallback = false` line)

#### Scenario: Profile has no legacyFallback setting

- GIVEN `modules/home/opencode-profile.nix` is read
- WHEN parsing its attribute set
- THEN `legacyFallback` is NOT present
- AND `enable`, `runtime`, `agentOverrides`, `plugins`, `tuiPlugins` are present
