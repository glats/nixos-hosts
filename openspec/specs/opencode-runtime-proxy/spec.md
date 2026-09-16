# opencode-runtime-proxy Specification

## Purpose

Define the stable OpenCode runtime baseline: no legacy OpenAI proxy gateway and no public replacement gateway, with `macm5` reaching native OpenAI through the sing-box private link. The gateway family is retired; the private-link path is production-validated in-building as of 2026-09-01.

## Requirements

### Requirement: No Legacy OpenAI Proxy Gateway

The system MUST NOT configure or expose the legacy OpenAI proxy gateway. The `opencode-proxy.nix` gateway, `oai.glats.org` virtual host, `openai-proxy` provider family, `OPENAI_PROXY_API_KEY` wiring, and related sops declarations MUST be absent.

#### Scenario: Verify the legacy proxy family is absent [hosts: rog, macm5]

- GIVEN the cleanup configuration is present
- WHEN Nix-source references are searched across the repository
- THEN `openai-proxy`, `OPENAI_PROXY_API_KEY`, and `oai.glats.org` return zero matches outside `openspec/` history artifacts
- AND no active OpenCode tier selects a `-proxy` provider

### Requirement: macm5 Native Runtime

`macm5` MUST use the native `openai-medium` tier after the home transport is healthy; native PONG, refresh, and MCP-clean checks MUST prove that behavior. The native path MUST NOT depend on the retired gateway. Built-in native tiers MUST remain intact for other hosts.

#### Scenario: Use native runtime after home proof [hosts: macm5]

- GIVEN home transport validation has passed
- WHEN macm5 OpenCode configuration is generated
- THEN `openai-medium` is active and no proxy provider is selected
- AND `opencode run -m openai/gpt-5.4 "PONG"` succeeds

#### Scenario: Keep native runtime gated on transport [hosts: macm5]

- GIVEN home transport validation is absent
- WHEN provider selection is evaluated
- THEN native OpenAI use is not treated as proven

### Requirement: Gated Gateway Availability and Retirement

The legacy gateway family — `oai.glats.org`, its `/v1` boundary, the gateway service, proxy tiers, and associated secret wiring — is RETIRED and MUST remain absent, with no replacement public API gateway. Historically the family was retained until every home proof and every OFFICE GATE passed; the retirement landed first (via `remove-opencode-proxy-legacy`), and office production proof of the native private-link path was validated in-building 2026-09-01. The tracked host defaults show `macm5` on the native tier; the transition MUST avoid mid-flight breakage for any existing consumer.

#### Scenario: Retain gateway before gates [hosts: rog, macm5]

- GIVEN an office gate is unproven
- WHEN tunnel and native-auth changes are delivered
- THEN the retained gateway history shows the family stayed operational until retirement
- AND the macm5 transition does not remove shared gateway dependencies

#### Scenario: Retire only after all gates [hosts: rog, macm5]

- GIVEN the gateway family is retired and the native private-link path is production-validated
- WHEN the retirement tree is inspected and `format-nix && nix flake check --no-build` runs
- THEN the gateway service, endpoint, tiers, exports, and secrets are absent
- AND no replacement public gateway is configured

### Requirement: Secret Hygiene

The system MUST remove `secrets/host/rog/openai-proxy.yaml` from tracking, remove its `.sops.yaml` creation rule, and remove the Darwin secret declaration. No active configuration MAY reference the deleted secret.

#### Scenario: Validate deletion-safe secret configuration [hosts: rog, macm5]

- GIVEN the proxy secret has been removed
- WHEN the sops configuration and Darwin activation configuration are evaluated
- THEN the sops configuration parses without a rule for the deleted path
- AND Darwin activation has no missing-secret reference

### Requirement: Scoped Rollback

Rollback MUST remain limited to `macm5` and `rog`. Recovery after retirement MUST use macm5 Git, generation, and identity state without placing credentials in the store or reactivating the retired Darwin host.
(Previously: rollback removed the custom runtime path and revoked its scoped access.)

#### Scenario: Revert before retirement [hosts: rog, macm5]

- GIVEN Phase 1 or Phase 2 has been deployed and Phase 3 has not
- WHEN the declarative tunnel/native changes are reverted
- THEN macm5 returns to the pre-retirement declarative state
- AND gateway availability is restored without changing other hosts

#### Scenario: Recover after retirement [hosts: rog, macm5]

- GIVEN the Darwin retirement is complete
- WHEN the reviewed macm5 Git state and known-good generation are restored
- THEN macm5 recovery remains available
- AND no plaintext credential is introduced into the Nix store

### Requirement: No Functional Regression for Other Hosts

The transition MUST preserve non-proxy OpenCode behavior on `rog`, `t14`, `thinkcentre`, and `macm5`. `macm5` MUST run OpenCode using its native OpenAI authentication via the sing-box private link while its native tier is active.

#### Scenario: Validate host evaluation and macm5 native use [hosts: rog, t14, thinkcentre, macm5]

- GIVEN the post-cleanup configuration
- WHEN `nix flake check --no-build` runs and `macm5` runs OpenCode with native OpenAI authentication
- THEN the flake check passes
- AND `macm5` completes its OpenCode use through the private link without selecting a proxy provider
