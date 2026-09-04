# opencode-bootstrap-seed Specification

## Purpose

Define bootstrap-only delivery and installation of an OpenCode auth seed from `rog` to `mact2` without exposing raw secret material in the public uploads path.

## Requirements

### Requirement: Encrypted Seed Publication

The system MUST treat bootstrap artifact delivery as distinct from runtime proxying. `rog` MUST publish only an encrypted `mact2`-targeted seed artifact, plus any verification metadata needed by the installer, through the uploads path. The system MUST NOT publish raw `auth.json`, bearer tokens, upstream API keys, or other plaintext secret material in that path.

#### Scenario: Publish bootstrap ciphertext to uploads [hosts: rog]

- GIVEN `rog` has a seed prepared for `mact2`
- WHEN the bootstrap artifact is published to the uploads path
- THEN the published payload is encrypted and intended only for bootstrap installation
- AND no runtime upstream credential is exposed there

#### Scenario: Reject plaintext bootstrap publication [hosts: rog]

- GIVEN an operator attempts to publish raw auth state or another plaintext secret
- WHEN the publication workflow validates the artifact
- THEN the workflow MUST fail closed
- AND the uploads path remains without the plaintext secret

### Requirement: Safe Seed Installation

The `mact2` installer MUST verify the bootstrap artifact before merge, MUST create a timestamped backup of existing auth state before modification, and MUST merge only the seed payload into local OpenCode auth state. The installer MUST fail closed on download, verification, decrypt, or JSON-merge errors and SHALL preserve the preexisting auth state for rollback.

#### Scenario: Merge verified seed into existing auth state [hosts: mact2]

- GIVEN `mact2` has a valid encrypted seed and an existing or absent auth file
- WHEN the installer runs successfully
- THEN it creates a backup before modification and merges only the seed payload
- AND the resulting auth state remains valid JSON

#### Scenario: Preserve auth state on verification or merge failure [hosts: mact2]

- GIVEN `mact2` receives a corrupted, undecryptable, or invalid seed artifact
- WHEN the installer attempts to apply it
- THEN the installer MUST leave the current auth state unchanged
- AND the failure is reported without partial merge
