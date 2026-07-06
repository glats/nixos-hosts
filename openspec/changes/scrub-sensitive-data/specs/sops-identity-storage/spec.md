# Delta Spec: sops-identity-storage

Domain for encrypting personal/work name and email values via sops, replacing the plaintext PII currently in `shared/git-identity.nix`.

## ADDED Requirements

### Requirement: Encrypted Identity Secrets File

The system MUST provide a new sops-encrypted file at `secrets/user/identities.yaml` containing `personal` and `work` blocks, each with `name` and `email` fields.

The file MUST be encrypted with the same `.sops.yaml` age keys used by all other secrets in this repository.

The file MUST NOT contain GPG signing key fingerprints (those remain in Nix).

#### Scenario: Secrets file exists and is encrypted

- GIVEN the repository after Stage 1
- WHEN `sops secrets/user/identities.yaml` is run to edit the file
- THEN the file MUST decrypt successfully
- AND the decrypted content MUST contain a `personal` block with `name` and `email` fields
- AND the decrypted content MUST contain a `work` block with `name` and `email` fields

#### Scenario: Secrets file uses correct age key

- GIVEN the repository after Stage 1
- WHEN `.sops.yaml` is inspected for `secrets/user/identities.yaml`
- THEN the file MUST use the same `admin_glats` age key as the rest of the secrets
- AND the file MUST NOT introduce a new encryption key

### Requirement: No Plaintext PII in Nix

The system MUST remove all plaintext name and email values from `shared/git-identity.nix`.

The file MUST retain GPG signing key fingerprints for each identity (these are public identifiers).

#### Scenario: git-identity.nix has zero plaintext PII

- GIVEN the repository after Stage 1
- WHEN `grep -E "(Redacted Name|jcuzmar@|falabella)" shared/git-identity.nix` is executed
- THEN zero matches MUST be returned

#### Scenario: GPG fingerprints are preserved

- GIVEN the repository after Stage 1
- WHEN `grep -E "fingerprint|signingKey|signingkey" shared/git-identity.nix` is executed
- THEN the file MUST still contain signing key fingerprints for both `personal` and `work` identities

### Requirement: Git Config Resolves from Sops

On every host, git `user.name` and `user.email` MUST resolve from the sops-decrypted `secrets/user/identities.yaml` file, NOT from plaintext Nix string literals.

The mechanism MUST work on both Linux hosts (rog, thinkcentre, t14) and Darwin (mact2).

On Linux hosts, sops secrets are decrypted to `/run/secrets/` before HM activation. On Darwin, the sops-nix integration decrypts to a per-user path.

#### Scenario: Linux host git identity set from sops

- GIVEN a Linux host (rog, thinkcentre, or t14) with Stage 1 configuration applied
- WHEN `git config user.name` is executed
- THEN the output MUST match the `personal.name` value from the decrypted sops identities file
- AND `git config user.email` MUST match the `personal.email` value from the decrypted identities file

#### Scenario: Darwin host git identity set from sops

- GIVEN the Darwin host mact2 with Stage 1 configuration applied
- WHEN `git config user.name` is executed
- THEN the output MUST match the `work.name` value from the decrypted sops identities file
- AND `git config user.email` MUST match the `work.email` value from the decrypted identities file

#### Scenario: No plaintext PII in Home Manager activation output

- GIVEN any host with Stage 1 configuration applied
- WHEN `home-manager switch` runs with verbose output
- THEN the activation output MUST NOT contain `Redacted Name`, `personal@example.com`, or `work@example.com`

### Requirement: Graceful Degradation When Sops Secrets Unavailable

Home Manager activation MUST NOT fail when the sops identities secrets file is not yet available (e.g., during initial bootstrap or when sops-nix has not yet decrypted secrets).

When the identities file is unavailable, git identity configuration MUST be skipped silently (no error, no broken git config).

#### Scenario: HM activation succeeds without identities file

- GIVEN the sops identities file has NOT been decrypted (e.g., `sops-nix` not yet initialized on a fresh host)
- WHEN `home-manager switch` runs
- THEN activation MUST exit with code 0
- AND no error messages about missing identity secrets MUST appear

#### Scenario: Git identity is absent when secrets unavailable

- GIVEN the sops identities file is not available
- WHEN `git config user.name` is executed
- THEN the output MAY be empty (no user.name set by HM)
- AND git operations that require user identity MUST fall back to system-level or environment-level configuration

### Requirement: Documentation Redacted

The file `docs/multi-github-identity.md` MUST be updated to reference sops secrets instead of hardcoded PII values.

#### Scenario: Documentation contains no PII

- GIVEN the repository after Stage 1
- WHEN `grep -E "(Redacted Name|jcuzmar@falabella\.cl|jcuzmar@protonmail\.com)" docs/multi-github-identity.md` is executed
- THEN zero matches MUST be returned

#### Scenario: Documentation references sops

- GIVEN the repository after Stage 1
- WHEN `grep -i "sops\|secrets\/user\/identities" docs/multi-github-identity.md` is executed
- THEN at least one match MUST be found (documentation points users to the sops-encrypted source)

### Requirement: Live OpenSpec Specs Redacted

The file `openspec/specs/gh-auth/spec.md` MUST be updated to remove all occurrences of `Redacted Name`, `personal@example.com`, and `work@example.com`.

#### Scenario: gh-auth spec has zero PII

- GIVEN the repository after Stage 1
- WHEN `grep -E "(Redacted Name|jcuzmar@falabella\.cl|jcuzmar@protonmail\.com)" openspec/specs/gh-auth/spec.md` is executed
- THEN zero matches MUST be returned

## MODIFIED Requirements

None. All requirements in this domain are new.

## REMOVED Requirements

None.

## RENAMED Requirements

None.
