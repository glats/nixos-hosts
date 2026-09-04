# opencode-runtime-proxy Specification

## Purpose

Define runtime-only OpenAI-compatible proxy behavior between `mact2` and `rog` after bootstrap completes.

## Requirements

### Requirement: mact2 Custom Runtime Provider

`mact2` MUST use a new custom OpenCode provider identity named `openai-proxy` for this flow and MUST target `https://oai.glats.org/v1` for runtime traffic. The system MUST NOT require successful native macOS OpenAI browser OAuth for this runtime path, and MUST keep the built-in `openai` provider and its tiers (`openai-full`, `openai-medium`, `openai-light`) intact for other hosts.

#### Scenario: Configure mact2 to use the rog runtime endpoint [hosts: mact2]

- GIVEN the change is enabled for `mact2`
- WHEN OpenCode runtime configuration is generated
- THEN the active runtime path uses the custom provider identity and `https://oai.glats.org/v1`
- AND it does not depend on the built-in OpenAI OAuth provider identity

### Requirement: rog Runtime Gateway Boundary

`rog` MUST expose only OpenAI-compatible `/v1` runtime traffic at `oai.glats.org`. The system MUST keep upstream provider credentials server-side on `rog`, and `mact2` SHALL receive only scoped client access needed to call the gateway. Non-runtime admin or UI routes SHOULD NOT be publicly reachable through this endpoint.

#### Scenario: Proxy runtime traffic through rog [hosts: rog, mact2]

- GIVEN `mact2` sends a runtime request to `https://oai.glats.org/v1`
- WHEN `rog` receives the request
- THEN `rog` forwards only the runtime API traffic to its internal gateway
- AND the upstream credential remains on `rog`

#### Scenario: Deny non-runtime or administrative paths [hosts: rog]

- GIVEN a request targets a non-`/v1` path on `oai.glats.org`
- WHEN `rog` evaluates the request
- THEN the request is denied or not routed to the internal gateway
- AND no admin capability is exposed to the public endpoint

### Requirement: Scoped Rollback

Rollback MUST be limited to `mact2` and `rog` for this delta. Disabling the change MUST allow removal of the custom runtime path, revocation of scoped client access, and withdrawal of the bootstrap artifact without changing other hosts.

#### Scenario: Roll back the mact2-to-rog path [hosts: rog, mact2]

- GIVEN the operator decides to disable this change
- WHEN rollback is executed
- THEN `mact2` no longer targets the custom runtime endpoint and the scoped client access is revoked
- AND no other host is required to change behavior
