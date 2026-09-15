# Darwin Host Retirement Specification

## Purpose

Retire the handed-over Intel Darwin host without restoring it as an operational path.

## Requirements

### Requirement: Evidence-Gated mact2 Retirement

The system MUST remove mact2 configuration, stale remote-access declarations, private-link identity, rog-side user, and required SOPS records only after recorded macm5 native acceptance. Recovery MUST restore repository state or a known-good macm5 generation and MAY restore its identity; it MUST NOT reactivate, validate, or use mact2 as fallback.

#### Scenario: Retire after macm5 acceptance [hosts: macm5, rog]

- GIVEN recorded macm5 acceptance evidence and retirement authorization
- WHEN the declarative retirement is applied
- THEN mact2 declarations and identity records are absent
- AND recovery targets only macm5 Git, generation, and identity state

#### Scenario: Block premature retirement [hosts: macm5, rog]

- GIVEN macm5 native acceptance evidence is absent or failed
- WHEN retirement is requested
- THEN mact2 declarations and identity records remain unchanged
