# opencode-native-oauth-egress Specification

## Purpose

Define native ChatGPT OAuth egress for OpenCode on `mact2` without restoring an API-key gateway or changing MCP routing.

## Requirements

### Requirement: Native OpenCode Authentication and Provider Selection

`mact2` MUST use OpenCode's built-in OpenAI/ChatGPT OAuth authentication and the native `openai-medium` selection. It MUST NOT use an OpenAI Platform API key, an OpenAI-compatible custom provider, a custom `baseURL`, or a gateway credential.

#### Scenario: Use native OAuth successfully [hosts: mact2]

- GIVEN valid native ChatGPT OAuth state is available
- WHEN OpenCode makes a supported OpenAI request
- THEN the request succeeds using native OAuth
- AND `openai-medium` is the selected provider tier

#### Scenario: Reject API-key or custom-provider configuration [hosts: mact2]

- GIVEN generated OpenCode configuration is inspected
- WHEN authentication and provider settings are evaluated
- THEN no Platform API key, custom provider, or custom OpenAI-compatible endpoint is present

### Requirement: Gateway Architecture Retirement

The final implementation MUST retire the old OpenAIP provider and tier family, gateway service, gateway secret wiring, and public `oai.glats.org` endpoint. It MUST NOT replace them with another public API gateway.

#### Scenario: Remove retired runtime surface [hosts: mact2, rog]

- GIVEN the final configuration is built
- WHEN retired OpenAI gateway references and exposed routes are checked
- THEN the old provider, service, secret wiring, and public endpoint are absent

#### Scenario: Prevent gateway regression [hosts: mact2, rog]

- GIVEN a change attempts to restore an OpenAIP path or public endpoint
- WHEN configuration validation runs
- THEN validation fails or the change is rejected
- AND native OAuth remains the only supported OpenAI path

### Requirement: Evidence-Gated Egress Selection

The system MUST complete and retain sanitized preflight evidence before selecting routing. If native direct egress succeeds, it MUST be selected. `rog` egress MAY be selected only after direct egress fails and evidence demonstrates `mact2`→`rog` reachability, `rog`→OpenAI reachability, and MCP isolation. If those conditions are not demonstrated, no routing change MUST be applied.

#### Scenario: Prefer verified direct egress [hosts: mact2]

- GIVEN a native OAuth request succeeds through direct egress
- WHEN preflight selection is evaluated
- THEN direct egress is selected
- AND no `rog` routing dependency is configured

#### Scenario: Block unproven `rog` routing [hosts: mact2, rog]

- GIVEN direct egress fails and any required reachability or isolation proof is missing
- WHEN preflight selection is evaluated
- THEN `rog` egress is not selected
- AND no routing change is applied

### Requirement: MCP Isolation and Auth-Seed Safety

The system MUST NOT set shell-wide `HTTP_PROXY` or `HTTPS_PROXY`. OpenCode MCP child processes MUST retain default, unproxied routing and remain functional. If an auth seed is retained, it MUST contain only native OAuth auth data, back up existing auth before modification, and MUST NOT have API-key semantics.

#### Scenario: Preserve MCP default routing [hosts: mact2]

- GIVEN OpenCode launches a representative local MCP child process
- WHEN its environment, connections, and operation are observed
- THEN it has no inherited proxy routing and completes normally

#### Scenario: Fail closed for unsafe auth seed [hosts: mact2]

- GIVEN a seed is invalid, contains API-key-like data, or cannot be safely merged
- WHEN seed installation is attempted
- THEN installation fails without changing existing auth
- AND the prior auth state remains backed up and usable
