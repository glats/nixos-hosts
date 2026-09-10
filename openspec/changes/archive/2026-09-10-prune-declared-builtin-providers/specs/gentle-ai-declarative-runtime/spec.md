# Delta for Gentle AI Declarative Runtime

## ADDED Requirements

### Requirement: Minimal Declarative Provider Catalog

The declarative provider catalog MUST contain only NVIDIA's custom OpenAI-compatible declaration and OpenCode's timeout overrides. It MUST NOT declare model pins for `anthropic`, `github-copilot`, `openai`, or `opencode`, and MUST NOT emit the unsupported `thinking` key; NVIDIA's existing declaration MUST remain unchanged.

#### Scenario: Generated catalog excludes built-in model pins [hosts: rog, thinkcentre, t14, mact2]
- GIVEN the shared OpenCode configuration is evaluated
- WHEN its provider catalog is inspected
- THEN only `nvidia` and option-only `opencode` provider entries are present
- AND no Anthropic, GitHub Copilot, OpenAI, or OpenCode model pin is declared
- AND no provider model contains `thinking`

### Requirement: Routing Profiles Remain Independent

Every routing profile present in the baseline `providers` list MUST remain byte-identical, as verified by a full-JSON-equality A/B evaluation of the pruned file against the baseline revision. Every built-in phase model identifier MUST resolve with zero missing model IDs against the live models.dev catalog at verification time; NVIDIA identifiers MUST remain resolved by the explicit custom declaration.

#### Scenario: Pruned and baseline routing are equivalent [hosts: rog, thinkcentre, t14, mact2]
- GIVEN baseline and pruned provider evaluations plus the current models.dev catalog
- WHEN all profiles, phase mappings, and unique built-in model identifiers are compared
- THEN every routing profile present in the baseline `providers` list is byte-identical in the pruned evaluation
- AND all built-in identifiers resolve with zero missing model IDs against the live models.dev catalog while NVIDIA remains declared

### Requirement: OpenCode Streaming Overrides Persist

Generated `opencode.json` MUST retain `provider.opencode.options.timeout = 3600000` and `chunkTimeout = 3600000` without declaring OpenCode models.

#### Scenario: Free routing retains one-hour limits [hosts: t14, mact2]
- GIVEN a host configuration containing the `opencode-free` routing profile
- WHEN its generated `opencode.json` is inspected
- THEN both OpenCode timeout options equal 3,600,000 milliseconds
- AND no five-minute default or configured OpenCode model list replaces them

### Requirement: Unreachable Provider Extension Is Absent

The runtime configuration MUST NOT contain `providers-extra.nix`, thread `extraProviders`, or retain any repository consumer of `extraProviders`.

#### Scenario: Dead extension path is grep-clean [hosts: rog, thinkcentre, t14, mact2]
- GIVEN the provider cleanup is complete
- WHEN tracked files and references are searched
- THEN `providers-extra.nix` is absent
- AND `extraProviders` has zero repository references

### Requirement: Provider Credential Exports Remain Stable

Existing sops-backed provider environment exports in `shared/opencode.nix`, including Groq and Cerebras credentials, MUST remain unchanged because they support catalog-resolved providers independently of static provider blocks.

#### Scenario: Built-in credentials survive pruning [hosts: rog, thinkcentre, t14, mact2]
- GIVEN the pre-change and pruned shared OpenCode environment definitions
- WHEN their sops-backed provider exports are compared
- THEN every existing export is byte-identical
- AND no credential or secret declaration is removed

## MODIFIED Requirements

### 6. Requirement: Shared Evaluation Gate

All changed Nix MUST be formatted. `nix flake check --no-build`, a full-JSON-equality A/B evaluation preserving every routing profile present in the baseline `providers` list, a live models.dev catalog cross-check reporting zero missing model IDs, and evaluation of `.#nixosConfigurations.t14.config.system.build.toplevel` MUST pass before rollout.

(Previously: The gate required only formatting and `nix flake check --no-build`.)

#### Scenario: Repository and provider checks pass [hosts: rog, thinkcentre, t14, mact2]
- GIVEN all scoped edits are complete
- WHEN `format-nix`, the flake check, both provider checks, and the t14 build evaluation run
- THEN every command and comparison succeeds
- AND the catalog cross-check reports zero missing built-in model identifiers
