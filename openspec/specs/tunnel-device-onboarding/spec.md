# tunnel-device-onboarding Specification

## Purpose

Provision independently revocable VLESS access for approved devices without persisting share credentials.

## Requirements

### Requirement: Declarative Device Credential Lifecycle

Adding a device MUST add one scalar sops UUID key, its runtime declaration, and one named VLESS user, then rebuild. `macm5` MUST receive the dedicated `uuid_macm5` identity before native acceptance. After accepted macm5 activation, revoking mact2 MUST remove its key, declaration, and named user, then rebuild; it MUST NOT interrupt another valid device or expose either UUID in the repository, Nix store, or logs.

#### Scenario: Provision and revoke the replaced identity [hosts: macm5, rog]

- GIVEN macm5 has a distinct valid UUID and native acceptance is recorded
- WHEN the mact2 identity is revoked and private-link services rebuild
- THEN macm5 remains authenticated and mact2 authentication fails
- AND neither UUID appears in the repository, store, or logs

#### Scenario: Block identity revocation before acceptance [hosts: macm5, rog]

- GIVEN macm5 native acceptance is absent or failed
- WHEN mact2 identity revocation is requested
- THEN the mact2 key, declaration, and named user remain present

#### Scenario: Add and revoke one device [hosts: rog, macm5, Android]

- GIVEN `macm5` is connected with its own valid UUID
- WHEN a phone UUID is added and rebuilt, then removed and rebuilt
- THEN the phone connects before removal and fails its handshake afterwards
- AND `macm5` remains connected throughout the phone revocation

### Requirement: Runtime-Only Android Link Delivery

`bin/device-link` MUST read the rendered phone UUID only at runtime and print a `vless://` link with `encryption=none`, TLS, `sni=tun.glats.org`, `fp=chrome`, `type=ws`, `host=tun.glats.org`, and the fixed WebSocket path. The link and UUID MUST NOT be written to the repository, Nix store, or logs.

#### Scenario: Generate an importable link [hosts: macm5, Android]

- GIVEN the phone runtime secret and tunnel configuration are installed
- WHEN `bin/device-link` is invoked
- THEN its stdout is an importable link containing the required parameters
- AND repository, store, and command logs contain neither the UUID nor the complete link
