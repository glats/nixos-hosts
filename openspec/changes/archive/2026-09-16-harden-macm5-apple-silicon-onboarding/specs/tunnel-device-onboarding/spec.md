# Delta for tunnel-device-onboarding

## MODIFIED Requirements

### Requirement: Declarative Device Credential Lifecycle

Adding a device MUST add one scalar sops UUID key, its runtime declaration, and one named VLESS user, then rebuild. `macm5` MUST receive the dedicated `uuid_macm5` identity before native acceptance. After accepted macm5 activation, revoking mact2 MUST remove its key, declaration, and named user, then rebuild; it MUST NOT interrupt another valid device or expose either UUID in the repository, Nix store, or logs.
(Previously: Device lifecycle protected another valid device, with mact2 as the retained device during another device's revocation.)

#### Scenario: Provision and revoke the replaced identity [hosts: macm5, rog]

- GIVEN macm5 has a distinct valid UUID and native acceptance is recorded
- WHEN the mact2 identity is revoked and private-link services rebuild
- THEN macm5 remains authenticated and mact2 authentication fails
- AND neither UUID appears in the repository, store, or logs

#### Scenario: Block identity revocation before acceptance [hosts: macm5, rog]

- GIVEN macm5 native acceptance is absent or failed
- WHEN mact2 identity revocation is requested
- THEN the mact2 key, declaration, and named user remain present
