# tunnel-device-onboarding Specification

## Purpose

Provision independently revocable VLESS access for approved devices without persisting share credentials.

## Requirements

### Requirement: Declarative Device Credential Lifecycle

Adding a device MUST add one scalar sops UUID key, its runtime declaration, and one named VLESS user, then rebuild. Revoking a device MUST remove that key, declaration, and user, then rebuild; it MUST NOT interrupt another valid device.

#### Scenario: Add and revoke one device [hosts: rog, mact2, Android]

- GIVEN `mact2` is connected with its own valid UUID
- WHEN a phone UUID is added and rebuilt, then removed and rebuilt
- THEN the phone connects before removal and fails its handshake afterwards
- AND `mact2` remains connected throughout the phone revocation

### Requirement: Runtime-Only Android Link Delivery

`bin/tunnel-device-link` MUST read the rendered phone UUID only at runtime and print a `vless://` link with `encryption=none`, TLS, `sni=tun.glats.org`, `fp=chrome`, `type=ws`, `host=tun.glats.org`, and the fixed WebSocket path. The link and UUID MUST NOT be written to the repository, Nix store, or logs.

#### Scenario: Generate an importable link [hosts: mact2, Android]

- GIVEN the phone runtime secret and tunnel configuration are installed
- WHEN `bin/tunnel-device-link` is invoked
- THEN its stdout is an importable link containing the required parameters
- AND repository, store, and command logs contain neither the UUID nor the complete link
