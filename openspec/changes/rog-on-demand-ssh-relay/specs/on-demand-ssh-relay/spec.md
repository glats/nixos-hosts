# On-Demand SSH Relay Specification

## Purpose

Provide rog-to-macm5 SSH through approved Rust wstunnel11.0.0. Manual startup; reboot persistence, power control and disconnected-session survival remain excluded.

## Requirements

### Requirement: Verified outbound transport

macm5 MUST initiate WSS443 to exactly `relay.glats.org`, explicitly verifying certificate/hostname against trusted system CAs; raw SSH443 MUST NOT substitute. Chisel transport fingerprints are obsolete.

#### Scenario: Authorized connection [macm5, rog]
- GIVEN valid ingress and trusted identities
- WHEN macm5 enables publication
- THEN verified WSS443 reaches rog without inbound Mac internet exposure.

#### Scenario: Identity failure [macm5, rog]
- GIVEN an invalid certificate or unexpected relay identity
- WHEN connection is attempted
- THEN publication fails closed without disabling verification.

### Requirement: Restricted authenticated publication

rog MUST authenticate independently revocable per-host Authorization and allow ONLY ReverseTunnel Tcp on `127.0.0.1:22220`; UDP/SOCKS/HTTP-proxy/normal-forward/other listeners MUST fail. Trusted managed macm5 MUST forward only `127.0.0.1:22`; malicious endpoints cannot be attested. Credentials MUST remain runtime-only in restriction/header files, absent from argv/environment/store/logs/status. Policy changes MUST STOP the dedicated server before secret/policy replacement, validate, then START; failure stays stopped, last removal uses `restrictions: []`. Missing/malformed startup policy MUST fail closed; hot reload MUST NOT count as immediate revocation.

#### Scenario: Denied publication [macm5, rog]
- GIVEN missing/invalid/revoked credentials, removed/malformed policy, or forbidden capability/listener
- WHEN publication is attempted
- THEN publication fails closed; revocation shutdown tears down existing streams and stale policy MUST NOT restart.

#### Scenario: Local listener and secret containment [macm5, rog]
- GIVEN authorized publication
- WHEN bindings, external access, and artifacts/output are inspected
- THEN only `127.0.0.1:22220` publishes trusted Mac `127.0.0.1:22`; no credential leaks.

### Requirement: Authenticated operator SSH

rog MUST add a `juan` SSH alias requiring authorized key and verified Mac host key independently of publication.

#### Scenario: Operator access [rog, macm5]
- GIVEN a live publication and the verified Mac host key
- WHEN rog tries authorized/unauthorized keys or a mismatched host key
- THEN authorized SSH succeeds; unauthorized attempts fail without password/trust bypass.

### Requirement: Enabled intention and recovery

`on` MUST return within its finite deadline while rog is unavailable, retaining enabled intent with quiet capped native retries until `off`; duplicate clients are forbidden. Recovery MUST allow new SSH without another `on`.

#### Scenario: Nightly outage and recovery [macm5, rog]
- GIVEN rog is unavailable
- WHEN `on` is repeated and rog later becomes reachable
- THEN one client reconnects within the documented bound without busy-looping/repetitive errors.

### Requirement: Definitive cancellation

`off` MUST idempotently cancel intent, pending/in-flight retries and client activity without rog availability, releasing publication.

#### Scenario: Stop racing recovery [macm5, rog]
- GIVEN retries or connection work are active
- WHEN `off` completes, is repeated, and rog recovers
- THEN no client/retry resumes; publication clears after relay-side disconnect detection.

### Requirement: Bounded truthful status

`status` MUST be read-only, noninteractive, redacted and finitely bounded, distinguishing intent, process/registration, relay and SSH evidence; unavailable evidence is unknown, never success.

#### Scenario: Incomplete evidence [macm5, rog]
- GIVEN a running client or open listener but no verified end-to-end SSH evidence
- WHEN `status` runs
- THEN it neither claims end-to-end SSH success nor changes intent.

#### Scenario: Stalled probe [macm5, rog]
- GIVEN DNS, connection, TLS, or SSH probing stalls or requires interaction
- WHEN `status` runs
- THEN its deadline holds without prompts/service starts/physical power claims.

### Requirement: Operational isolation

Relay MUST NOT add VPN/TUN/routes, depend on linkctl, reuse `tun.glats.org` credentials/path/backend, or block boot/login/apps. LAN SSH/linkctl/web ingress remain unchanged.

#### Scenario: Noninterference [macm5, rog]
- GIVEN baseline networking and existing services work
- WHEN relay is enabled, unavailable, recovered, then disabled
- THEN routes, LAN SSH, linkctl/tun access, other vhosts, login, and unrelated application networking retain baseline behavior.
