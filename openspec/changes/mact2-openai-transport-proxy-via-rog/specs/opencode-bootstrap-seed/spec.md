# OpenCode Bootstrap Seed Specification

## Purpose

Provide a safe `mact2` OAuth fallback while prioritizing an independent credential.

## Requirements

### Requirement: Prefer independent headless authentication

The system SHOULD use headless OpenCode login on `mact2` through the private proxy before a seed. It MUST treat a seed credential as one-time fallback material and MUST NOT require its concurrent use on `rog` and `mact2`.

#### Scenario: [mact2] Headless login succeeds

- GIVEN the private proxy is available
- WHEN an operator completes headless OpenCode login on `mact2`
- THEN `mact2` retains its independently issued `openai` credential

#### Scenario: [mact2,rog] Seed is required

- GIVEN independent headless login cannot complete
- WHEN the fallback seed is installed on `mact2`
- THEN operators MUST avoid concurrent use of the copied credential on `rog`

### Requirement: Protect fallback seed and rollback boundaries

The publisher MUST encrypt only a validated `openai` auth object to the `mact2` recipient and MUST NOT publish plaintext OAuth data. The installer MUST validate input, back up auth state, and replace only `openai`, preserving other providers. Rollback MUST disable proxy routing and preserve backups; it MUST NOT restore gateway secrets or plaintext credentials.

#### Scenario: [rog] Ciphertext-only publication

- GIVEN a valid local `openai` auth entry on `rog`
- WHEN a fallback seed is published
- THEN the published artifact is recipient-encrypted ciphertext containing no plaintext OAuth data

#### Scenario: [mact2] Safe installation failure

- GIVEN a seed is malformed, undecryptable, or lacks a valid `openai` entry
- WHEN the installer processes it
- THEN installation MUST fail without changing existing auth state

#### Scenario: [mact2] Scoped seed installation

- GIVEN valid seed data and existing non-OpenAI providers
- WHEN the installer applies the seed
- THEN it backs up auth state, replaces only `openai`, and preserves other providers

#### Scenario: [rog,mact2] Rollback avoids secret regression

- GIVEN transport proxying must be rolled back
- WHEN operators disable the proxy path
- THEN native provider configuration and auth backups remain available without restoring gateway keys or endpoints
