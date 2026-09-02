# opencode-runtime-proxy Specification

## Purpose

Define the stable OpenCode runtime baseline: no legacy OpenAI proxy gateway and no public replacement gateway, with `mact2` reaching native OpenAI through the sing-box private link. The gateway family is retired; the private-link path is production-validated in-building as of 2026-09-01.

## Requirements

### Requirement: No Legacy OpenAI Proxy Gateway

The system MUST NOT configure or expose the legacy OpenAI proxy gateway. The `opencode-proxy.nix` gateway, `oai.glats.org` virtual host, `openai-proxy` provider family, `OPENAI_PROXY_API_KEY` wiring, and related sops declarations MUST be absent.

#### Scenario: Verify the legacy proxy family is absent [hosts: rog, mact2]

- GIVEN the cleanup configuration is present
- WHEN Nix-source references are searched across the repository
- THEN `openai-proxy`, `OPENAI_PROXY_API_KEY`, and `oai.glats.org` return zero matches outside `openspec/` history artifacts
- AND no active OpenCode tier selects a `-proxy` provider

### Requirement: mact2 Runtime Provider Transition

`mact2` MUST leave `openai-medium-proxy` for native `openai-medium` after the home transport is healthy; native PONG, refresh, and MCP-clean checks MUST then prove that transition. The configured runtime proxy is currently broken because its gateway forwards an invalid `nvapi-` credential to `api.openai.com`; the native path MUST NOT depend on that gateway. Built-in native tiers MUST remain intact for other hosts.
(Previously: `mact2` was required to use `openai-proxy` at `https://oai.glats.org/v1`; the `remove-opencode-proxy-legacy` baseline briefly placed `mact2` on the non-OpenAI `opencode-go-medium` interim tier while native OpenAI was unreachable.)

#### Scenario: Switch after home proof [hosts: mact2]

- GIVEN home transport validation has passed
- WHEN mact2 OpenCode configuration is generated
- THEN `openai-medium` is active and no proxy provider is selected
- AND `opencode run -m openai/gpt-5.4 "PONG"` succeeds

#### Scenario: Block premature switch [hosts: mact2]

- GIVEN home transport validation is absent
- WHEN provider selection is evaluated
- THEN `openai-medium-proxy` remains configured

### Requirement: Gated Gateway Availability and Retirement

The legacy gateway family — `oai.glats.org`, its `/v1` boundary, the gateway service, proxy tiers, and associated secret wiring — is RETIRED and MUST remain absent, with no replacement public API gateway. Historically the family was retained until every home proof and every OFFICE GATE passed; the retirement landed first (via `remove-opencode-proxy-legacy`), and office production proof of the native private-link path was validated in-building 2026-09-01. The tracked host defaults show only `mact2` selects a proxy tier; the transition MUST avoid mid-flight breakage for any existing consumer.

#### Scenario: Retain gateway before gates [hosts: rog, mact2]

- GIVEN an office gate is unproven
- WHEN tunnel and native-auth changes are delivered
- THEN the retained gateway history shows the family stayed operational until retirement
- AND the mact2 transition does not remove shared gateway dependencies

#### Scenario: Retire only after all gates [hosts: rog, mact2]

- GIVEN the gateway family is retired and the native private-link path is production-validated
- WHEN the retirement tree is inspected and `format-nix && nix flake check --no-build` runs
- THEN the gateway service, endpoint, tiers, exports, and secrets are absent
- AND no replacement public gateway is configured

### Requirement: Secret Hygiene

The system MUST remove `secrets/host/rog/openai-proxy.yaml` from tracking, remove its `.sops.yaml` creation rule, and remove the Darwin secret declaration. No active configuration MAY reference the deleted secret.

#### Scenario: Validate deletion-safe secret configuration [hosts: rog, mact2]

- GIVEN the proxy secret has been removed
- WHEN the sops configuration and Darwin activation configuration are evaluated
- THEN the sops configuration parses without a rule for the deleted path
- AND Darwin activation has no missing-secret reference

### Requirement: Scoped Rollback

Rollback MUST remain limited to `mact2` and `rog`. Before retirement, reverting tunnel and native-tier configuration MUST restore `mact2` to the retained proxy path. After retirement, reverting the retirement change MUST restore the gateway configuration and re-encrypted secret without placing credentials in the store.
(Previously: rollback removed the custom runtime path and revoked its scoped access.)

#### Scenario: Revert before retirement [hosts: rog, mact2]

- GIVEN Phase 1 or Phase 2 has been deployed and Phase 3 has not
- WHEN the declarative tunnel/native changes are reverted
- THEN mact2 returns to the retained proxy tier
- AND gateway availability is restored without changing other hosts

#### Scenario: Revert after retirement [hosts: rog, mact2]

- GIVEN Phase 3 has retired the gateway
- WHEN its declarative change and encrypted secret are restored
- THEN the prior gateway path is available again
- AND no plaintext credential is introduced into the Nix store

### Requirement: No Functional Regression for Other Hosts

The transition MUST preserve non-proxy OpenCode behavior on `rog`, `t14`, `thinkcentre`, and `mact2`. `mact2` MUST run OpenCode using its native OpenAI authentication via the sing-box private link while its native tier is active.

#### Scenario: Validate host evaluation and mact2 native use [hosts: rog, t14, thinkcentre, mact2]

- GIVEN the post-cleanup configuration
- WHEN `nix flake check --no-build` runs and `mact2` runs OpenCode with native OpenAI authentication
- THEN the flake check passes
- AND `mact2` completes its OpenCode use through the private link without selecting a proxy provider
