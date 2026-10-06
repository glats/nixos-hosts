# Droppy Music Access Specification

## Purpose

Expose music declaratively on `rog` while preserving Droppy-native persistent accounts. This new capability has no existing main spec.

## Requirements

### Requirement: Declarative read-only music access

Droppy on `rog` MUST declare `/run/media/library/music:/files/music:ro`, retain `/srv/glats/droppy/config:/config` and `/run/media/stuff/droppy:/files`, and expose music through Droppy rather than new nginx aliases. Other hosts MUST remain unchanged.

#### Scenario: Music is accessible after authorized deployment [rog]

- GIVEN the library is mounted and music exists
- WHEN the approved configuration is deployed and an existing user browses Droppy
- THEN `/files/music` exposes the source music and existing files remain accessible
- AND music writes through Droppy are denied without changing source data

### Requirement: Missing-source acceptance gate

Verification MUST assess generated startup ordering and missing-source behavior. An absent library mount or music directory MUST block deployment acceptance; an empty fallback directory MUST NOT count as success or be created by this change.

#### Scenario: Source unavailable [rog]

- GIVEN the library mount or music directory is unavailable
- WHEN authorized deployment acceptance is assessed
- THEN acceptance is blocked and the missing prerequisite is reported
- AND no fallback directory is created

### Requirement: Preserve native persistent accounts

Existing `shrike` and `glats` MUST remain native records in `/srv/glats/droppy/config/db.json`, not Nix-reproducible accounts. This change MUST NOT recreate or mutate accounts, overwrite hashes or privileges, invalidate sessions, or alter shared links. `shrike` MUST remain non-privileged.

#### Scenario: Existing state survives the change [rog]

- GIVEN `shrike` already exists alongside `glats`, sessions, and links
- WHEN the music configuration is applied or rolled back
- THEN this change performs no account or database mutations
- AND persistent configuration remains bound to `/config`

### Requirement: Remove rejected pending provisioning only after apply approval

Authorized apply MUST remove this change's pending `sops.secrets.droppy-users`, account-seeding `docker-droppy.preStart`, `secrets/host/rog/droppy-users.json`, and `linux/system/services/web/droppy.test.py`. The only retained functional change MUST be the music mount. Unrelated dirty edits MUST remain intact.

#### Scenario: Scoped cleanup [rog]

- GIVEN separate apply approval and the rejected pending additions
- WHEN cleanup is performed
- THEN those additions are absent and only the music mount remains
- AND unrelated edits and live account state are preserved

### Requirement: Bounded offline verification

Offline acceptance MUST include touched-module formatting, `rog` toplevel evaluation, and generated volume/unit checks. It MUST NOT imply runtime success. Ad-hoc tests MUST use synthetic data only in a sandbox or `/home/glats/.local/opencode-v2/tmp/opencode`; no Python tests MAY be added beside Nix modules. Credentials MUST NOT appear in artifacts or reports; secrets MUST NOT be decrypted.

#### Scenario: Offline proof succeeds [rog]

- GIVEN apply approval and scoped cleanup
- WHEN offline checks pass without activation
- THEN configuration acceptance is reported separately from pending runtime acceptance

#### Scenario: Offline proof fails [rog]

- GIVEN evaluation or generated configuration checks fail
- WHEN results are reported
- THEN offline acceptance fails without deployment or live-state changes

### Requirement: Separate deployment authorization

Planning approval MUST NOT authorize implementation, service actions, or deployment. Runtime verification MUST require separate deployment approval and user-confirmed login checks without credential disclosure.

#### Scenario: Deployment not approved [rog]

- GIVEN only planning or offline verification is authorized
- WHEN that phase completes
- THEN no activation, service action, or live login check occurs

#### Scenario: Authorized runtime acceptance [rog]

- GIVEN separate deployment approval and an available music source
- WHEN post-deploy verification occurs
- THEN read-only browsing and user-confirmed existing-account login are verified
- AND account privileges remain unchanged without reporting credentials
