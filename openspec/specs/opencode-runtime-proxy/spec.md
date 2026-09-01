# opencode-runtime-proxy Specification

## Purpose

Define the stable post-cleanup OpenCode runtime baseline: no legacy OpenAI proxy path and a non-OpenAI interim provider for `mact2`.

## Requirements

### Requirement: No Legacy OpenAI Proxy Gateway

The system MUST NOT configure or expose the legacy OpenAI proxy gateway. The `opencode-proxy.nix` gateway, `oai.glats.org` virtual host, `openai-proxy` provider family, `OPENAI_PROXY_API_KEY` wiring, and related sops declarations MUST be absent.

#### Scenario: Verify the legacy proxy family is absent [hosts: rog, mact2]

- GIVEN the cleanup configuration is present
- WHEN Nix-source references are searched across the repository
- THEN `openai-proxy`, `OPENAI_PROXY_API_KEY`, and `oai.glats.org` return zero matches outside `openspec/` history artifacts
- AND no active OpenCode tier selects a `-proxy` provider

### Requirement: mact2 Interim Provider

While native OpenAI is unreachable, `mact2` MUST select `opencode-go-medium` in both its host configuration and standalone Home Manager override.

#### Scenario: Generate the mact2 interim runtime configuration [hosts: mact2]

- GIVEN native OpenAI remains unreachable from `mact2`
- WHEN its OpenCode configuration is generated
- THEN the active tier is `opencode-go-medium`
- AND no `-proxy` tier is present

### Requirement: Secret Hygiene

The system MUST remove `secrets/host/rog/openai-proxy.yaml` from tracking, remove its `.sops.yaml` creation rule, and remove the Darwin secret declaration. No active configuration MAY reference the deleted secret.

#### Scenario: Validate deletion-safe secret configuration [hosts: rog, mact2]

- GIVEN the proxy secret has been removed
- WHEN the sops configuration and Darwin activation configuration are evaluated
- THEN the sops configuration parses without a rule for the deleted path
- AND Darwin activation has no missing-secret reference

### Requirement: No Functional Regression for Other Hosts

The cleanup MUST preserve non-proxy OpenCode behavior on `rog`, `t14`, `thinkcentre`, and `mact2`. `mact2` MUST continue to run OpenCode using its existing `opencode-go` authentication while its interim tier is active.

#### Scenario: Validate host evaluation and mact2 interim use [hosts: rog, t14, thinkcentre, mact2]

- GIVEN the post-cleanup configuration
- WHEN `nix flake check --no-build` runs and `mact2` runs OpenCode with `opencode-go` authentication
- THEN the flake check passes
- AND `mact2` completes its non-OpenAI OpenCode use without selecting a proxy provider
