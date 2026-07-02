# opencode-provider-tiers Specification

## Purpose

Defines the model catalogue, SDD phase-to-model tier routing, and default provider selection for the `opencode-go` subscription. Ensures all tier assignments use only models served via the OpenAI-compatible transport (`/v1/chat/completions`), avoiding the broken Anthropic `/v1/messages` path (Qwen 3.7 family).

## Requirements

### Requirement: Model Catalogue Completeness

The `opencodeProvider.opencode.models` attribute set MUST declare exactly 11 models: 8 working OpenAI-compatible models and 3 zombie Qwen entries retained for upstream tracking.

Working models: `glm-5.2`, `glm-5.1`, `kimi-k2.6`, `kimi-k2.7-code`, `deepseek-v4-pro`, `deepseek-v4-flash`, `mimo-v2.5`, `mimo-v2.5-pro`.

Zombie models (with upstream tracking comment): `qwen3.7-plus`, `qwen3.7-max`, `qwen3.8-ultra`.

#### Scenario: All working models are declared

- GIVEN the `opencodeProvider.opencode.models` attribute set
- WHEN it is evaluated by `nix flake check`
- THEN it MUST contain exactly the 8 working model keys listed above
- AND each model key MUST have a `name` attribute with a human-readable display name

#### Scenario: Zombie models carry upstream tracking comment

- GIVEN the `opencodeProvider.opencode.models` attribute set
- WHEN a Nix developer reads the source
- THEN a comment block MUST appear above the 3 zombie entries citing upstream issues `opencode#23960`, `#32418`, `#29754`

### Requirement: Tier Phase Routing

Each tier MUST map all 12 SDD phases to exactly one model. No tier MAY assign a phase to a zombie Qwen model.

| Phase | opencode-go-full | opencode-go-medium | opencode-go-light |
|-------|-----------------|-------------------|------------------|
| gentle-orchestrator | deepseek-v4-pro | deepseek-v4-pro | deepseek-v4-flash |
| sdd-init | deepseek-v4-flash | deepseek-v4-flash | deepseek-v4-flash |
| sdd-explore | deepseek-v4-pro | deepseek-v4-pro | deepseek-v4-pro |
| sdd-propose | deepseek-v4-pro | deepseek-v4-pro | deepseek-v4-pro |
| sdd-spec | deepseek-v4-pro | deepseek-v4-pro | deepseek-v4-pro |
| sdd-design | glm-5.1 | glm-5.1 | deepseek-v4-pro |
| sdd-tasks | deepseek-v4-pro | deepseek-v4-flash | deepseek-v4-flash |
| sdd-apply | deepseek-v4-pro | deepseek-v4-flash | deepseek-v4-flash |
| sdd-verify | glm-5.1 | deepseek-v4-pro | deepseek-v4-pro |
| sdd-archive | deepseek-v4-flash | deepseek-v4-flash | deepseek-v4-flash |
| sdd-onboard | deepseek-v4-flash | deepseek-v4-flash | deepseek-v4-flash |
| neutral | deepseek-v4-pro | deepseek-v4-flash | deepseek-v4-flash |

#### Scenario: opencode-go-medium tier resolves all phases

- GIVEN `activeProviderName` is `"opencode-go-medium"`
- WHEN any SDD phase requests its model assignment
- THEN the resolved model MUST be one of: `glm-5.1`, `deepseek-v4-pro`, `deepseek-v4-flash`
- AND no phase MAY resolve to a zombie Qwen model

#### Scenario: opencode-go-full tier resolves all phases

- GIVEN `activeProviderName` is `"opencode-go-full"`
- WHEN any SDD phase requests its model assignment
- THEN the resolved model MUST be one of: `glm-5.1`, `deepseek-v4-pro`, `deepseek-v4-flash`
- AND no phase MAY resolve to a zombie Qwen model

#### Scenario: opencode-go-light tier resolves all phases

- GIVEN `activeProviderName` is `"opencode-go-light"`
- WHEN any SDD phase requests its model assignment
- THEN the resolved model MUST be one of: `deepseek-v4-pro`, `deepseek-v4-flash`
- AND no phase MAY resolve to a zombie Qwen model

### Requirement: Default Provider Selection

The system default `activeProviderName` MUST be `"opencode-go-medium"`. This default MUST be set consistently across all four declaration points.

#### Scenario: Default provider is opencode-go-medium

- GIVEN a host that does not override `activeProviderName`
- WHEN the OpenCode configuration is generated
- THEN the active provider MUST resolve to `"opencode-go-medium"`

#### Scenario: All declaration points agree

- GIVEN the four files `shared/opencode.nix`, `shared/opencode-profile.nix`, `shared/opencode/providers.nix`, `shared/opencode/providers-base.nix`
- WHEN their default `activeProviderName` values are inspected
- THEN all four MUST default to `"opencode-go-medium"`

### Requirement: Host Provider Mapping

Each host MUST have a valid `activeProviderName` assignment. Hosts MAY override the default via plain attribute assignment.

| Host | activeProviderName | Override Location |
|------|-------------------|-------------------|
| rog | opencode-go-medium | default (no override) |
| thinkcentre | opencode-go-medium | default (no override) |
| t14 | opencode-go-full | `hosts/t14/home/omarchy.nix` |
| mact2 | github-copilot | unchanged (darwin) |

#### Scenario: t14 uses opencode-go-full

- GIVEN the t14 host configuration
- WHEN `home.opencode.activeProviderName` is evaluated
- THEN the value MUST be `"opencode-go-full"`

#### Scenario: rog and thinkcentre use opencode-go-medium

- GIVEN the rog or thinkcentre host configuration
- WHEN `home.opencode.activeProviderName` is evaluated without explicit override
- THEN the value MUST resolve to `"opencode-go-medium"` via the default

### Requirement: Removed Tiers

The old tier names `opencode-go` and `opencode-go2` MUST NOT exist in the `providers` list. They are replaced by `opencode-go-full`, `opencode-go-medium`, and `opencode-go-light`.

#### Scenario: Old tier names are absent

- GIVEN the `providers` list in `providers-base.nix`
- WHEN it is scanned for tier names
- THEN `"opencode-go"` and `"opencode-go2"` MUST NOT appear
- AND `"opencode-go-full"`, `"opencode-go-medium"`, `"opencode-go-light"` MUST appear
