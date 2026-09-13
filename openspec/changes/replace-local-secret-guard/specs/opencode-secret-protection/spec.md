# OpenCode Secret Protection Specification

## Purpose

Provide cross-platform, reproducible secret protection for shared OpenCode profiles while retaining declarative permission denies as the authorization boundary.

## Requirements

### Requirement: Reproducible Warden Availability

The system MUST make exactly `opencode-warden@1.2.0` available to OpenCode from a fixed, integrity-verified package source. OpenCode MUST NOT need runtime npm network resolution to load it.

#### Scenario: Shared Linux profile starts with the pinned plugin

- GIVEN rog, thinkcentre, or t14 has its generated shared OpenCode profile
- WHEN OpenCode starts
- THEN it loads `opencode-warden@1.2.0` from the declaratively available package
- AND startup requires no npm network download

#### Scenario: Shared Darwin profile starts with the pinned plugin

- GIVEN mact2 has its generated shared OpenCode profile
- WHEN OpenCode starts
- THEN it loads `opencode-warden@1.2.0` from the declaratively available package
- AND the package identity and integrity match the declared pin

### Requirement: Shared Host Coverage

The system MUST enable the Warden protection capability for rog, thinkcentre, t14, and mact2. It SHALL keep the capability configuration equivalent across those supported hosts except for platform-required runtime differences.

#### Scenario: Configuration coverage is inspected

- GIVEN generated OpenCode configuration for each supported host
- WHEN the configured plugins are inspected
- THEN each configuration includes `opencode-warden@1.2.0`
- AND none relies on a host-local exception to omit secret protection

### Requirement: Local Secret Guard Retirement

The system MUST retire the broken local `secret-guard` plugin and MUST NOT load, package, or expose it as an OpenCode plugin.

#### Scenario: Startup has no local-plugin failure

- GIVEN a supported host starts OpenCode after the migration
- WHEN plugin loading completes
- THEN no local `secret-guard` plugin is loaded
- AND no startup diagnostic reports its invalid plugin export

#### Scenario: Retired artifact audit

- GIVEN the declared OpenCode package and runtime inputs
- WHEN they are audited for active plugin references
- THEN no active local `secret-guard` asset or package reference remains

### Requirement: Defense-in-Depth Secret Protections

The system MUST retain permission denies for `sops*`, `.env*`, and `/run/secrets/**` as the authorization boundary. Warden MUST operate in regex-only mode with user-prompt scanning and LLM safety features disabled. It MUST redact detected secrets in protected tool data, sanitize sensitive shell-environment values, and reject protected paths according to its deterministic rules.

#### Scenario: Sensitive tool data is redacted

- GIVEN a supported host processes tool data containing a recognizable secret
- WHEN Warden inspects the protected data
- THEN the exposed representation is redacted
- AND enabling LLM safety processing is not required

#### Scenario: SOPS environment data is sanitized

- GIVEN a shell invocation inherits an SOPS key environment value
- WHEN Warden prepares the shell environment
- THEN the sensitive value is sanitized before exposure to the tool

#### Scenario: Sensitive paths remain denied

- GIVEN an OpenCode action targets a `sops*`, `.env*`, or `/run/secrets/**` path
- WHEN permission evaluation occurs
- THEN the existing declarative deny prevents the action
- AND Warden protection does not weaken that deny

### Requirement: Measurable Cross-Platform Validation

The migration MUST provide repeatable validation evidence for Linux and Darwin covering plugin startup, fixed-package availability, secret redaction, SOPS environment sanitization, protected-path denial, and absence of the local plugin.

#### Scenario: Validation evidence is collected

- GIVEN the migration candidate is evaluated on at least one supported Linux host and mact2
- WHEN the defined validation suite runs
- THEN every required protection outcome has a recorded pass or fail result
- AND a failure prevents the migration from being accepted as validated
