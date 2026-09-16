# LAN SSH Mesh Specification

## Purpose

Provide an auditable, bidirectional, non-root SSH public-key mesh among `rog`, `thinkcentre`, `t14`, `macm5`, and `oneplus5` without adding `mact2`.

## Requirements

### Requirement: Public Identity Registry

The system MUST maintain one reviewed registry containing exactly one unique `ssh-ed25519` public identity for each mesh source host. Each record MUST identify its host, target login account, public-key line, comment, SHA256 fingerprint, and verification date. The registry MUST NOT contain private-key material, SOPS-encrypted key material, or a shared identity.

#### Scenario: [rog, thinkcentre, t14, macm5, oneplus5] Complete verified inventory

- GIVEN five confirmed source-host public identities
- WHEN the registry is evaluated
- THEN it MUST contain one uniquely attributable record for every mesh member

#### Scenario: [all mesh hosts] Unsafe identity input

- GIVEN an identity is duplicate, unverified, or private material
- WHEN it is proposed for the registry
- THEN it MUST NOT become an authorized mesh record

### Requirement: Declarative Nix-Target Authorization

`rog`, `thinkcentre`, and `t14` MUST declaratively authorize the other four registry identities for `glats`; `macm5` MUST declaratively authorize the other four for `juan`. A target MUST NOT authorize its own source identity. The mesh MUST NOT add root authorization or change existing password-authentication policy.

#### Scenario: [rog, thinkcentre, t14, macm5] Peer key accepted

- GIVEN a deployed Nix target and a peer's designated private key
- WHEN the peer authenticates as the target's mesh account
- THEN public-key authentication MUST succeed

#### Scenario: [rog, thinkcentre, t14, macm5] Self or root access

- GIVEN a source's own key or a root login attempt
- WHEN SSH authentication is attempted
- THEN the mesh MUST NOT authorize that access

### Requirement: Source-Specific Client Aliases

Each mesh source MUST provide aliases named for its four peer hosts. Each alias MUST select the target account, use only the local source identity with `IdentitiesOnly`, and preserve host-key verification. Darwin mesh aliases MUST apply to `macm5` only; `mact2` MUST receive no mesh aliases.

#### Scenario: [rog, thinkcentre, t14, macm5] Alias selects local identity

- GIVEN a configured Nix mesh source
- WHEN it connects through a peer alias
- THEN the alias MUST offer only that source host's designated identity

#### Scenario: [mact2] Excluded Darwin host

- GIVEN `mact2` is evaluated or activated
- WHEN its SSH client configuration is inspected
- THEN mesh aliases MUST be absent

### Requirement: Manual oneplus5 Inbound Lifecycle

The repository MUST document a testable manual procedure for `oneplus5` that authorizes the four Nix-source public keys for `glats`, configures its four peer aliases with its local identity, records completion evidence, and detects drift against the registry. The procedure MUST require manual removal of a revoked key and a rejection proof; it MUST NOT claim Nix deployment manages `oneplus5`.

#### Scenario: [oneplus5] Manual enrollment evidence

- GIVEN the four Nix-source registry records
- WHEN the documented procedure is completed on `oneplus5`
- THEN its authorization and aliases MUST enable its four directed mesh connections

#### Scenario: [oneplus5] Manual revocation proof

- GIVEN a compromised source identity was removed from the registry
- WHEN the documented oneplus5 removal and verification are performed
- THEN authentication by that identity MUST be rejected and evidence MUST be recorded

### Requirement: Mesh Acceptance and Revocation

The implementation MUST prove all twenty directed non-root connections with their designated identities, including physical `macm5` activation. Emergency revocation MUST remove a compromised identity from all four peer Nix targets, apply the oneplus5 manual removal where applicable, and prove rejection; active sessions SHOULD be ended where practical before replacement distribution.

#### Scenario: [rog, thinkcentre, t14, macm5, oneplus5] Full matrix

- GIVEN all targets are deployed and oneplus5 manual enrollment is evidenced
- WHEN every source connects to each of its four peers
- THEN all twenty designated-key connections MUST succeed
