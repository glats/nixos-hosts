# Delta for opencode-runtime-proxy

## MODIFIED Requirements

### Requirement: mact2 Runtime Provider Transition

`mact2` MUST leave `openai-medium-proxy` for native `openai-medium` after the home transport is healthy; native PONG, refresh, and MCP-clean checks MUST then prove that transition. The configured runtime proxy is currently broken because its gateway forwards an invalid `nvapi-` credential to `api.openai.com`; the native path MUST NOT depend on that gateway. Built-in native tiers MUST remain intact for other hosts.  
(Previously: `mact2` was required to use `openai-proxy` at `https://oai.glats.org/v1`.)

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

`rog` MUST keep `oai.glats.org`, its `/v1` boundary, gateway service, proxy tiers, and associated secret wiring operational until every home proof and every OFFICE GATE passes. Retirement MUST then remove that complete gateway family without replacing it with a public API gateway. The tracked host defaults show only `mact2` selects a proxy tier; this retention MUST nevertheless avoid mid-flight breakage for any existing consumer.
(Previously: `rog` had to expose `/v1` runtime traffic as the active mact2 path.)

#### Scenario: Retain gateway before gates [hosts: rog, mact2]

- GIVEN an office gate is unproven
- WHEN tunnel and native-auth changes are delivered
- THEN `oai.glats.org` and the proxy service remain operational
- AND the mact2 transition does not remove shared gateway dependencies

#### Scenario: Retire only after all gates [hosts: rog, mact2]

- GIVEN all home and OFFICE GATE evidence is recorded
- WHEN Phase 3 removal is applied and `format-nix && nix flake check --no-build` runs
- THEN the gateway service, endpoint, tiers, exports, and secrets are absent
- AND no replacement public gateway is configured

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
