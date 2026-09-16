# macm5 Apple Silicon Onboarding Specification

## Purpose

Define Determinate-first, native Apple Silicon activation and recoverable acceptance for `macm5`.

## Requirements

### Requirement: Determinate-Owned Native Configuration

`macm5` MUST retain `nix.enable = false` and MUST supply required daemon and Cachix settings through `determinateNix.customSettings`. Activation MUST begin from a fresh Determinate-only installation and MUST stop for mixed-installer, APFS `/nix`, or daemon-socket failure.

#### Scenario: Reject an unsafe native base [hosts: macm5]

- GIVEN macm5 has Xcode CLI tools and Determinate Nix installed
- WHEN installer state, `/nix`, and the daemon socket are checked before activation
- THEN activation proceeds only with a healthy Determinate-only base
- AND a failed check records recovery before any retirement action

### Requirement: Native Acceptance and Recovery Evidence

`macm5` MUST be accepted only from native evidence covering evaluation, activation, `/nix`, Determinate services, Nix and `darwin-rebuild` PATH, Home Manager, arm64 Homebrew, remote access, wsdd, and direct-default private-link routing. The runbook MUST require Git and known-good-generation recovery; it MUST NOT name mact2 as validation, fallback, or rollback.

#### Scenario: Accept a native macm5 activation [hosts: macm5]

- GIVEN a healthy Determinate-only base and the macm5 configuration
- WHEN the operator activates and performs the documented native checks
- THEN all acceptance checks and release evidence pass on macm5
- AND the known-good generation and Git recovery reference are recorded

### Requirement: Stable Logical Darwin Selection

The Darwin flake selector MUST be independent of the physical macOS hostname.
`macm5` MUST use the local account `juan`, MUST preserve the corporate
LocalHostName `CLFTCLGV2FHWW0W`, and MUST NOT declare a host-name override.
The Darwin `nixos-build` helper MUST select `macm5` by default and MAY use the
documented `NIXOS_DARWIN_HOST` override for an explicitly selected declared
configuration. GitHub identity MUST remain `jcuzmar` independently of the
primary local account.

#### Scenario: Build the stable macm5 selector [hosts: macm5]

- GIVEN the physical LocalHostName is `CLFTCLGV2FHWW0W`
- WHEN `nixos-build` runs on Darwin without an override
- THEN it targets `darwinConfigurations.macm5`
- AND the host configuration provisions `juan` without declaring
  `networking.hostName`
- AND GitHub identity remains `jcuzmar`
