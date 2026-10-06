# macm5-openai-native-auth

## MODIFIED Requirements

### Requirement: Native Provider Activation

Native `openai-medium` MUST follow home proof, retaining OAuth/full-tunnel routing without proxy tiers.

(Previously: smoke targeted V1.)

#### Scenario: Run the native smoke test [hosts:macm5]
- GIVEN valid OAuth/native tier
- WHEN isolated `opencode2` PONG runs at home
- THEN OAuth succeeds through full tunnel

### Requirement: Auth-Seed Fallback Safety

Supported isolated-V2 fallback MAY follow device-flow failure; it MUST back-up-auth-before-mutation, merging only native OAuth. Unsupported/unsafe/API-key-like/conflicting requests MUST fail nonzero before fetch/decrypt/auth-access/backup/write, preserving credentials/existing-backups; no new backup/importer required. Retired helpers MUST reject even `--v2` with actionable guidance, never claiming success.

(Previously: V1; ambiguous refusal backups.)

#### Scenario: Reject an unsafe seed [hosts:macm5]
- GIVEN invalid/API-key-like/conflicting seed
- WHEN installation runs
- THEN auth/existing-backups remain unchanged; no new-backup requirement

#### Scenario: Unavailable interface [hosts:macm5]
- GIVEN unsupported seed interface
- WHEN default/`--v2` installation runs
- THEN actionable nonzero refusal precedes fetch/decrypt/auth-access/backup/write; no success is claimed
