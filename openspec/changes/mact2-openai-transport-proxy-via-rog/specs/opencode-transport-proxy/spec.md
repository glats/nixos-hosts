# OpenCode Transport Proxy Specification

## Purpose

Provide private `mact2` OpenCode HTTPS egress through `rog` with native OpenAI integration.

## Requirements

### Requirement: Retire the application gateway family

The system MUST remove the Python gateway, `oai.glats.org` `/v1`, all `openai-proxy` tiers and selectors, and gateway-key configuration. It MUST NOT retain an `sk-` key or `OPENAI_PROXY_API_KEY`.

#### Scenario: [rog] Gateway artifacts are absent

- GIVEN the corrected configuration is deployed
- WHEN `rog` configuration and published web routes are inspected
- THEN no application gateway or public `/v1` gateway route is available

#### Scenario: [mact2] Custom provider is unavailable

- GIVEN OpenCode configuration is generated on `mact2`
- WHEN provider tiers and environment are inspected
- THEN no `openai-*-proxy` tier or gateway API-key export exists

### Requirement: Provide private transport egress

The system MUST provide a `rog` forward proxy reachable only from `mact2` through WireGuard. It MUST accept HTTPS CONNECT and MUST NOT expose a public or unapproved-peer listener.

#### Scenario: [rog,mact2] Authorized HTTPS egress succeeds

- GIVEN the WireGuard tunnel and proxy are active
- WHEN OpenCode on `mact2` makes an HTTPS OpenAI or Codex request
- THEN the request can egress through `rog`

#### Scenario: [rog] Unauthorized access is rejected

- GIVEN a source outside the approved WireGuard peer
- WHEN it attempts to connect to the proxy
- THEN the proxy MUST reject the connection

### Requirement: Retain native OpenAI behavior on mact2

`mact2` MUST use built-in `openai` and native `openai-medium`. Its OpenCode-only environment MUST route HTTP(S) through the private proxy with local bypasses; it MUST NOT configure a global macOS proxy.

#### Scenario: [mact2] Native tier uses proxy transport

- GIVEN the `mact2` OpenCode shell is initialized
- WHEN OpenCode starts a native OpenAI request
- THEN it selects `openai-medium` and uses the private proxy environment

#### Scenario: [mact2] macOS networking remains unchanged

- GIVEN an unrelated macOS application runs
- WHEN it makes a network request
- THEN this capability MUST NOT impose the OpenCode proxy on it
